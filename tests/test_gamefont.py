"""The game's own font in Classic: reading letter widths from the font sheet, and when it's used."""

import unittest

from support import Harness

SHEET_WIDTH = 1024
ROWS = 32          # the two rows of 16 x 16 cells that hold the plain ASCII letters


def dxt3_sheet(pixels):
    """DXT3 blocks for a 1024 x 32 sheet with the given (x, y) pixels opaque."""
    blocks_wide = SHEET_WIDTH // 4
    data = bytearray(blocks_wide * (ROWS // 4) * 16)
    for x, y in pixels:
        block = (y // 4) * blocks_wide + (x // 4)
        pixel = (y % 4) * 4 + (x % 4)
        index = block * 16 + pixel // 2
        data[index] |= 0x0F if pixel % 2 == 0 else 0xF0
    return bytes(data)


def cell_origin(char):
    index = ord(char) - 0x20
    return (index % 64) * 16, (index // 64) * 16


class GlyphWidthTests(unittest.TestCase):
    def setUp(self):
        self.h = Harness()
        self.datfile = self.h.load('datfile')

    def texture(self, pixels, fourcc='DXT3'):
        return self.h.table({'width': SHEET_WIDTH, 'height': ROWS, 'fourcc': fourcc,
                             'blocks': dxt3_sheet(pixels)})

    def test_each_letter_is_as_wide_as_its_drawn_columns(self):
        ax, ay = cell_origin('A')
        ix, iy = cell_origin('i')
        pixels = [(ax + x, ay + y) for x in range(3, 10) for y in range(2, 13)]
        pixels += [(ix + 5, iy + 4), (ix + 6, iy + 9)]
        widths = self.datfile.glyph_widths(self.texture(pixels))
        self.assertEqual((widths[ord('A')]['left'], widths[ord('A')]['width']), (3, 7))
        self.assertEqual((widths[ord('i')]['left'], widths[ord('i')]['width']), (5, 2))

    def test_letters_with_nothing_drawn_are_left_out(self):
        widths = self.datfile.glyph_widths(self.texture([]))
        self.assertIsNone(widths[ord('B')])
        self.assertIsNone(widths[ord(' ')])

    def test_only_dxt3_sheets_are_read(self):
        self.assertIsNone(self.datfile.glyph_widths(self.texture([], fourcc='DXT1')))


# A stand-in for the game font: every letter five pixels wide.
FAKE_FONT = r'''
local glyphs = {}
for code = 0x21, 0x7E do glyphs[code] = { left = 0, width = 5 } end
package.preload.skin = function()
    return {
        window_type = function(pinned) return (pinned and pinned >= 0) and pinned or 0 end,
        get = function() return nil end,
        font = function() return { id = 77, width = 1024, height = 2048, glyphs = glyphs } end,
        release = function() end,
        draw = function() end,
    }
end
'''


class GameFontTests(unittest.TestCase):
    def setUp(self):
        self.h = Harness()
        self.h.lua.execute(FAKE_FONT)
        self.h.start_main()
        self.ui = self.h.load('ui')

    def render(self):
        self.h.lua.execute('drawn_images = {}; drawn_text = {}')
        self.h.dispatch('d3d_present')

    def images(self):
        return len(list(self.h.lua.globals().drawn_images.values()))

    def test_classic_at_scale_one_measures_and_draws_in_the_game_font(self):
        self.h.dispatch('command', command='/ptrack theme classic 2', blocked=False)
        self.render()
        # Five pixels a letter, one between letters, four for a space.
        self.assertEqual(self.ui.text_width('AB'), 12)
        self.assertEqual(self.ui.text_width('A B'), 16)
        self.assertGreater(self.images(), 0)

    def test_the_game_font_is_only_used_at_scale_one(self):
        self.h.dispatch('command', command='/ptrack theme classic 2', blocked=False)
        self.h.settings.scale = 1.5
        self.render()
        self.assertEqual(self.images(), 0)
        self.assertNotEqual(self.ui.text_width('AB'), 12)

    def test_other_themes_never_use_it(self):
        for theme in ('phoenix', 'neutral'):
            with self.subTest(theme=theme):
                self.h.settings.theme = theme
                self.render()
                self.assertEqual(self.images(), 0)

    def test_font_outline_switches_classic_back_to_the_outlined_normal_font(self):
        self.h.dispatch('command', command='/ptrack theme classic 2', blocked=False)
        self.h.dispatch('command', command='/ptrack font outline', blocked=False)
        self.assertFalse(self.h.settings.game_font)
        self.render()
        self.assertEqual(self.images(), 0)
        self.assertGreater(len(list(self.h.lua.globals().drawn_text.values())), 0)
        self.h.dispatch('command', command='/ptrack font game', blocked=False)
        self.assertTrue(self.h.settings.game_font)

    def test_a_bad_font_choice_is_refused(self):
        self.h.dispatch('command', command='/ptrack font comic', blocked=False)
        self.assertTrue(self.h.settings.game_font)
        self.assertIn('Usage: /ptrack font <game | outline>', self.h.messages)


if __name__ == '__main__':
    unittest.main()
