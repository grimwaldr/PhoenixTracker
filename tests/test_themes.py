"""Themes: picking one, what each fills ui.COLOR with, and Classic without the game's art."""

import unittest

from support import Harness


def hex_color(text):
    return [int(text[i:i + 2], 16) / 255 for i in (0, 2, 4)]


class ThemeTests(unittest.TestCase):
    def setUp(self):
        self.h = Harness()
        self.h.start_main()
        self.ui = self.h.load('ui')

    def command(self, text):
        return self.h.dispatch('command', command=text, blocked=False)

    def render(self):
        self.h.dispatch('d3d_present')

    def color(self, name):
        value = self.ui.COLOR[name]
        return [value[1], value[2], value[3]]

    def assertColor(self, name, expected):
        for got, want in zip(self.color(name), expected):
            self.assertAlmostEqual(got, want, places=4)

    def test_phoenix_is_the_starting_theme_with_the_original_palette(self):
        self.render()
        self.assertEqual(self.h.settings.theme, 'phoenix')
        self.assertColor('abyss', hex_color('180e0e'))
        self.assertColor('royal', hex_color('c55151'))
        self.assertColor('peach', hex_color('d2abab'))

    def test_a_theme_refills_the_same_colour_table_the_tabs_hold(self):
        held = self.ui.COLOR
        self.command('/ptrack theme neutral')
        self.render()
        self.assertTrue(self.h.lua.eval('rawequal')(self.ui.COLOR, held))
        self.assertColor('royal', hex_color('3f6fb8'))
        self.command('/ptrack theme phoenix')
        self.render()
        self.assertColor('royal', hex_color('c55151'))

    def test_neutral_and_classic_have_no_red_buttons_on_a_red_background(self):
        for command in ('/ptrack theme neutral', '/ptrack theme classic 1'):
            with self.subTest(command=command):
                self.command(command)
                self.render()
                for name in ('abyss', 'royal'):
                    r, g, b = self.color(name)
                    self.assertLessEqual(r, max(g, b) + 0.02, f'{name} is red in {command}')

    def test_classic_takes_its_colours_from_the_pinned_window_type(self):
        self.command('/ptrack theme classic 6')
        self.render()
        self.assertEqual(self.h.settings.theme, 'classic')
        self.assertEqual(self.h.settings.window_type, 5)
        self.assertColor('abyss', [c * 0.62 for c in hex_color('001948')])
        self.command('/ptrack theme classic 8')
        self.render()
        self.assertColor('abyss', [c * 0.62 for c in hex_color('1c353f')])

    def test_classic_game_follows_the_in_game_setting_again(self):
        self.command('/ptrack theme classic 3')
        self.command('/ptrack theme classic game')
        self.assertEqual(self.h.settings.window_type, -1)
        self.assertIn('Theme set to Classic, following your in-game Window Type.', self.h.messages)

    def test_bad_window_types_are_refused(self):
        for pick in ('0', '9', '2.5', 'nan', 'blue'):
            with self.subTest(pick=pick):
                self.command('/ptrack theme classic ' + pick)
                self.assertEqual(self.h.settings.theme, 'phoenix')
                self.assertEqual(self.h.settings.window_type, -1)
        self.assertIn('Usage: /ptrack theme classic <1-8 | game>', self.h.messages)

    def test_theme_names_match_by_label_and_ignore_case(self):
        self.command('/ptrack theme NEUTRAL')
        self.assertEqual(self.h.settings.theme, 'neutral')
        self.command('/pdig theme Classic')
        self.assertEqual(self.h.settings.theme, 'classic')

    def test_no_name_lists_the_themes_and_changes_nothing(self):
        self.command('/ptrack theme')
        self.command('/ptrack theme sparkly')
        self.assertEqual(self.h.settings.theme, 'phoenix')
        self.assertIn('Themes: Phoenix, Classic, Neutral. Current: Phoenix.', self.h.messages)

    def test_an_unknown_saved_theme_falls_back_to_phoenix(self):
        self.h.settings.theme = 'removed-theme'
        self.render()
        self.assertColor('royal', hex_color('c55151'))

    def test_every_tab_draws_under_every_theme(self):
        # The test client has no Direct3D, so Classic draws with its flat colours as it would
        # when the game's art can't be read.
        for theme in ('phoenix', 'classic', 'neutral'):
            for tab in ('fish', 'dig', 'harvest', 'log', 'mine', 'excavate'):
                with self.subTest(theme=theme, tab=tab):
                    self.h.settings.theme = theme
                    self.h.settings.tab = tab
                    self.render()


if __name__ == '__main__':
    unittest.main()
