"""Tests for scripts/agent-cost-report (run: python3 -m pytest tests/agent_cost_report_test.py)."""

import importlib.machinery
import importlib.util
import json
import re
import time
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "agent-cost-report"
# The script has no .py suffix, so importlib needs the loader named explicitly.
SPEC = importlib.util.spec_from_loader(
    "agent_cost_report", importlib.machinery.SourceFileLoader("agent_cost_report", str(SCRIPT))
)
acr = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(acr)

PRICES = json.loads((Path(__file__).resolve().parents[1] / "scripts" / "agent-cost-pricing.json").read_text())


def claude_line(msg_id, req_id, block, model="claude-opus-5", **usage):
    base = {"input_tokens": 0, "output_tokens": 0, "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0}
    base.update(usage)
    return json.dumps(
        {
            "type": "assistant",
            "timestamp": "2026-09-01T10:00:00.000Z",
            "requestId": req_id,
            "message": {"id": msg_id, "model": model, "content": [{"type": block}], "usage": base},
        }
    )


def test_content_blocks_of_one_message_are_counted_once(tmp_path):
    """Claude Code writes one line per content block, all repeating the same usage."""
    f = tmp_path / "s.jsonl"
    f.write_text(
        "\n".join(
            claude_line("msg1", "req1", b, output_tokens=100, input_tokens=10)
            for b in ("thinking", "text", "tool_use")
        )
    )
    rows = acr.parse_claude(f)["rows"]
    assert rows["2026-09-01|claude-opus-5"]["output"] == 100
    assert rows["2026-09-01|claude-opus-5"]["requests"] == 1


def test_skip_set_excludes_already_counted_records(tmp_path):
    f = tmp_path / "s.jsonl"
    f.write_text(claude_line("msg1", "req1", "text", output_tokens=100) + "\n" + claude_line("msg2", "req2", "text", output_tokens=7))
    rows = acr.parse_claude(f, skip={"msg1|req1"})["rows"]
    assert rows["2026-09-01|claude-opus-5"]["output"] == 7


def test_cache_split_falls_back_loudly(tmp_path):
    """No 5m/1h split -> counted as 5m AND flagged, never silently dropped."""
    f = tmp_path / "s.jsonl"
    f.write_text(claude_line("m", "r", "text", cache_creation_input_tokens=500))
    row = acr.parse_claude(f)["rows"]["2026-09-01|claude-opus-5"]
    assert row["cache_write_5m"] == 500 and row["no_cache_split"] == 500


def test_codex_input_excludes_cached_part(tmp_path):
    """OpenAI reports input_tokens as the total; only the uncached part is full price."""
    f = tmp_path / "r.jsonl"
    f.write_text(
        json.dumps({"type": "turn_context", "payload": {"turn_id": "t1", "model": "gpt-6-astra"}})
        + "\n"
        + json.dumps(
            {
                "type": "token_usage_record",
                "timestamp": "2026-09-01T10:00:00.000Z",
                "payload": {
                    "turn_id": "t1",
                    "response_id": "resp1",
                    "usage": {"input_tokens": 1000, "cached_input_tokens": 800, "output_tokens": 50},
                    "turn_token_usage": {"input_tokens": 999999},
                },
            }
        )
    )
    row = acr.parse_codex(f)["rows"]["2026-09-01|gpt-6-astra"]
    assert row["input"] == 200 and row["cache_read"] == 800 and row["output"] == 50


def test_pricing_matches_published_rates():
    row = acr.new_row()
    row.update({"input": 1_000_000, "output": 1_000_000, "cache_read": 1_000_000, "cache_write_1h": 1_000_000})
    cost, _ = acr.price_row(PRICES["claude"], "claude-opus-5", row, 0)
    assert cost == 5.0 + 25.0 + 0.5 + 10.0


def test_alias_and_unknown_model():
    row = acr.new_row()
    row["output"] = 1_000_000
    assert acr.price_row(PRICES["claude"], "claude-opus-5[1m]", row, 0)[0] == 25.0
    assert acr.price_row(PRICES["claude"], "claude-made-up", row, 0) is None


def test_web_search_billed_per_thousand():
    row = acr.new_row()
    row["web_search"] = 50
    assert acr.price_row(PRICES["claude"], "claude-opus-5", row, 10.0)[0] == 0.5


def _tc(ts, total):
    return json.dumps(
        {"type": "event_msg", "timestamp": ts, "payload": {"type": "token_count", "info": {"total_token_usage": total}}}
    )


def test_old_format_uses_cumulative_deltas_not_repeated_last(tmp_path):
    """token_count re-emits the same running total; differencing it must not double-count."""
    f = tmp_path / "old.jsonl"
    f.write_text(
        "\n".join(
            [
                json.dumps({"type": "turn_context", "payload": {"turn_id": "t1", "model": "gpt-5.5"}}),
                _tc("2026-05-01T10:00:00Z", {"input_tokens": 1000, "cached_input_tokens": 600, "output_tokens": 40}),
                _tc("2026-05-01T10:01:00Z", {"input_tokens": 1000, "cached_input_tokens": 600, "output_tokens": 40}),
                _tc("2026-05-01T10:02:00Z", {"input_tokens": 2500, "cached_input_tokens": 2000, "output_tokens": 90}),
            ]
        )
    )
    row = acr.parse_codex(f)["rows"]["2026-05-01|gpt-5.5"]
    assert row["cache_read"] == 2000 and row["input"] == 500 and row["output"] == 90
    assert row["requests"] == 2  # the repeated event contributes nothing


def test_new_format_wins_when_both_present(tmp_path):
    """Files with token_usage_record also carry token_count; only one may be counted."""
    f = tmp_path / "both.jsonl"
    f.write_text(
        "\n".join(
            [
                json.dumps({"type": "turn_context", "payload": {"turn_id": "t1", "model": "gpt-6-astra"}}),
                json.dumps(
                    {
                        "type": "token_usage_record",
                        "timestamp": "2026-09-01T10:00:00Z",
                        "payload": {
                            "turn_id": "t1",
                            "response_id": "r1",
                            "usage": {"input_tokens": 100, "cached_input_tokens": 0, "output_tokens": 10},
                        },
                    }
                ),
                _tc("2026-09-01T10:00:01Z", {"input_tokens": 100, "cached_input_tokens": 0, "output_tokens": 10}),
            ]
        )
    )
    rows = acr.parse_codex(f)["rows"]
    assert rows["2026-09-01|gpt-6-astra"]["output"] == 10 and len(rows) == 1


def test_group_of_splits_fable_from_the_rest():
    assert acr.group_of("codex", "gpt-6-astra") == "codex"
    assert acr.group_of("claude", "claude-opus-5") == "claude"
    assert acr.group_of("claude", "claude-fable-5-1") == "claude_fable"


def _row(**kw):
    r = acr.new_row()
    r.update(kw)
    return r


def test_windows_buckets_by_date_and_tracks_unpriced():
    totals = {
        "claude": {"rows": {
            "2026-09-20|claude-opus-5": _row(output=1_000_000, requests=1),     # today
            "2026-09-18|claude-fable-5": _row(output=1_000_000, requests=1),    # in 7d
            "2026-08-25|claude-opus-5": _row(output=1_000_000, requests=1),     # in 30d only
            "2026-01-01|claude-opus-5": _row(output=1_000_000, requests=1),     # all only
        }},
        "codex": {"rows": {"2026-09-20|codex-auto-review": _row(output=500, requests=3)}},
    }
    w = acr.windows(totals, PRICES, "2026-09-20")
    assert w["claude"]["today"]["usd"] == 25.0
    assert w["claude"]["d7"]["usd"] == 25.0        # the 09-18 row is fable, not claude
    assert w["claude"]["d30"]["usd"] == 50.0
    assert w["claude"]["all"]["usd"] == 75.0
    assert w["claude_fable"]["d7"]["usd"] == 50.0
    # An unpriced model contributes requests, never a guessed dollar figure.
    assert w["codex"]["today"] == {"usd": 0.0, "unpriced_requests": 3}


# --------------------------------------------------------------------- agent-usage

USAGE_SPEC = importlib.util.spec_from_loader(
    "agent_usage",
    importlib.machinery.SourceFileLoader(
        "agent_usage", str(Path(__file__).resolve().parents[1] / "scripts" / "agent-usage")
    ),
)
au = importlib.util.module_from_spec(USAGE_SPEC)
USAGE_SPEC.loader.exec_module(au)


def test_claude_entries_maps_the_three_usage_bars():
    payload = {"limits": [
        {"kind": "session", "percent": 3, "severity": "normal", "resets_at": "2026-09-21T00:10:00+00:00"},
        {"kind": "weekly_all", "percent": 42, "severity": "normal", "resets_at": "2026-09-25T03:00:00+00:00"},
        {"kind": "weekly_scoped", "percent": 63, "severity": "normal", "resets_at": "2026-09-25T03:00:00+00:00",
         "scope": {"model": {"display_name": "Fable"}}},
        {"kind": "something_new", "percent": 99, "severity": "critical"},
    ]}
    got = [(e["label"], e["percent"]) for e in au.claude_entries(payload)]
    assert got == [("CC 5h", 3), ("7d", 42), ("Fable", 63)]  # unknown kind skipped, not guessed


def test_nonzero_usage_always_lights_a_cell():
    assert au.filled_cells(0) == 0
    assert au.filled_cells(1) == 1   # would round to 0 -> indistinguishable from no data
    assert au.filled_cells(43) == 4
    assert au.filled_cells(100) == 10


def test_colour_only_warns_near_the_limit():
    assert au.colour({"percent": 63, "severity": "normal"}) is None
    assert au.colour({"percent": 75, "severity": "normal"}) == au.COL_WARN
    assert au.colour({"percent": 95, "severity": "normal"}) == au.COL_CRIT
    assert au.colour({"percent": 10, "severity": "warning"}) == au.COL_WARN


def test_codex_entry_reads_the_last_snapshot(tmp_path):
    f = tmp_path / "rollout.jsonl"
    def ev(ts, pct):
        return json.dumps({"type": "event_msg", "timestamp": ts, "payload": {
            "type": "token_count",
            "rate_limits": {"primary": {"used_percent": pct, "window_minutes": 10080, "resets_at": 1790441439}}}})
    f.write_text(ev("2026-09-20T10:00:00.000Z", 12.0) + "\n" + ev("2026-09-20T23:14:07.000Z", 19.4))
    e = au.codex_entry(f)
    assert e["percent"] == 19 and e["label"] == "CDX 7d" and e["stale_seconds"] > 0


def test_codex_entry_without_rate_limits_returns_none(tmp_path):
    f = tmp_path / "r.jsonl"
    f.write_text(json.dumps({"type": "event_msg", "payload": {"type": "token_count", "info": {}}}))
    assert au.codex_entry(f) is None


def _entry(percent, resets_in_seconds, window):
    return {"label": "7d", "percent": percent, "severity": "normal", "stale_seconds": 0,
            "window_seconds": window, "resets_at": time.time() + resets_in_seconds}


def test_elapsed_percent_from_reset_time_and_window():
    assert au.elapsed_percent(_entry(0, 3600, 7200)) == 50      # half the window left
    assert au.elapsed_percent(_entry(0, 7200, 7200)) == 0       # just reset
    assert au.elapsed_percent(_entry(0, 1, 7200)) == 100        # about to reset
    assert au.elapsed_percent({"window_seconds": None, "resets_at": None}) is None


def test_pace_colour_projects_to_end_of_window():
    on_track = _entry(40, 3600, 7200)      # 40% used, 50% elapsed -> projects 80%
    over = _entry(60, 3600, 7200)          # -> projects 120%
    way_over = _entry(90, 3600, 7200)      # -> projects 180%
    assert au.pace_colour(on_track, 50) == au.COL_OK
    assert au.pace_colour(over, 50) == au.COL_WARN
    assert au.pace_colour(way_over, 50) == au.COL_CRIT
    # Early in a window the ratio is noise: 3% used at 2% elapsed is not "150%".
    assert au.pace_colour(_entry(3, 7000, 7200), 2) is None


def test_the_two_rows_line_up_column_for_column():
    """The pair is only readable if both rows render identical visible widths."""
    e = _entry(47, 300000, 604800)
    plain = lambda s: re.sub(r"<[^>]*>", "", s)
    assert len(plain(au.segment(e))) == len(plain(au.time_segment(e)))
    # ... including when the window is unknown and the time row has nothing to draw
    unknown = {"label": "7d", "percent": 47, "severity": "normal", "stale_seconds": 0,
               "window_seconds": None, "resets_at": None}
    assert len(plain(au.segment(unknown))) == len(plain(au.time_segment(unknown)))
