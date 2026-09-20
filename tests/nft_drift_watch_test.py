"""nft-drift-watch: does it see the rogue rule, and can it tell 'not watching' from 'not drifted'?"""
import importlib.util
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_loader("nft_drift_watch", loader=None)
watch = importlib.util.module_from_spec(spec)
with open(os.path.join(HERE, "..", "scripts", "nft-drift-watch")) as source:
    code = compile(source.read(), "nft-drift-watch", "exec")
exec(code, watch.__dict__)  # noqa: S102 — load a script without .py suffix

# The REAL live listing from spark-1 on Sep 20 2026, handle 19 and all.
LIVE = """table inet tailscale_only { # handle 3
\tset lan_peers { # handle 2
\t\ttype ipv4_addr
\t\tflags interval
\t\telements = { 192.168.102.0/24 }
\t}
\tset blocked_tcp { # handle 9
\t\ttype ipv4_addr . inet_service
\t\tsize 8192
\t\tflags dynamic,timeout
\t\ttimeout 7d
\t}
\tchain input { # handle 1
\t\ttype filter hook input priority -100; policy accept;
\t\tiifname "enP7s7" accept # handle 19
\t\tct state established,related accept # handle 4
\t\tiifname "lo" accept # handle 5
\t\tiifname "tailscale0" accept # handle 6
\t\tiifname "enP7s7" ip saddr @lan_peers accept # handle 16
\t\tct state new iifname != "lo" iifname != "tailscale0" counter packets 2838236 bytes 637226233 drop # handle 18
\t}
}
"""

# What the file says - same policy, different formatting, NO handle-19 rule, and a set whose
# elements the file lists differently (they legitimately drift and must be ignored).
CONFIG = """#!/usr/sbin/nft -f
# [tom 2026-08-26] enforcement
destroy table inet tailscale_only
table inet tailscale_only {
    set lan_peers {
        type ipv4_addr; flags interval;
        elements = { 192.168.102.0/24 }
    }
    set blocked_tcp { type ipv4_addr . inet_service; size 8192; flags dynamic,timeout; timeout 7d; }
    chain input {
        type filter hook input priority -100;
        policy accept;
        ct state established,related accept   # [tom 2026-08-11] never sever a live connection
        iifname "lo" accept
        iifname "tailscale0" accept
        iifname "enP7s7" ip saddr @lan_peers accept
        ct state new iifname != "lo" iifname != "tailscale0" counter drop
    }
}
"""


class Parsing(unittest.TestCase):
    def test_handles_and_counters_are_not_policy(self):
        self.assertEqual(watch.normalise('  iifname "enP7s7" accept # handle 19  '), 'iifname "enP7s7" accept')
        self.assertEqual(watch.normalise('ct state new counter packets 2838236 bytes 637226233 drop # handle 18'),
                         'ct state new counter drop')

    def test_the_rogue_rule_is_the_only_difference(self):
        """The whole reason this exists: handle 19 is live and NOT in the file, nothing else differs."""
        extra, missing = watch.compare(watch.rules_of(LIVE), watch.rules_of(CONFIG))
        self.assertEqual(extra, [('input', 'iifname "enP7s7" accept')])
        self.assertEqual(missing, [], 'formatting differences must not read as missing rules')

    def test_set_contents_are_ignored_because_they_legitimately_differ(self):
        rules = watch.rules_of(LIVE)
        self.assertFalse(any('elements' in rule or 'timeout' in rule for _, rule in rules))

    def test_a_ruleset_that_matches_the_file_is_in_sync(self):
        clean = LIVE.replace('\t\tiifname "enP7s7" accept # handle 19\n', '')
        self.assertEqual(watch.compare(watch.rules_of(clean), watch.rules_of(CONFIG)), ([], []))

    def test_a_flushed_chain_shows_as_missing_rules(self):
        """The other failure mode - the table lost its rules - must be visible too, not just extras."""
        flushed = 'table inet tailscale_only {\n\tchain input {\n\t\ttype filter hook input priority -100; policy accept;\n\t}\n}\n'
        extra, missing = watch.compare(watch.rules_of(flushed), watch.rules_of(CONFIG))
        self.assertEqual(extra, [])
        self.assertEqual(len(missing), 5)

    def test_other_tables_in_the_file_are_not_compared(self):
        other = CONFIG + '\ntable inet something_else {\n    chain input {\n        drop\n    }\n}\n'
        self.assertEqual(watch.rules_of(other), watch.rules_of(CONFIG))


class Metrics(unittest.TestCase):
    def test_in_sync_and_the_timestamp_are_written_even_when_nothing_is_wrong(self):
        """★ The user's requirement: a gap must mean 'not watching', never 'nothing to report'."""
        text = watch.render(True, [], [], now=1700000000)
        self.assertIn('nft_drift_in_sync 1\n', text)
        self.assertIn('nft_drift_extra_rules 0\n', text)
        self.assertIn('nft_drift_last_check_timestamp_seconds 1700000000\n', text)
        self.assertIn('nft_drift_up 1\n', text)

    def test_a_read_failure_is_published_as_down_not_as_in_sync(self):
        text = watch.render(False, [], [], now=1, error='sudo: a password is required')
        self.assertIn('nft_drift_up 0\n', text)
        self.assertIn('nft_drift_in_sync 0\n', text)

    def test_drift_counts_are_published(self):
        text = watch.render(False, [('input', 'x')], [('input', 'y'), ('input', 'z')], now=1)
        self.assertIn('nft_drift_extra_rules 1\n', text)
        self.assertIn('nft_drift_missing_rules 2\n', text)


class Loop(unittest.TestCase):
    def run_cycles(self, results, heartbeat_every=3):
        published, snapshots, logged = [], [], []
        outcomes = iter(results)
        clock = [1000.]

        def checker():
            r = next(outcomes)
            return r
        def sleep(_):
            clock[0] += 60
        original = watch.log
        watch.log = logged.append
        try:
            watch.loop(interval=60, once=False, heartbeat_every=heartbeat_every, checker=checker,
                       publisher=published.append, snapshotter=lambda e, m, t, now: (snapshots.append(now) or '/evidence'),
                       sleep=sleep, now=lambda: clock[0])
        except StopIteration:
            pass
        finally:
            watch.log = original
        return published, snapshots, logged

    def test_every_cycle_publishes_even_while_nothing_changes(self):
        published, _, _ = self.run_cycles([(True, [], [], 'x', None)]*5)
        self.assertEqual(len(published), 5)
        self.assertTrue(all('nft_drift_in_sync 1' in p for p in published))

    def test_logs_on_change_and_on_heartbeat_not_every_minute(self):
        results = [(True, [], [], 'x', None)]*7
        _, _, logged = self.run_cycles(results, heartbeat_every=3)
        self.assertEqual(sum('in sync' in line for line in logged), 3, 'cycles 0, 3 and 6')

    def test_evidence_is_captured_on_the_transition_into_drift_not_every_minute(self):
        drift = (False, [('input', 'iifname "enP7s7" accept')], [], 'x', None)
        results = [(True, [], [], 'x', None)]*2 + [drift]*4
        published, snapshots, logged = self.run_cycles(results, heartbeat_every=100)
        self.assertEqual(len(snapshots), 1, 'one snapshot for the transition; the first has the suspects')
        self.assertTrue(any('DRIFT: 1 extra' in line for line in logged))
        self.assertTrue(any('extra   [input] iifname "enP7s7" accept' in line for line in logged))
        self.assertIn('nft_drift_in_sync 0', published[-1])

    def test_a_read_failure_publishes_down_and_says_so(self):
        _, snapshots, logged = self.run_cycles([(False, [], [], '', 'sudo: a password is required')])
        self.assertEqual(snapshots, [], 'a read failure is not drift; do not fabricate a suspect list')
        self.assertTrue(any('CANNOT READ RULESET' in line for line in logged))


class Evidence(unittest.TestCase):
    def test_snapshot_records_unreadable_sections_instead_of_leaving_them_empty(self):
        def run(argv, **_):
            raise FileNotFoundError(argv[0])
        with tempfile.TemporaryDirectory() as directory:
            path = watch.snapshot([('input', 'x')], [], 'live text', directory=directory, now=1700000000, run=run)
            body = open(path).read()
        self.assertIn('=== EXTRA', body)
        self.assertIn('input: x', body)
        self.assertIn('live text', body)
        self.assertGreaterEqual(body.count('unreadable:'), 4, 'every failed section says so explicitly')


if __name__ == '__main__':
    unittest.main()


class RealConfigConstructs(unittest.TestCase):
    """Pinned against the actual /etc/nftables.conf text that first broke the parser (Sep 20 2026)."""

    FILE_RULE = ('    ct state new meta nfproto ipv4 meta l4proto tcp \\\n'
                 '        iifname != "lo" iifname != "tailscale0" \\\n'
                 '        update @blocked_tcp { ip saddr . tcp dport } \\\n'
                 '        limit rate 10/minute log prefix "nft-drop-tcp: "   # [tom 2026-08-26] log\n')
    LIVE_RULE = ('\t\tct state new iifname != "lo" iifname != "tailscale0" update @blocked_tcp '
                 '{ ip saddr . tcp dport } limit rate 10/minute burst 5 packets log prefix "nft-drop-tcp: " # handle 17\n')

    def wrap(self, rule):
        return 'table inet tailscale_only {\n\tchain input {\n' + rule + '\t}\n}\n'

    def test_backslash_continuations_fold_into_one_rule(self):
        self.assertEqual(len(watch.joined_lines(self.FILE_RULE)), 1)
        self.assertEqual(len(watch.rules_of(self.wrap(self.FILE_RULE))), 1)

    def test_the_kernels_reserialisation_of_the_same_rule_compares_equal(self):
        """`burst 5 packets` printed, `meta nfproto/l4proto` dropped - same policy, must be in sync."""
        self.assertEqual(watch.compare(watch.rules_of(self.wrap(self.LIVE_RULE)),
                                       watch.rules_of(self.wrap(self.FILE_RULE))), ([], []))

    def test_a_quoted_hash_is_not_a_comment(self):
        self.assertEqual(watch.strip_comment('log prefix "a#b" # real comment'), 'log prefix "a#b" ')
