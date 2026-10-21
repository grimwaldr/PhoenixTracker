-- Reads textures out of the game's DAT files, held in memory as a string. Pure Lua: it touches no
-- files, no game and no graphics, so it can be tested on its own. skin.lua reads the files and
-- turns these into textures.
--
-- A DAT is a list of chunks, each with a 16-byte header. A texture chunk holds a flag byte, a 16
-- character name, a bitmap header, the format tag ("DXT1" to "DXT5", stored backwards) and the raw
-- DXT blocks. The layout was worked out for craftbook by Frankie-hz (GPLv3).
local datfile = {};

local CHUNK_HEADER  = 16;
local TEXTURE_CHUNK = 0x20;
local DXT_TEXTURE   = 0xA1;
local NAME_FIRST    = 10;
local NAME_LAST     = 17;
local INFO_OFFSET   = 17;
local FORMAT_EXTRA  = 12;

local DDS_HEADER_SIZE = 124;
local DDS_FLAGS       = 0x81007;
local DDS_PIXELFORMAT = 32;
local DDS_FOURCC      = 0x4;
local DDS_TEXTURE     = 0x1000;

function datfile.u32(data, offset)
    local a, b, c, d = data:byte(offset + 1, offset + 4);
    return a + b * 256 + c * 65536 + d * 16777216;
end

local u32 = datfile.u32;

local function write_u32(value)
    return string.char(value % 256, math.floor(value / 256) % 256, math.floor(value / 65536) % 256, math.floor(value / 16777216) % 256);
end

-- Wraps raw DXT blocks in a DDS header so D3DX can load them as a file.
function datfile.as_dds(width, height, fourcc, blocks)
    local zero = write_u32(0);
    return table.concat({
        'DDS ', write_u32(DDS_HEADER_SIZE), write_u32(DDS_FLAGS), write_u32(height), write_u32(width), write_u32(#blocks), zero, zero,
        zero:rep(11),
        write_u32(DDS_PIXELFORMAT), write_u32(DDS_FOURCC), fourcc, zero:rep(5),
        write_u32(DDS_TEXTURE), zero:rep(4),
        blocks,
    });
end

-- One texture chunk's body as { name, width, height, fourcc, blocks }, or nil if it isn't a DXT texture.
local function read_texture(body)
    if (#body < INFO_OFFSET + 12 or body:byte(1) ~= DXT_TEXTURE) then
        return nil;
    end

    local name   = body:sub(NAME_FIRST, NAME_LAST):gsub('%s+$', '');
    local width  = u32(body, INFO_OFFSET + 4);
    local height = u32(body, INFO_OFFSET + 8);
    local format = INFO_OFFSET + u32(body, INFO_OFFSET);
    local fourcc = body:sub(format + 1, format + 4):reverse();
    if (fourcc:match('^DXT[1-5]$') == nil) then
        return nil;
    end

    local block_size = (fourcc == 'DXT1') and 8 or 16;
    local length     = math.ceil(width / 4) * math.ceil(height / 4) * block_size;
    local blocks     = body:sub(format + FORMAT_EXTRA + 1, format + FORMAT_EXTRA + length);
    if (#blocks ~= length) then
        return nil;
    end
    return { name = name, width = width, height = height, fourcc = fourcc, blocks = blocks };
end

-- Every texture in the data whose name is in wanted (a set), keyed by name. The window art files hold
-- a handful of chunks and the font file a few hundred, so max_chunks bounds the walk.
function datfile.textures(data, wanted, max_chunks)
    local found  = {};
    local offset = 0;
    for _ = 1, max_chunks or 32 do
        if (offset + CHUNK_HEADER > #data) then
            break;
        end
        local packed = u32(data, offset + 4);
        local kind   = packed % 128;
        local size   = (math.floor(packed / 128) % 0x80000) * 16;
        if (size == 0) then
            break;
        end
        if (kind == TEXTURE_CHUNK) then
            local texture = read_texture(data:sub(offset + CHUNK_HEADER + 1, offset + size));
            if (texture and (wanted == nil or wanted[texture.name])) then
                found[texture.name] = texture;
            end
        end
        offset = offset + size;
    end
    return found;
end

-- The game's text font ('moji') keeps one character in each 16 x 16 cell, 64 cells a row, starting
-- at the space character. Each letter is only as wide as its drawn pixels, which this reads from
-- the DXT3 alpha of the plain ASCII rows: { [code] = { left = first column, width = columns } }.
-- Characters with nothing drawn (the space) are left out.
datfile.CELL    = 16;
datfile.PER_ROW = 64;

function datfile.glyph_widths(texture, first, last)
    if (texture.fourcc ~= 'DXT3') then
        return nil;
    end
    local cell, per_row = datfile.CELL, datfile.PER_ROW;
    local blocks_wide   = math.ceil(texture.width / 4);
    local blocks        = texture.blocks;

    -- A DXT3 block is 16 bytes: 8 bytes of alpha, 4 bits a pixel in rows of 4, then the colour.
    local function alpha(x, y)
        local block = math.floor(y / 4) * blocks_wide + math.floor(x / 4);
        local pixel = (y % 4) * 4 + (x % 4);
        local byte  = blocks:byte(block * 16 + math.floor(pixel / 2) + 1) or 0;
        if (pixel % 2 == 0) then
            return byte % 16;
        end
        return math.floor(byte / 16);
    end

    local widths = {};
    for code = first or 0x21, last or 0x7E do
        local index = code - 0x20;
        local cx    = (index % per_row) * cell;
        local cy    = math.floor(index / per_row) * cell;
        local left, right = nil, nil;
        for x = 0, cell - 1 do
            for y = 0, cell - 1 do
                if (alpha(cx + x, cy + y) > 0) then
                    left  = left or x;
                    right = x;
                    break;
                end
            end
        end
        if (left ~= nil) then
            widths[code] = { left = left, width = right - left + 1 };
        end
    end
    return widths;
end

return datfile;
