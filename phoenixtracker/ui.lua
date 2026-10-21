-- Shared look for every PhoenixTracker tab: the themes, and the helpers every tab draws with.
-- Tabs read colours from ui.COLOR by name. A theme refills that table in place, so a tab never
-- needs to know which theme is showing.
require('common');

local chat  = require('chat');
local imgui = require('imgui');

local ui = {};

ui.PADDING    = 12;
ui.BASE_WIDTH = 360;
ui.JST_OFFSET = 9 * 3600;

function ui.rgb(hex, alpha)
    return {
        tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
        alpha or 1.0,
    };
end

local rgb = ui.rgb;

local function fade(color, alpha)
    return { color[1], color[2], color[3], alpha };
end

local function shade(color, factor, alpha)
    return { color[1] * factor, color[2] * factor, color[3] * factor, alpha or 1 };
end

local function lighten(color, amount)
    return {
        color[1] + (1 - color[1]) * amount,
        color[2] + (1 - color[2]) * amount,
        color[3] + (1 - color[3]) * amount,
        1,
    };
end

-----------------------------------
-- Themes
-----------------------------------
-- Every theme fills the same names:
--   abyss      window background, and dark text on a filled banner
--   surface1   title bar, popups and alternate table rows
--   surface2   input boxes and the empty part of a bar
--   button, button_hover   an off toggle button and its hover state
--   border, subtle   window and table lines
--   text, secondary, muted, faint   text from brightest to dimmest
--   peach      the character name and other headline text
--   royal, hover, tint   an on toggle button, filled bars, and their hover states
--   ember      a highlighted number or countdown
--   danger, gold, success   bad, notable and good
-- style holds the corner rounding, which Classic squares off to match the game's windows. A theme
-- can also set imgui (ImGui colours by ImGuiCol_ name, on top of the ones built from the palette)
-- and vars (ImGui style sizes by ImGuiStyleVar_ name).

-- Skold's original palette, after phoenix-xi.com.
local function phoenix_theme()
    return {
        palette = {
            abyss     = rgb('180e0e'),
            surface1  = rgb('291c1c'),
            surface2  = rgb('321f1f'),
            border    = rgb('d2abab', 0.20),
            subtle    = rgb('d2abab', 0.12),
            text      = rgb('fff8f8'),
            secondary = rgb('eae1e1'),
            peach     = rgb('d2abab'),
            muted     = rgb('8a6b6b'),
            faint     = rgb('5a4545'),
            button       = rgb('321f1f'),
            button_hover = rgb('c55151', 0.30),
            royal     = rgb('c55151'),
            tint      = rgb('c55151', 0.30),
            hover     = rgb('d45e5e'),
            ember     = rgb('ff8d79'),
            danger    = rgb('e04040'),
            gold      = rgb('c5a131'),
            success   = rgb('63ba8a'),
        },
        style = { window = 8.0, frame = 4.0 },
    };
end

-- Dark grey with a blue accent, for anyone who'd rather not have red on red.
local function neutral_theme()
    return {
        palette = {
            abyss     = rgb('16171b'),
            surface1  = rgb('222329'),
            surface2  = rgb('2c2e35'),
            border    = rgb('c8ccd6', 0.18),
            subtle    = rgb('c8ccd6', 0.10),
            text      = rgb('f2f3f5'),
            secondary = rgb('d9dbe0'),
            peach     = rgb('a9c4f5'),
            muted     = rgb('8b8f99'),
            faint     = rgb('5b5e66'),
            button       = rgb('2c2e35'),
            button_hover = rgb('3f6fb8', 0.30),
            royal     = rgb('3f6fb8'),
            tint      = rgb('3f6fb8', 0.30),
            hover     = rgb('4c7ec9'),
            ember     = rgb('f2b366'),
            danger    = rgb('e05a5a'),
            gold      = rgb('d4b44a'),
            success   = rgb('63ba8a'),
        },
        style = { window = 8.0, frame = 4.0 },
    };
end

-- The background and frame colour of each in-game Window Type (0 is Type 1), sampled from the
-- game's art by Frankie-hz for craftbook. The flat parts of the window are built from these so
-- they sit on the art, and they stand in for the art if it can't be read.
local WINDOW_ART = {
    [0] = { background = rgb('282452'), frame = rgb('888988') },
    [1] = { background = rgb('5d5c6f'), frame = rgb('9698a6') },
    [2] = { background = rgb('23204d'), frame = rgb('888988') },
    [3] = { background = rgb('2b2b2b'), frame = rgb('9698a6') },
    [4] = { background = rgb('626262'), frame = rgb('888988') },
    [5] = { background = rgb('001948'), frame = rgb('5a4418') },
    [6] = { background = rgb('9e8f64'), frame = rgb('867953') },
    [7] = { background = rgb('1c353f'), frame = rgb('314e57') },
};

-- The middle of the top-down shading the art is drawn with.
local ART_SHADE = 0.62;

-- The game's own window look, following Config > Windows > Shared > Window Type. The colours and
-- sizes are craftbook's Classic theme, so the controls sit on the art the same way: buttons are a
-- see-through tint of the frame colour, input boxes a dark inset, the title bar solid.
local function classic_theme(window_type)
    local art    = WINDOW_ART[window_type] or WINDOW_ART[0];
    local panel  = shade(art.background, ART_SHADE);
    local accent = lighten(art.frame, 0.25);
    local light  = lighten(art.frame, 0.60);
    local text   = { 0.96, 0.96, 0.93, 1 };
    local inset  = { 0, 0, 0, 0.34 };
    return {
        palette = {
            abyss        = panel,
            surface1     = shade(panel, 0.80),
            surface2     = inset,
            border       = fade(accent, 0.55),
            subtle       = fade(accent, 0.25),
            text         = text,
            secondary    = { 0.88, 0.88, 0.85, 1 },
            peach        = { 1.00, 0.87, 0.48, 1 },
            muted        = { 0.72, 0.72, 0.70, 1 },
            faint        = { 0.56, 0.56, 0.55, 1 },
            button       = fade(accent, 0.30),
            button_hover = fade(accent, 0.48),
            royal        = fade(accent, 0.66),
            tint         = fade(accent, 0.24),
            hover        = fade(accent, 0.80),
            ember        = { 0.98, 0.82, 0.38, 1 },
            danger       = { 1.00, 0.52, 0.46, 1 },
            gold         = { 1.00, 0.87, 0.48, 1 },
            success      = { 0.52, 0.90, 0.52, 1 },
        },
        style = { window = 0.0, frame = 2.0 },
        imgui = {
            TitleBg              = shade(panel, 0.80),
            TitleBgActive        = shade(panel, 1.05),
            TitleBgCollapsed     = shade(panel, 0.80, 0.90),
            PopupBg              = shade(panel, 0.85, 0.98),
            Border               = fade(accent, 0.55),
            Separator            = fade(accent, 0.50),
            TextDisabled         = { 0.72, 0.72, 0.70, 1 },
            FrameBg              = inset,
            FrameBgHovered       = fade(accent, 0.24),
            FrameBgActive        = fade(accent, 0.36),
            Button               = fade(accent, 0.30),
            ButtonHovered        = fade(accent, 0.48),
            ButtonActive         = fade(accent, 0.66),
            Header               = fade(accent, 0.30),
            HeaderHovered        = fade(accent, 0.44),
            HeaderActive         = fade(accent, 0.58),
            CheckMark            = light,
            SliderGrab           = fade(light, 0.70),
            SliderGrabActive     = light,
            PlotHistogram        = fade(accent, 0.66),
            ScrollbarBg          = { 0, 0, 0, 0.30 },
            ScrollbarGrab        = fade(accent, 0.55),
            ScrollbarGrabHovered = fade(accent, 0.80),
            ScrollbarGrabActive  = light,
            TableHeaderBg        = inset,
            TableBorderStrong    = fade(accent, 0.45),
            TableBorderLight     = fade(accent, 0.25),
            -- Alternate rows only lift the art a touch: a solid fill would paint stripes across it.
            TableRowBgAlt        = { 1, 1, 1, 0.03 },
        },
        vars = {
            FramePadding     = { 8, 5 },
            ItemSpacing      = { 8, 6 },
            GrabRounding     = 2.0,
            ScrollbarSize    = 12.0,
            -- The frame comes from the art.
            WindowBorderSize = 0.0,
        },
        skin = window_type,
    };
end

-- In the order the settings panel lists them. Phoenix comes first and is the starting theme.
ui.THEMES = {
    { key = 'phoenix', label = 'Phoenix' },
    { key = 'classic', label = 'Classic' },
    { key = 'neutral', label = 'Neutral' },
};
ui.STARTING_THEME = 'phoenix';

local BUILDERS = { phoenix = phoenix_theme, classic = classic_theme, neutral = neutral_theme };

-- Matches a theme by key or label, ignoring case.
function ui.find_theme(text)
    local wanted = (text or ''):lower();
    for _, theme in ipairs(ui.THEMES) do
        if (theme.key == wanted or theme.label:lower() == wanted) then
            return theme.key;
        end
    end
    return nil;
end

function ui.theme_label(key)
    for _, theme in ipairs(ui.THEMES) do
        if (theme.key == key) then
            return theme.label;
        end
    end
    return ui.THEMES[1].label;
end

-- The game art is drawn by skin.lua, which needs Ashita's Direct3D bindings. It is loaded the first
-- time Classic is picked, and Classic keeps its flat colours if it can't load.
local skin_module = nil;

local function skin()
    if (skin_module == nil) then
        local ok, loaded = pcall(require, 'skin');
        skin_module = ok and loaded or false;
    end
    return skin_module or nil;
end

ui.COLOR = T{ clear = { 0, 0, 0, 0 } };

local COLOR   = ui.COLOR;
local current = { key = nil, window_type = nil, theme = nil };

-- Applies a theme, refilling ui.COLOR in place. pinned_type is a Window Type (0-7) for Classic to
-- keep, or -1 to follow the game. Cheap to call every frame: it only refills when something changed.
function ui.apply_theme(key, pinned_type)
    key = BUILDERS[key] and key or ui.STARTING_THEME;

    local window_type = nil;
    if (key == 'classic') then
        local module = skin();
        if (module) then
            window_type = module.window_type(pinned_type);
        elseif (pinned_type and pinned_type >= 0 and pinned_type <= 7) then
            window_type = pinned_type;
        else
            window_type = 0;
        end
    end
    if (current.key == key and current.window_type == window_type) then
        return current.theme;
    end

    local theme = BUILDERS[key](window_type);
    for name, color in pairs(theme.palette) do
        COLOR[name] = color;
    end
    current.key         = key;
    current.window_type = window_type;
    current.theme       = theme;
    return theme;
end

-- True when the active theme is drawing the game's window art, so ImGui's own fill is hidden.
local function art_showing()
    local theme  = current.theme;
    local module = theme and theme.skin and skin();
    return module and module.get(theme.skin) ~= nil or false;
end

-- Paints the game's window art behind the window that was just begun, when Classic is showing.
-- titled is whether the window has a title bar.
function ui.draw_skin(titled, alpha)
    local theme = current.theme;
    if (theme and theme.skin and art_showing()) then
        skin().draw(theme.skin, titled, alpha);
    end
end

-- Frees the window art's textures, for unloading the addon.
function ui.release_skin()
    if (skin_module) then
        skin_module.release();
    end
end

ui.apply_theme(ui.STARTING_THEME);

-----------------------------------
-- Messages and time
-----------------------------------
function ui.say(message)
    print(chat.header(addon.name):append(chat.message(message)));
end

function ui.warn(message)
    print(chat.header(addon.name):append(chat.warning(message)));
end

function ui.jst_day()
    return os.date('!%Y-%m-%d', os.time() + ui.JST_OFFSET);
end

function ui.seconds_until_reset()
    return 86400 - ((os.time() + ui.JST_OFFSET) % 86400);
end

function ui.duration(seconds)
    seconds = math.max(0, math.floor(seconds));
    local hours   = math.floor(seconds / 3600);
    local minutes = math.floor((seconds % 3600) / 60);
    if (hours > 0) then
        return ('%dh %02dm'):fmt(hours, minutes);
    end
    return ('%dm %02ds'):fmt(minutes, seconds % 60);
end

-----------------------------------
-- Drawing helpers
-----------------------------------
-- Ashita returns an ImVec2 either as a table or as two numbers, depending on the call.
function ui.vec2(a, b)
    if (type(a) == 'table') then
        return a.x or a[1], a.y or a[2];
    end
    return a, b;
end

function ui.text_width(text)
    local width = imgui.CalcTextSize(text);
    if (type(width) == 'table') then
        return width.x or width[1] or 0;
    end
    return width or 0;
end

function ui.right_text(width, color, text)
    imgui.SameLine(ui.PADDING + width - ui.text_width(text));
    imgui.TextColored(color, text);
end

function ui.stat_cell(label, value, color)
    imgui.TableNextColumn();
    imgui.TextColored(COLOR.muted, label);
    imgui.TextColored(color or COLOR.text, value);
end

function ui.toggle_button(label, on, width)
    imgui.PushStyleColor(ImGuiCol_Button, on and COLOR.royal or COLOR.button);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, on and COLOR.hover or COLOR.button_hover);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, COLOR.royal);
    imgui.PushStyleColor(ImGuiCol_Text, on and COLOR.text or COLOR.muted);
    local clicked = imgui.Button(label, { width, 0 });
    imgui.PopStyleColor(4);
    return clicked;
end

-- A progress bar for a value only known as a range: solid up to lo, faint from lo to hi.
function ui.range_bar(width, height, lo, hi, color)
    local x, y = ui.vec2(imgui.GetCursorScreenPos());
    local list = imgui.GetWindowDrawList();
    local faint = { color[1], color[2], color[3], 0.35 };
    lo = math.max(0, math.min(1, lo));
    hi = math.max(lo, math.min(1, hi));
    list:AddRectFilled({ x, y }, { x + width, y + height }, imgui.GetColorU32(COLOR.surface2), 4.0);
    if (hi > lo) then
        list:AddRectFilled({ x + width * lo, y }, { x + width * hi, y + height }, imgui.GetColorU32(faint), 0.0);
    end
    if (lo > 0) then
        list:AddRectFilled({ x, y }, { x + width * lo, y + height }, imgui.GetColorU32(color), 4.0);
    end
    imgui.Dummy({ width, height });
end

function ui.window_flags(locked)
    local flags = bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoCollapse);
    if (locked) then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove);
    end
    return flags;
end

-- Returns how many colours and style vars were pushed, for the matching pops.
function ui.push_theme(alpha)
    -- Under Classic the art carries the window's opacity, so ImGui's own fill is switched off.
    local fill = art_showing() and 0 or alpha;
    local style = current.theme.style;
    local colors = {
        { ImGuiCol_WindowBg,          { COLOR.abyss[1], COLOR.abyss[2], COLOR.abyss[3], fill } },
        { ImGuiCol_TitleBg,           COLOR.surface1 },
        { ImGuiCol_TitleBgActive,     COLOR.surface2 },
        { ImGuiCol_TitleBgCollapsed,  COLOR.surface1 },
        { ImGuiCol_Border,            COLOR.border   },
        { ImGuiCol_Separator,         COLOR.border   },
        { ImGuiCol_Text,              COLOR.text     },
        { ImGuiCol_TextDisabled,      COLOR.muted    },
        { ImGuiCol_FrameBg,           COLOR.surface2 },
        { ImGuiCol_FrameBgHovered,    COLOR.tint     },
        { ImGuiCol_FrameBgActive,     COLOR.surface2 },
        { ImGuiCol_SliderGrab,        COLOR.royal    },
        { ImGuiCol_SliderGrabActive,  COLOR.hover    },
        { ImGuiCol_PlotHistogram,     COLOR.royal    },
        { ImGuiCol_Header,            COLOR.surface2 },
        { ImGuiCol_HeaderHovered,     COLOR.tint     },
        { ImGuiCol_HeaderActive,      COLOR.royal    },
        { ImGuiCol_TableHeaderBg,     COLOR.surface2 },
        { ImGuiCol_TableBorderLight,  COLOR.subtle   },
        { ImGuiCol_TableBorderStrong, COLOR.border   },
        { ImGuiCol_TableRowBg,        COLOR.clear    },
        { ImGuiCol_TableRowBgAlt,     COLOR.surface1 },
        { ImGuiCol_PopupBg,           COLOR.surface1 },
        { ImGuiCol_CheckMark,         COLOR.royal    },
        { ImGuiCol_Button,            COLOR.royal    },
        { ImGuiCol_ButtonHovered,     COLOR.hover    },
        { ImGuiCol_ButtonActive,      COLOR.royal    },
        { ImGuiCol_ScrollbarBg,       COLOR.abyss    },
        { ImGuiCol_ScrollbarGrab,     COLOR.surface2 },
        { ImGuiCol_ResizeGrip,        COLOR.clear    },
    };
    for _, color in ipairs(colors) do
        imgui.PushStyleColor(color[1], color[2]);
    end
    -- A theme's own ImGui colours go on top. Names this ImGui build lacks are skipped.
    local pushed = #colors;
    for name, value in pairs(current.theme.imgui or {}) do
        local enum = _G['ImGuiCol_' .. name];
        if (enum ~= nil) then
            imgui.PushStyleColor(enum, value);
            pushed = pushed + 1;
        end
    end

    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, style.window);
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, style.frame);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { ui.PADDING, 10 });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 8, 5 });
    imgui.PushStyleVar(ImGuiStyleVar_CellPadding, { 4, 3 });
    local vars = 5;
    for name, value in pairs(current.theme.vars or {}) do
        local enum = _G['ImGuiStyleVar_' .. name];
        if (enum ~= nil) then
            imgui.PushStyleVar(enum, value);
            vars = vars + 1;
        end
    end

    return pushed, vars;
end

-----------------------------------
-- Game memory
-----------------------------------
-- The client's current weather, so a tab knows it before the next zone or weather packet arrives.
-- Returns nil if it can't be found in this version of the game client.
local weather_address;

function ui.weather()
    if (not weather_address) then
        local found = ashita.memory.find('FFXiMain.dll', 0, '66A1????????663D????72', 0, 0);
        weather_address = (found and found ~= 0) and ashita.memory.read_uint32(found + 0x02) or 0;
    end
    if (weather_address == 0) then
        return nil;
    end
    return ashita.memory.read_uint8(weather_address);
end

-----------------------------------
-- Packet helpers
-----------------------------------
function ui.u16(data, offset)
    local low, high = data:byte(offset + 1, offset + 2);
    return (low or 0) + (high or 0) * 256;
end

function ui.u32(data, offset)
    return ui.u16(data, offset) + ui.u16(data, offset + 2) * 65536;
end

-- Saved daily data lives beside Ashita's own settings for the addon.
function ui.data_folder(addon_name)
    return ('%s\\config\\addons\\%s\\'):fmt(AshitaCore:GetInstallPath(), addon_name or addon.name);
end

-- addon_name reads another addon's saved data, for picking up counts from the standalone versions.
function ui.read_data(name, addon_name)
    local chunk = loadfile(ui.data_folder(addon_name) .. name);
    if (not chunk) then
        return T{};
    end
    local ok, data = pcall(chunk);
    if (not ok or type(data) ~= 'table') then
        return T{};
    end
    return data;
end

-- Keep the shared fishing count when moving from PhoenixFishTrack. Ashita's settings
-- identity is available before the party memory updates during a character switch.
function ui.migrate_fishing_account(current, name, server_id)
    if (current.fish_account_migrated or not name or name == '' or not server_id or server_id == 0) then
        return false;
    end

    local legacy = ui.read_data(('%s_%d\\settings.lua'):fmt(name, server_id), 'phoenixfishtrack');
    if (current.account == '' and type(legacy.account) == 'string') then
        current.account = legacy.account;
    end
    current.fish_account_migrated = true;
    return true;
end

function ui.write_data(name, body)
    local folder = ui.data_folder();
    if (not ashita.fs.exists(folder)) then
        ashita.fs.create_directory(folder);
    end
    local file = io.open(folder .. name, 'w');
    if (not file) then
        return;
    end
    file:write(body);
    file:close();
end

return ui;
