"""Active time: the session clock only runs while you're doing the activity."""

import unittest

from support import Harness, packet


class ClockTests(unittest.TestCase):
    def setUp(self):
        self.ui = Harness().load('ui')
        self.clock = self.ui.new_clock()

    def seconds(self, now):
        return tuple(self.ui.clock_seconds(self.clock, now))

    def test_a_cast_runs_the_clock_until_thirty_seconds_after_it_ends(self):
        self.ui.clock_start(self.clock, 1000)
        self.assertEqual(self.seconds(1040), (40, False))   # still on the line
        self.ui.clock_finish(self.clock, 1050)
        self.assertEqual(self.seconds(1070), (70, False))   # in the 30 second grace
        self.assertEqual(self.seconds(1080), (80, True))    # paused
        self.assertEqual(self.seconds(2000), (80, True))    # time away doesn't count

    def test_casting_again_within_the_grace_keeps_it_running(self):
        self.ui.clock_start(self.clock, 1000)
        self.ui.clock_finish(self.clock, 1050)
        self.ui.clock_start(self.clock, 1075)
        self.assertEqual(self.seconds(1100), (100, False))

    def test_coming_back_starts_a_new_stretch_without_the_gap(self):
        self.ui.clock_start(self.clock, 1000)
        self.ui.clock_finish(self.clock, 1050)               # counts to 1080
        self.ui.clock_start(self.clock, 1500)
        self.ui.clock_finish(self.clock, 1520)
        self.assertEqual(self.seconds(1550), (80 + 50, True))

    def test_instant_actions_count_their_grace(self):
        for at in (1000, 1015, 1030):                          # a dig every 15 seconds
            self.ui.clock_start(self.clock, at)
            self.ui.clock_finish(self.clock, at)
        self.assertEqual(self.seconds(1060), (60, True))

    def test_an_action_that_never_ends_stops_counting(self):
        self.ui.clock_start(self.clock, 1000)
        self.assertEqual(self.seconds(5000), (self.ui.ACTIVE_LONGEST, True))

    def test_an_unused_clock_shows_nothing(self):
        self.assertEqual(self.seconds(1000), (0, True))
        label, value, _ = self.ui.active_cell(self.clock)
        self.assertEqual((label, value), ('Active', '-'))


class FishingActiveTimeTests(unittest.TestCase):
    def setUp(self):
        self.h = Harness('fishing')
        self.ui = self.h.load('ui')
        self.pf = self.h.get_upvalue('pf')

    def animation(self, status):
        self.h.state.status = status
        self.h.packet(0x037, packet(64, u32={0x24: self.h.state.player_id}, u8={0x30: status}))

    def cast(self, seconds):
        self.animation(56)
        self.h.advance(seconds)
        self.animation(0)

    def test_casts_run_the_clock_and_time_away_pauses_it(self):
        self.cast(40)
        self.h.advance(10)
        self.cast(40)                     # 40 + 10 + 40 seconds, all active
        self.h.advance(600)               # ten minutes away
        label, value, color = self.ui.active_cell(self.pf.session.clock)
        self.assertEqual((label, value), ('Paused', '2m 00s'))   # plus the 30 second grace
        self.assertIsNotNone(color)

        self.cast(20)
        label, value, _ = self.ui.active_cell(self.pf.session.clock)
        self.assertEqual((label, value), ('Active', '2m 20s'))

    def times(self):
        session = self.pf.session
        _, active, _ = self.ui.active_cell(session.clock)
        return active, self.ui.duration(self.ui.session_total(session))

    def test_both_clocks_stop_at_the_daily_limit_and_run_again_after_the_reset(self):
        self.h.present()
        self.cast(40)
        self.h.command('set', ['200'])
        self.h.advance(1)
        self.h.present()                  # the limit is seen on the next tick
        held = self.times()
        self.h.advance(1800)
        self.cast(30)                     # casting on past the limit counts for nothing
        self.h.advance(600)
        self.h.present()
        self.assertEqual(self.times(), held)
        self.assertEqual(self.ui.active_cell(self.pf.session.clock)[0], 'Active')

        self.h.advance(1, day='2026-10-09')
        self.h.present()                  # JST midnight: a fresh day
        self.cast(20)
        self.assertEqual(held, ('0m 41s', '0m 41s'))          # the cast and a second after it
        self.assertEqual(self.times(), ('1m 01s', '1m 01s'))  # plus the 20 second cast after the reset


if __name__ == '__main__':
    unittest.main()
