"""Tests for scripts/agent-cost-report (run: python3 -m pytest tests/agent_cost_report_test.py)."""

import importlib.machinery
import importlib.util
import json
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
