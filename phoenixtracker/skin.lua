-- The game's own window art, for the Classic theme. Adapted from Frankie-hz's craftbook
-- (github.com/Frankie-hz/craftbook, GPLv3), which worked out the file layout and drawing.
--
-- The art is read from the player's own install (ROM/0/14.DAT to 21.DAT, one per Window Type).
-- Nothing from the game ships with the addon.
require('common');

local chat    = require('chat');
local datfile = require('datfile');
local d3d     = require('d3d8');
local ffi   = require('ffi');
local imgui = require('imgui');
local C     = ffi.C;

pcall(ffi.cdef, 'void* GetModuleHandleA(const char* name);');
pcall(ffi.cdef, 'uint32_t GetModuleFileNameA(void* module, char* path, uint32_t size);');
pcall(ffi.cdef, 'typedef int32_t (__cdecl* phoenixtracker_config_get_t)(int32_t);');

-- The game keeps one DAT per Window Type: ROM/0/14.DAT is Type 1, ROM/0/21.DAT is Type 8.
local WINDOW_TYPES    = 8;
local FIRST_SKIN_FILE = 14;
local SKIN_FOLDER     = 'ROM\\0';
local GAME_MODULE     = 'FFXiMain.dll';
local MAX_PATH        = 260;
local PLAYONLINE_FFXI = 1;

-- Same lookup Ashita's config addon uses. Key 18 is Config > Windows > Shared > Window Type.
local CONFIG_GET_SIGNATURE = '8B0D????????85C974??8B44240450E8????????C383C8FFC3';
local WINDOW_TYPE_KEY      = 18;
local POLL_SECONDS         = 1;

local PARTS = { 'newtex', 'hfr1', 'vfr1', 'corner' };

-- The game's text font lives in its main UI file. Each region's client uses its own copy; 119/51 is
-- the one the English font mods replace, so it's tried first.
local FONT_FILES  = { 'ROM\\119\\51.DAT', 'ROM\\118\\111.DAT', 'ROM\\91\\15.DAT', 'ROM\\0\\1.DAT' };
local FONT_CHUNKS = 4096;

local D3DX_FROM_FILE   = 0xFFFFFFFF;
local D3DX_FILTER_NONE = 1;

local TILE        = 128;
local STRIP       = 16;
local PIECE       = 32;
local HALF        = 16;
local MAX_STRIPS  = 256;
local MAX_COLUMNS = 64;
local WHITE       = 0xFFFFFFFF;

-- An edge samples its piece from texel centres so the two ends never blend into each other.
local EDGE_START = 0.5 / PIECE;
local EDGE_END   = 1 - 0.5 / PIECE;

-- The game lights its windows from the top: these multiply the art, where 1 leaves it as drawn.
local TOP_SHADE    = 0.75;
local BOTTOM_SHADE = 0.50;

local skin = {
    WINDOW_TYPES = WINDOW_TYPES,
};

local cache      = {};
local config_get = nil;
local followed   = 0;
local next_poll  = 0;

local function message(text)
    print(chat.header(addon.name):append(chat.message(text)));
end

-- Ashita returns an ImVec2 either as a table or as two numbers, depending on the call.
local function vec2(a, b)
    if (type(a) == 'table') then
        return a.x or a[1], a.y or a[2];
    end
    return a, b;
end

-----------------------------------
-- Which window type
-----------------------------------
-- The Window Type picked in the game's config (0-7), or nil when it can't be read.
function skin.game_type()
    if (config_get == nil) then
        local ok, pointer = pcall(ashita.memory.find, 0, 0, CONFIG_GET_SIGNATURE, 0, 0);
        if (ok and pointer ~= nil and pointer ~= 0) then
            config_get = ffi.cast('phoenixtracker_config_get_t', pointer);
        else
            config_get = false;
        end
    end
    if (config_get == false) then
        return nil;
    end

    local value = config_get(WINDOW_TYPE_KEY);
    if (value < 0 or value >= WINDOW_TYPES) then
        return nil;
    end
    return value;
end

-- The window type to draw: the pinned one, else the game's, re-read about once a second.
function skin.window_type(pinned)
    if (pinned and pinned >= 0 and pinned < WINDOW_TYPES) then
        return pinned;
    end

    local now = os.clock();
    if (now >= next_poll) then
        next_poll = now + POLL_SECONDS;
        followed  = skin.game_type() or followed;
    end
    return followed;
end

-----------------------------------
-- Reading the art from the game install
-----------------------------------
local function folder_of(path)
    return path:match('^(.*)[\\/][^\\/]*$');
end

local function running_client_folder()
    local module = C.GetModuleHandleA(GAME_MODULE);
    if (module == nil) then
        return nil;
    end

    local buffer = ffi.new('char[?]', MAX_PATH);
    local length = C.GetModuleFileNameA(module, buffer, MAX_PATH);
    if (length == 0) then
        return nil;
    end
    return folder_of(ffi.string(buffer, length));
end

local function registered_client_folder()
    local language = AshitaCore:GetConfigurationManager():GetInt32('boot', 'ashita.language', 'playonline', 2);
    return ashita.fs.get_install_dir(language, PLAYONLINE_FFXI);
end

-- One of the game's own files (a name like 'ROM\0\14.DAT') as a string, or nil. Read-only.
local function read_rom(name)
    local finders = { running_client_folder, registered_client_folder };
    for _, finder in ipairs(finders) do
        local ok, folder = pcall(finder);
        if (ok and folder ~= nil and folder ~= '') then
            local file = io.open(('%s\\%s'):fmt(folder, name), 'rb');
            if (file ~= nil) then
                local data = file:read('*a');
                file:close();
                return data;
            end
        end
    end
    return nil;
end

-- A texture read by datfile, as a Direct3D texture ImGui can draw: { texture, id }.
local function create_texture(texture)
    local image  = datfile.as_dds(texture.width, texture.height, texture.fourcc, texture.blocks);
    local result_texture = ffi.new('IDirect3DTexture8*[1]');
    local result = C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), image, #image, D3DX_FROM_FILE, D3DX_FROM_FILE, 1, 0, C.D3DFMT_A8R8G8B8, C.D3DPOOL_MANAGED, D3DX_FILTER_NONE, C.D3DX_DEFAULT, 0, nil, nil, result_texture);
    if (result ~= C.S_OK) then
        return nil;
    end

    local handle = ffi.cast('IDirect3DTexture8*', result_texture[0]);
    return { texture = handle, id = tonumber(ffi.cast('uint32_t', handle)) };
end

local function release_art(art)
    for _, part in pairs(art) do
        part.texture:Release();
    end
end

local WANTED_PARTS = {};
for _, name in ipairs(PARTS) do
    WANTED_PARTS[name] = true;
end

local function load_art(window_type)
    local data = read_rom(('%s\\%d.DAT'):fmt(SKIN_FOLDER, FIRST_SKIN_FILE + window_type));
    if (data == nil) then
        return nil, 'the window art file was not found in the game install';
    end

    local images = datfile.textures(data, WANTED_PARTS);
    local art    = {};
    for _, name in ipairs(PARTS) do
        local part = nil;
        if (images[name] ~= nil) then
            part = create_texture(images[name]);
        end
        if (part == nil) then
            release_art(art);
            return nil, ('the "%s" art could not be read'):fmt(name);
        end
        art[name] = part;
    end
    return art, nil;
end

-- The textures for a window type, or nil when the install's art can't be used (said once in chat).
function skin.get(window_type)
    local art = cache[window_type];
    if (art == nil) then
        local ok, loaded, reason = pcall(load_art, window_type);
        if (ok and loaded ~= nil) then
            art = loaded;
        else
            art = false;
            if (not ok) then
                reason = tostring(loaded);
            end
            message(('Classic theme: %s. Using plain colours for Type %d.'):fmt(reason, window_type + 1));
        end
        cache[window_type] = art;
    end
    if (art == false) then
        return nil;
    end
    return art;
end

-----------------------------------
-- The game's text font
-----------------------------------
local font_cache = nil;

local function load_font()
    for _, name in ipairs(FONT_FILES) do
        local data = read_rom(name);
        if (data ~= nil) then
            local moji = datfile.textures(data, { moji = true }, FONT_CHUNKS).moji;
            local glyphs = moji and datfile.glyph_widths(moji);
            if (glyphs ~= nil) then
                local texture = create_texture(moji);
                if (texture == nil) then
                    return nil, 'the font texture could not be made';
                end
                return {
                    texture = texture.texture,
                    id      = texture.id,
                    width   = moji.width,
                    height  = moji.height,
                    glyphs  = glyphs,
                }, nil;
            end
        end
    end
    return nil, 'the game\'s font file was not found in the game install';
end

-- The game's text font: { id, width, height, glyphs }, where glyphs[code] = { left, width } in the
-- 16 x 16 cell. nil when it can't be used (said once in chat). Read once, the first time it's asked for.
function skin.font()
    if (font_cache == nil) then
        local ok, loaded, reason = pcall(load_font);
        if (ok and loaded ~= nil) then
            font_cache = loaded;
        else
            font_cache = false;
            if (not ok) then
                reason = tostring(loaded);
            end
            message(('Classic theme: %s. Using the normal font with an outline.'):fmt(reason));
        end
    end
    return font_cache or nil;
end

-- Art that failed to load stays marked, so its chat message isn't repeated.
function skin.release()
    for window_type, art in pairs(cache) do
        if (art ~= false) then
            release_art(art);
            cache[window_type] = nil;
        end
    end
    if (font_cache) then
        font_cache.texture:Release();
        font_cache = nil;
    end
end

-----------------------------------
-- Drawing
-----------------------------------
-- Reused for every quad, since a window is a few hundred of them each frame.
local corner_min = { 0, 0 };
local corner_max = { 0, 0 };
local uv_min     = { 0, 0 };
local uv_max     = { 0, 0 };

local function quad(list, texture, x0, y0, x1, y1, u0, v0, u1, v1, color)
    corner_min[1] = x0;
    corner_min[2] = y0;
    corner_max[1] = x1;
    corner_max[2] = y1;
    uv_min[1]     = u0;
    uv_min[2]     = v0;
    uv_max[1]     = u1;
    uv_max[2]     = v1;
    list:AddImage(texture, corner_min, corner_max, uv_min, uv_max, color);
end

-- The shade at a height (0 top, 1 bottom) as the packed colour ImGui multiplies the texture by.
local function shade(t, alpha)
    local level = math.floor((TOP_SHADE + (BOTTOM_SHADE - TOP_SHADE) * t) * 255 + 0.5);
    local a     = math.floor(alpha * 255 + 0.5);
    return a * 16777216 + level * 65536 + level * 256 + level;
end

-- The background repeats every 128 pixels and is drawn in thin rows so each row can take its own shade.
local function draw_background(list, texture, left, top, right, bottom, alpha)
    local height = bottom - top;
    if (height <= 0 or right <= left) then
        return;
    end

    local strips  = math.min(math.ceil(height / STRIP), MAX_STRIPS);
    local columns = math.min(math.ceil((right - left) / TILE), MAX_COLUMNS);
    for strip = 0, strips - 1 do
        local y0    = top + strip * STRIP;
        local y1    = math.min(y0 + STRIP, bottom);
        local v0    = ((strip * STRIP) % TILE) / TILE;
        local v1    = v0 + (y1 - y0) / TILE;
        local color = shade(math.min((y0 - top + STRIP / 2) / height, 1), alpha);
        for column = 0, columns - 1 do
            local x0 = left + column * TILE;
            local x1 = math.min(x0 + TILE, right);
            quad(list, texture, x0, y0, x1, y1, 0, v0, (x1 - x0) / TILE, v1, color);
        end
    end
end

-- Each piece holds two edges (top and bottom, or left and right) and the corner piece all four
-- corners. An edge is stretched along its length because some frames shade from one end to the
-- other, which tiling would repeat.
local function draw_frame(list, art, left, top, right, bottom)
    if (right - left < PIECE or bottom - top < PIECE) then
        return;
    end

    local horizontal = art.hfr1.id;
    quad(list, horizontal, left + HALF, top, right - HALF, top + HALF, EDGE_START, 0, EDGE_END, 0.5, WHITE);
    quad(list, horizontal, left + HALF, bottom - HALF, right - HALF, bottom, EDGE_START, 0.5, EDGE_END, 1, WHITE);

    local vertical = art.vfr1.id;
    quad(list, vertical, left, top + HALF, left + HALF, bottom - HALF, 0, EDGE_START, 0.5, EDGE_END, WHITE);
    quad(list, vertical, right - HALF, top + HALF, right, bottom - HALF, 0.5, EDGE_START, 1, EDGE_END, WHITE);

    local corner = art.corner.id;
    quad(list, corner, left, top, left + HALF, top + HALF, 0, 0, 0.5, 0.5, WHITE);
    quad(list, corner, right - HALF, top, right, top + HALF, 0.5, 0, 1, 0.5, WHITE);
    quad(list, corner, left, bottom - HALF, left + HALF, bottom, 0, 0.5, 0.5, 1, WHITE);
    quad(list, corner, right - HALF, bottom - HALF, right, bottom, 0.5, 0.5, 1, 1, WHITE);
end

-- Paints the window that was just begun. ImGui has already drawn the title bar by then, so the
-- background stays below it and only the thin frame lines cross it.
function skin.draw(window_type, titled, alpha)
    local art = skin.get(window_type);
    if (art == nil) then
        return;
    end

    local x, y          = vec2(imgui.GetWindowPos());
    local width, height = vec2(imgui.GetWindowSize());
    local left          = math.floor(x);
    local top           = math.floor(y);
    local right         = left + math.floor(width);
    local bottom        = top + math.floor(height);

    local body_top = top;
    if (titled) then
        body_top = top + math.floor(imgui.GetFrameHeight());
    end

    -- A clip rectangle that leaves the screen makes the renderer stretch the art over the whole screen.
    local display     = imgui.GetIO().DisplaySize;
    local clip_left   = math.max(left, 0);
    local clip_top    = math.max(top, 0);
    local clip_right  = math.min(right, display.x);
    local clip_bottom = math.min(bottom, display.y);
    if (clip_right <= clip_left or clip_bottom <= clip_top) then
        return;
    end

    local list = imgui.GetWindowDrawList();
    list:PushClipRect({ clip_left, clip_top }, { clip_right, clip_bottom }, false);
    draw_background(list, art.newtex.id, left, body_top, right, bottom, alpha);
    draw_frame(list, art, left, top, right, bottom);
    list:PopClipRect();
end

return skin;
