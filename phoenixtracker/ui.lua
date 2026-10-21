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
            -- Unselected toggle buttons darken the art, so their labels stand out and the selected
            -- one (royal) reads as lit.
            button       = { 0, 0, 0, 0.38 },
            button_hover = fade(accent, 0.30),
            royal        = fade(accent, 0.66),
            tint         = fade(accent, 0.24),
            hover        = fade(accent, 0.80),
            ember        = { 0.98, 0.82, 0.38, 1 },
            danger       = { 1.00, 0.52, 0.46, 1 },
            gold         = { 1.00, 0.87, 0.48, 1 },
            success      = { 0.52, 0.90, 0.52, 1 },
        },
        style = { window = 0.0, frame = 2.0 },
        -- Unselected button labels. Muted grey on the grey-tinted buttons was too hard to read over
        -- the art, so they sit just below the selected label instead.
        off_label = { 0.86, 0.86, 0.83, 1 },
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
        skin    = window_type,
        -- Text is drawn the way the game draws its own: a dark outline and a slightly heavier stroke.
        outline = true,
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

-----------------------------------
-- The game's own font
-----------------------------------
-- Classic draws plain text in the game's own font, read from the player's install by skin.lua: each
-- letter is cut from the font sheet (16 x 16 cells, the outline already drawn in) and drawn at its own
-- width, tinted with the text colour. It's a bitmap that only looks right at its own size, so it's
-- used when the window is at scale 1 and the text is the normal size; anything else uses the normal
-- font with an outline.
local CELL  = 16;
local GAP   = 1;    -- pixels between letters, as the game spaces its chat
local SPACE = 4;    -- the width of a space

local frame = { scale = 1, base = nil, game_font = true };

local function plain(text)
    return type(text) == 'string' and not text:find('[^\32-\126]');
end

-- Call once a frame, before any window is drawn: the window's scale, and whether Classic may use
-- the game font.
function ui.begin_frame(scale, game_font)
    frame.scale     = scale;
    frame.game_font = game_font ~= false;
    frame.base      = imgui.GetFontSize();
end

-- The game font, when it should draw text at the current size; otherwise nil.
local function game_font()
    local theme = current.theme;
    if (not theme or not theme.outline or not frame.game_font or frame.scale ~= 1 or not frame.base) then
        return nil;
    end
    if (math.abs(imgui.GetFontSize() - frame.base) > 0.01) then
        return nil;
    end
    local module = skin();
    return module and module.font and module.font() or nil;
end

-- The gap only goes between letters, so centred and right-aligned text lands on the exact middle or
-- edge rather than a pixel short of it.
local function game_width(font, text)
    local width = 0;
    local glyph = nil;
    for index = 1, #text do
        glyph = font.glyphs[text:byte(index)];
        width = width + (glyph and (glyph.width + GAP) or SPACE);
    end
    if (glyph) then
        width = width - GAP;
    end
    return width;
end

-- The game font's own dark edge is only a shadow on the right and bottom, so over the lighter art
-- the top and left of each letter faded out. A dark copy one pixel out each way rings every letter.
local RING       = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } };
local RING_ALPHA = 0.9;

-- Draws the letters on whole pixels, centred in the line, as the game draws its own.
local function draw_game_text(list, font, x, y, color, text)
    local x0   = math.floor(x + 0.5);
    local y0   = math.floor(y + (imgui.GetTextLineHeight() - CELL) / 2 + 0.5);
    local fill = imgui.GetColorU32(color);
    local dark = imgui.GetColorU32({ 0, 0, 0, RING_ALPHA * (color[4] or 1) });
    -- Every ring first, so one letter's ring never covers the letter before it.
    for pass = 1, 2 do
        local left = x0;
        for index = 1, #text do
            local code  = text:byte(index);
            local glyph = font.glyphs[code];
            if (glyph) then
                local cell = code - 0x20;
                local u    = (cell % 64) * CELL + glyph.left;
                local v    = math.floor(cell / 64) * CELL;
                local uv0  = { u / font.width, v / font.height };
                local uv1  = { (u + glyph.width) / font.width, (v + CELL) / font.height };
                if (pass == 1) then
                    for _, offset in ipairs(RING) do
                        local ox, oy = left + offset[1], y0 + offset[2];
                        list:AddImage(font.id, { ox, oy }, { ox + glyph.width, oy + CELL }, uv0, uv1, dark);
                    end
                else
                    list:AddImage(font.id, { left, y0 }, { left + glyph.width, y0 + CELL }, uv0, uv1, fill);
                end
                left = left + glyph.width + GAP;
            else
                left = left + SPACE;
            end
        end
    end
end

-- How far the game digits overlap (they lean, and their outlines touch), the room after them, and how
-- far down the line beside them sits so its letters rest on the digits' baseline.
local DIGIT_OVERLAP = 2;
local DIGIT_AFTER   = 6;
local DIGIT_DROP    = 9;

-- Draws a large count: in the game's own italic digits under Classic with the game font, else in the
-- given font at twice the size. Leaves the cursor on the same line for what follows it, and returns
-- how far that should move down to sit on the count's baseline.
function ui.big_number(color, text, font, font_size)
    local game    = game_font();
    local numbers = game and game.numbers;
    if (numbers and text:match('^%d+$')) then
        local list   = imgui.GetWindowDrawList();
        local x, y   = ui.vec2(imgui.GetCursorScreenPos());
        local height = numbers.bottom - numbers.top;
        local left   = math.floor(x + 0.5);
        local top    = math.floor(y + 0.5);
        local tint   = imgui.GetColorU32(color);
        for index = 1, #text do
            local box = numbers.digits[text:sub(index, index)];
            list:AddImage(numbers.id, { left, top }, { left + box[2] - box[1], top + height },
                { box[1] / numbers.width, numbers.top / numbers.height }, { box[2] / numbers.width, numbers.bottom / numbers.height }, tint);
            left = left + box[2] - box[1] - DIGIT_OVERLAP;
        end
        imgui.Dummy({ left + DIGIT_OVERLAP - x, height });
        imgui.SameLine(0, DIGIT_AFTER);
        return DIGIT_DROP - (imgui.GetTextLineHeight() - CELL) / 2;
    end

    local small = imgui.GetFontSize();
    imgui.PushFont(font, font_size * 2.0);
    local big = imgui.GetFontSize();
    ui.text(color, text);
    imgui.PopFont();
    imgui.SameLine();
    return (big - small) * 0.8;
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

-----------------------------------
-- Active time
-----------------------------------
-- A session clock that only runs while you're doing the activity. It starts with an action (a cast,
-- a dig, a gather) and keeps running until ACTIVE_GRACE seconds after the last one ends, so walking
-- off, a town trip or being away doesn't count. An action that never reports its end stops counting
-- after ACTIVE_LONGEST seconds.
ui.ACTIVE_GRACE   = 30;
ui.ACTIVE_LONGEST = 180;

function ui.new_clock()
    return { banked = 0, from = nil, stop_at = nil };
end

-- An action began. now defaults to os.time().
function ui.clock_start(clock, now)
    if (clock.held) then
        return;
    end
    now = now or os.time();
    if (clock.from ~= nil and now >= clock.stop_at) then
        clock.banked = clock.banked + (clock.stop_at - clock.from);
        clock.from   = nil;
    end
    clock.from    = clock.from or now;
    clock.stop_at = now + ui.ACTIVE_LONGEST;
end

-- An action ended. For one with no separate end (a dig, a gather), call it right after clock_start.
function ui.clock_finish(clock, now)
    if (clock.held) then
        return;
    end
    now = now or os.time();
    if (clock.from == nil or now >= clock.stop_at) then
        ui.clock_start(clock, now);
    end
    clock.stop_at = now + ui.ACTIVE_GRACE;
end

-- Seconds of active time so far, and whether the clock is paused.
function ui.clock_seconds(clock, now)
    now = now or os.time();
    if (clock == nil or clock.from == nil) then
        return clock and clock.banked or 0, true;
    end
    return clock.banked + (math.min(now, clock.stop_at) - clock.from), now >= clock.stop_at;
end

-- The Session grid's Active cell: the label (Active, or Paused once you've stopped) and the time.
-- Once the daily limit is reached it just shows the time it took.
function ui.active_cell(clock)
    local seconds, paused = ui.clock_seconds(clock);
    if (seconds <= 0) then
        return 'Active', '-', nil;
    end
    if (clock.held) then
        return 'Active', ui.duration(seconds), nil;
    end
    return paused and 'Paused' or 'Active', ui.duration(seconds), paused and COLOR.gold or nil;
end

-- Holds a session's clocks while held is true (the daily limit is reached, so there's nothing left
-- to do until the reset), and lets them run again once it isn't. Total stops where Active does.
-- The session keeps started (its first action), total (time banked) and clock.
function ui.session_hold(session, held, now)
    now = now or os.time();
    local clock = session.clock;
    if (held and not clock.held) then
        local seconds = ui.clock_seconds(clock, now);
        clock.banked, clock.from, clock.stop_at = seconds, nil, nil;
        clock.held = true;
        if (session.started) then
            session.total   = (session.total or 0) + (now - session.started);
            session.started = nil;
        end
    elseif (not held and clock.held) then
        clock.held      = nil;
        session.started = nil;
    end
end

-- Seconds from the session's first action, stopping at the daily limit.
function ui.session_total(session, now)
    now = now or os.time();
    local total = session.total or 0;
    if (session.started and not session.clock.held) then
        total = total + (now - session.started);
    end
    return total;
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
    -- Style values such as FramePadding arrive as ImGui vector objects with x and y fields.
    if (a ~= nil and type(a) ~= 'number') then
        return a.x, a.y;
    end
    return a, b;
end

function ui.text_width(text)
    local font = plain(text) and game_font();
    if (font) then
        return game_width(font, text);
    end
    local width = imgui.CalcTextSize(text);
    if (type(width) == 'table') then
        return width.x or width[1] or 0;
    end
    return width or 0;
end

-----------------------------------
-- Game-style text
-----------------------------------
-- Themes with outline set (Classic) draw text the way the game draws its own: eight dark copies
-- one pixel out on every side for the outline, then the text twice, 0.6 pixels apart, for a slightly
-- heavier stroke. It uses the font ImGui already has; nothing is loaded into ImGui's font atlas.
-- The idea comes from Reverie's phoenixchat. Text with characters outside plain ASCII, such as
-- Japanese names, is drawn the normal way.
local OUTLINE = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } };
local aligned_y = nil;

local function outlined()
    return current.theme ~= nil and current.theme.outline == true;
end

-- Draws text at a screen position: in the game font when it applies, else outlined when the theme
-- asks for it. color is an RGBA table.
function ui.add_text(list, x, y, color, text)
    local game = plain(text) and game_font();
    if (game) then
        draw_game_text(list, game, x, y, color, text);
        return;
    end
    local font  = imgui.GetFont();
    local size  = imgui.GetFontSize();
    local fill  = imgui.GetColorU32(color);
    if (outlined()) then
        local reach = math.max(1, math.floor(size / 24 + 0.5));
        local dark  = imgui.GetColorU32({ 0, 0, 0, color[4] or 1 });
        for _, offset in ipairs(OUTLINE) do
            list:AddText(font, size, { x + offset[1] * reach, y + offset[2] * reach }, dark, text);
        end
        list:AddText(font, size, { x + 0.6, y }, fill, text);
    end
    list:AddText(font, size, { x, y }, fill, text);
end

-- Use in place of imgui.AlignTextToFramePadding, so text on this line lines up with the buttons
-- beside it under every theme.
function ui.align_to_frame()
    imgui.AlignTextToFramePadding();
    local _, y = ui.vec2(imgui.GetCursorScreenPos());
    aligned_y = y;
end

-- Use in place of imgui.TextColored.
function ui.text(color, text)
    if (not outlined() or not plain(text)) then
        imgui.TextColored(color, text);
        return;
    end

    local x, y   = ui.vec2(imgui.GetCursorScreenPos());
    local height = imgui.GetTextLineHeight();
    -- On a line lined up with buttons, text sits down by the frame padding, as ImGui's own does.
    if (aligned_y ~= nil and math.abs(y - aligned_y) < 0.5) then
        local _, pad = ui.vec2(imgui.GetStyle().FramePadding);
        y      = y + pad;
        height = imgui.GetFrameHeight();
    end
    ui.add_text(imgui.GetWindowDrawList(), x, y, color, text);
    imgui.Dummy({ math.max(ui.text_width(text), 1), height });
end

-- Text that wraps before wrap_x (in window coordinates, as imgui.PushTextWrapPos takes).
-- Splits text into the lines it takes up in `room` pixels, breaking between words as ImGui does.
local function wrap_lines(text, room)
    local lines = {};
    local line  = '';
    for word in text:gmatch('%S+') do
        local longer = (line == '') and word or (line .. ' ' .. word);
        if (line ~= '' and ui.text_width(longer) > room) then
            lines[#lines + 1] = line;
            line = word;
        else
            line = longer;
        end
    end
    if (line ~= '') then
        lines[#lines + 1] = line;
    end
    return lines;
end

-- Draws lines of text at the cursor and takes up `keep` lines of room (at least as many as drawn).
local function draw_lines(color, lines, keep)
    local x, y   = ui.vec2(imgui.GetCursorScreenPos());
    local height = imgui.GetTextLineHeight();
    local list   = imgui.GetWindowDrawList();
    local widest = 1;
    for index, piece in ipairs(lines) do
        ui.add_text(list, x, y + (index - 1) * height, color, piece);
        widest = math.max(widest, ui.text_width(piece));
    end
    imgui.Dummy({ widest, math.max(1, #lines, keep or 0) * height });
end

function ui.wrapped(color, text, wrap_x)
    if (not outlined() or not plain(text)) then
        imgui.PushTextWrapPos(wrap_x);
        imgui.TextColored(color, text);
        imgui.PopTextWrapPos();
        return;
    end

    draw_lines(color, wrap_lines(text, wrap_x - imgui.GetCursorPosX()));
end

-- Like ui.wrapped, for a spot whose message changes as you play: it always takes up the room of the
-- tallest message in `alike`, so the auto-sized window keeps its height when the message changes.
function ui.wrapped_steady(color, text, wrap_x, alike)
    local room = wrap_x - imgui.GetCursorPosX();
    local keep = 1;
    for _, other in ipairs(alike) do
        keep = math.max(keep, #wrap_lines(other, room));
    end
    draw_lines(color, wrap_lines(text, room), keep);
end

-- Use in place of imgui.CollapsingHeader. Under an outlined theme ImGui draws the header with its
-- text see-through, so it keeps the same ID (and open or closed state) but shows no label or arrow
-- of its own; the arrow is drawn here the way ImGui draws it, and the label in the theme's text.
function ui.header(label, flags)
    if (not outlined() or not plain(label)) then
        return imgui.CollapsingHeader(label, flags);
    end

    -- Where ImGui puts a framed header's arrow and label: from the cursor (the frame itself reaches a
    -- little further left), inside the frame padding, the label past the arrow.
    local x, y         = ui.vec2(imgui.GetCursorScreenPos());
    local pad_x, pad_y = ui.vec2(imgui.GetStyle().FramePadding);
    local size         = imgui.GetFontSize();
    imgui.PushStyleColor(ImGuiCol_Text, COLOR.clear);
    local open = imgui.CollapsingHeader(label, flags);
    imgui.PopStyleColor(1);

    -- ImGui's arrow: a triangle 0.4 of the font size from the centre of a font-sized square.
    local list   = imgui.GetWindowDrawList();
    local cx, cy = x + pad_x + size * 0.5, y + pad_y + size * 0.5;
    local r      = size * 0.40;
    local fill   = imgui.GetColorU32(COLOR.text);
    if (open) then
        list:AddTriangleFilled({ cx, cy + 0.75 * r }, { cx + 0.866 * r, cy - 0.75 * r }, { cx - 0.866 * r, cy - 0.75 * r }, fill);
    else
        list:AddTriangleFilled({ cx + 0.75 * r, cy }, { cx - 0.75 * r, cy + 0.866 * r }, { cx - 0.75 * r, cy - 0.866 * r }, fill);
    end
    ui.add_text(list, x + size + pad_x * 3, y + pad_y, COLOR.text, label);
    return open;
end

function ui.right_text(width, color, text)
    imgui.SameLine(ui.PADDING + width - ui.text_width(text));
    ui.text(color, text);
end

function ui.stat_cell(label, value, color)
    imgui.TableNextColumn();
    ui.text(COLOR.muted, label);
    ui.text(color or COLOR.text, value);
end

function ui.toggle_button(label, on, width)
    local off = (current.theme and current.theme.off_label) or COLOR.muted;
    imgui.PushStyleColor(ImGuiCol_Button, on and COLOR.royal or COLOR.button);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, on and COLOR.hover or COLOR.button_hover);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, COLOR.royal);
    imgui.PushStyleColor(ImGuiCol_Text, on and COLOR.text or off);
    local shown = label:match('^(.-)##') or label;
    if (not outlined() or shown == '' or not plain(shown)) then
        local clicked = imgui.Button(label, { width, 0 });
        imgui.PopStyleColor(4);
        return clicked;
    end

    -- The button draws no label of its own; the outlined one goes in its centre.
    local clicked = imgui.Button('##' .. label, { width, 0 });
    imgui.PopStyleColor(4);
    local x0, y0 = ui.vec2(imgui.GetItemRectMin());
    local x1, y1 = ui.vec2(imgui.GetItemRectMax());
    local x = (x0 + x1 - ui.text_width(shown)) / 2;
    local y = (y0 + y1 - imgui.GetTextLineHeight()) / 2;
    ui.add_text(imgui.GetWindowDrawList(), x, y, on and COLOR.text or off, shown);
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
