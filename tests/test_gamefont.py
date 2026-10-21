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


class DoubleAlphaTests(unittest.TestCase):
    def test_alpha_doubles_up_to_opaque_and_colour_is_untouched(self):
        h = Harness()
        datfile = h.load('datfile')
        alpha = bytes([0x00, 0x21, 0x84, 0xFF, 0x77, 0x08, 0x80, 0x10])
        colour = bytes(range(8))
        doubled = datfile.double_alpha(h.table({'name': 'font', 'width': 4, 'height': 4, 'fourcc': 'DXT3',
                                                'blocks': alpha + colour}))
        as_bytes = h.lua.eval('function(t) return { t.blocks:byte(1, -1) } end')
        self.assertEqual(bytes(as_bytes(doubled).values()),
                         bytes([0x00, 0x42, 0xF8, 0xFF, 0xEE, 0x0F, 0xF0, 0x20]) + colour)
        self.assertIsNone(datfile.double_alpha(h.table({'fourcc': 'DXT1', 'blocks': b''})))

    def test_black_specks_in_a_drawn_outline_take_the_outline_grey(self):
        h = Harness()
        datfile = h.load('datfile')
        grey, black = 0x2800, 0x0000                 # red 41ish and 0, as the digit outlines are
        # Pixel 0 drawn and black (index 1), pixel 1 drawn and grey (index 0), pixel 2 see-through
        # and black, the rest see-through grey.
        alpha = bytes([0xFF, 0x00]) + bytes(6)
        colour = grey.to_bytes(2, 'little') + black.to_bytes(2, 'little') + bytes([0b00000001, 0b00000000, 0, 0])
        block = alpha + colour
        evened = datfile.even_outline(h.table({'name': 'font', 'width': 4, 'height': 4, 'fourcc': 'DXT3', 'blocks': block}))
        as_bytes = h.lua.eval('function(t) return { t.blocks:byte(1, -1) } end')
        out = bytes(as_bytes(evened).values())
        self.assertEqual(out[:12], block[:12])
        self.assertEqual(out[12] & 0b11, 0)          # the drawn black pixel now uses the grey
        self.assertEqual(out[12] & 0b110000, 0)      # the see-through one was left alone
        self.assertIsNone(datfile.even_outline(h.table({'fourcc': 'DXT1', 'blocks': b''})))

    def test_each_digit_box_is_inside_the_sheet_and_in_order(self):
        digits = Harness().load('datfile').DIGITS
        boxes = [tuple(digits[str(d)].values()) for d in range(10)]
        for left, right in boxes:
            self.assertTrue(0 <= left < right <= 256)
        self.assertEqual(boxes, sorted(boxes))


# A stand-in for the game font: every letter five pixels wide.
FAKE_FONT = r'''
local glyphs = {}
fake_numbers = nil
for code = 0x21, 0x7E do glyphs[code] = { left = 0, width = 5 } end
package.preload.skin = function()
    return {
        window_type = function(pinned) return (pinned and pinned >= 0) and pinned or 0 end,
        get = function() return nil end,
        font = function() return { id = 77, width = 1024, height = 2048, glyphs = glyphs, numbers = fake_numbers } end,
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
        # Five pixels a letter, one between letters, four for a space, nothing after the last letter.
        self.assertEqual(self.ui.text_width('AB'), 11)
        self.assertEqual(self.ui.text_width('A B'), 15)
        self.assertGreater(self.images(), 0)

    def test_the_game_font_is_only_used_at_scale_one(self):
        self.h.dispatch('command', command='/ptrack theme classic 2', blocked=False)
        self.h.settings.scale = 1.5
        self.render()
        self.assertEqual(self.images(), 0)
        self.assertNotEqual(self.ui.text_width('AB'), 11)

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

    def test_each_letter_is_drawn_with_a_ring_then_its_fill(self):
        self.h.dispatch('command', command='/ptrack theme classic 2', blocked=False)
        self.render()
        self.h.lua.execute('drawn_images = {}')
        self.ui.text(self.ui.COLOR.text, 'AB')
        # Eight ring copies and one fill for each of the two letters.
        self.assertEqual(self.images(), 18)

    def use_numbers(self):
        self.h.lua.execute("fake_numbers = { id = 88, width = 256, height = 256, top = 131, bottom = 154, "
                           "digits = require('datfile').DIGITS }")

    def big(self, text):
        self.h.lua.execute('drawn_images = {}; drawn_text = {}')
        drop = self.ui.big_number(self.ui.COLOR.text, text, self.h.lua.eval('{}'), 16)
        return drop, [i for i in self.h.lua.globals().drawn_images.values()]

    def test_the_daily_count_uses_the_game_digits_when_they_loaded(self):
        self.use_numbers()
        self.h.dispatch('command', command='/ptrack theme classic 2', blocked=False)
        self.render()
        drop, images = self.big('163')
        self.assertEqual(images, [88, 88, 88])
        self.assertGreater(drop, 0)

    def test_the_count_falls_back_to_the_normal_font(self):
        self.h.dispatch('command', command='/ptrack theme classic 2', blocked=False)
        self.render()
        for text, numbers in (('163', False), ('1,234', True)):
            with self.subTest(text=text, numbers=numbers):
                if numbers:
                    self.use_numbers()
                    self.render()
                _, images = self.big(text)
                self.assertNotIn(88, images)

    def begun(self):
        self.h.lua.execute("begun = {}; local imgui = require('imgui'); "
                           "imgui.Begin = function(name) begun[#begun + 1] = name; return true end")
        self.render()
        return list(self.h.lua.globals().begun.values())

    def test_the_title_is_drawn_in_the_game_font_with_the_same_window_id(self):
        self.h.dispatch('command', command='/ptrack theme classic 2', blocked=False)
        self.assertIn('###phoenixtracker', self.begun())
        self.h.dispatch('command', command='/ptrack theme phoenix', blocked=False)
        self.assertIn('PhoenixTracker###phoenixtracker', self.begun())

    def test_table_headers_menus_and_sliders_use_the_game_font_under_classic(self):
        self.h.dispatch('command', command='/ptrack theme classic 2', blocked=False)
        self.render()
        self.h.lua.execute("""
            local imgui = require('imgui')
            local names = { [0] = 'Item', 'Qty' }
            imgui.TableGetColumnCount = function() return 2 end
            imgui.TableGetColumnName = function(i) return names[i] end
            imgui.TableSetColumnIndex = function() return true end
            imgui_calls = {}
            imgui.TableHeadersRow = function() imgui_calls[#imgui_calls + 1] = 'TableHeadersRow' end
            imgui.MenuItem = function() imgui_calls[#imgui_calls + 1] = 'MenuItem' end
            imgui.SliderFloat = function(_, _, _, _, format) imgui_calls[#imgui_calls + 1] = 'Slider ' .. format end
            drawn_images = {}
        """)
        self.ui.table_headers()
        self.ui.menu_item('Hide', None, 120)
        self.ui.slider('##s', self.h.lua.table(1.0), 0.5, 3.0, '%.2f', 0)
        calls = list(self.h.lua.globals().imgui_calls.values())
        self.assertNotIn('TableHeadersRow', calls)
        self.assertNotIn('MenuItem', calls)
        self.assertIn('Slider ', calls)                 # ImGui draws no value of its own
        self.assertGreater(self.images(), 0)

    def test_a_bad_font_choice_is_refused(self):
        self.h.dispatch('command', command='/ptrack font comic', blocked=False)
        self.assertTrue(self.h.settings.game_font)
        self.assertIn('Usage: /ptrack font <game | outline>', self.h.messages)


if __name__ == '__main__':
    unittest.main()
