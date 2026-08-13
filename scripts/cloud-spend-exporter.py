#!/usr/bin/env python3
"""OpenRouter + Vast.ai spend -> Prometheus textfile exporter.

Why bother when the waybar already shows these: the bar is instantaneous, and
money questions are almost always about trends -- what did the agent runs cost
this week, did that experiment double the burn, how long until the balance is
gone. Prometheus also gives rolling windows for free that neither API offers:

    increase(openrouter_usage_total_usd[24h])   # true rolling 24h spend
    predict_linear(vast_credit_usd[6h], 3600*8) # credit 8h from now

openrouter_usage_total_usd and vast_credit_usd are cumulative/monotonic-ish, so
they are declared counters where that holds and gauges where it does not.

Fails loud per provider: openrouter_up / vast_up go 0 and that provider's series
are omitted, so one dead API never fakes the other's numbers.
"""
import json
import os
import sys
import tempfile
import time
import urllib.request

OR_KEY_FILE = os.path.expanduser("~/.config/openrouter/key")
VAST_KEY_FILE = os.path.expanduser("~/.config/vastai/vast_api_key")
OUT = os.environ.get(
    "CLOUD_SPEND_PROM_FILE",
    os.path.expanduser("~/.local/share/node_exporter/textfile/cloud_spend.prom"),
)
INTERVAL = float(os.environ.get("CLOUD_SPEND_INTERVAL", "60"))
TIMEOUT = float(os.environ.get("CLOUD_SPEND_TIMEOUT", "15"))


def read_key(env, path):
    key = os.environ.get(env)
    if key:
        return key.strip()
    with open(path) as fh:
        return fh.read().strip()


def get(url, headers=None):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def openrouter():
    key = read_key("OPENROUTER_API_KEY", OR_KEY_FILE)
    hdr = {"Authorization": "Bearer " + key}
    credits = get("https://openrouter.ai/api/v1/credits", hdr)["data"]
    k = get("https://openrouter.ai/api/v1/key", hdr)["data"]
    total_credits = float(credits["total_credits"])
    total_usage = float(credits["total_usage"])
    out = [
        "openrouter_credits_total_usd %.6f" % total_credits,
        "openrouter_usage_total_usd %.6f" % total_usage,
        "openrouter_balance_usd %.6f" % (total_credits - total_usage),
        "openrouter_key_usage_total_usd %.6f" % float(k["usage"]),
        "openrouter_key_byok_usage_total_usd %.6f" % float(k["byok_usage"]),
    ]
    # UTC-calendar windows, NOT rolling - they reset at UTC midnight. Kept because
    # they are what the provider bills against; use increase() for real windows.
    for period, label in (("daily", "day"), ("weekly", "week"), ("monthly", "month")):
        out.append('openrouter_usage_period_usd{period="%s"} %.6f'
                   % (label, float(k["usage_" + period])))
        out.append('openrouter_byok_usage_period_usd{period="%s"} %.6f'
                   % (label, float(k["byok_usage_" + period])))
    limit = k.get("limit")
    if limit is not None:
        out.append("openrouter_key_limit_usd %.6f" % float(limit))
    return out


def vast():
    key = read_key("VAST_API_KEY", VAST_KEY_FILE)
    base = "https://console.vast.ai/api/v0/"
    credit = float(get(base + "users/current/?api_key=" + key)["credit"])
    insts = get(base + "instances/?api_key=" + key).get("instances", [])
    running = [i for i in insts if i.get("actual_status") == "running"]
    burn = sum(float(i.get("dph_total") or 0) for i in running)
    out = [
        "vast_credit_usd %.6f" % credit,
        "vast_burn_usd_per_hour %.6f" % burn,
        "vast_instances_running %d" % len(running),
        "vast_instances_total %d" % len(insts),
    ]
    # Runway is the number that actually matters: Vast destroys instances at $0.
    if burn > 0:
        out.append("vast_runway_hours %.4f" % (credit / burn))
    for i in running:
        lbl = 'id="%s",gpu="%s",num_gpus="%d"' % (
            i.get("id"), (i.get("gpu_name") or "unknown").replace(" ", ""),
            int(i.get("num_gpus") or 1))
        out.append("vast_instance_dph_usd{%s} %.6f" % (lbl, float(i.get("dph_total") or 0)))
        for key_, metric, scale in (("gpu_util", "gpu_util_percent", 1),
                                    ("vmem_usage", "vram_used_bytes", 1 << 30),
                                    ("gpu_ram", "vram_total_bytes", 1 << 20)):
            val = i.get(key_)
            if val is not None:
                out.append("vast_instance_%s{%s} %.4f" % (metric, lbl, float(val) * scale))
    return out


TYPES = [
    ("openrouter_usage_total_usd", "counter", "Lifetime OpenRouter credit spend."),
    ("openrouter_key_usage_total_usd", "counter", "Lifetime spend on this key."),
    ("openrouter_key_byok_usage_total_usd", "counter", "Lifetime BYOK spend (no credits)."),
    ("openrouter_credits_total_usd", "gauge", "Lifetime credits purchased."),
    ("openrouter_balance_usd", "gauge", "Credits purchased minus credits spent."),
    ("openrouter_usage_period_usd", "gauge", "Spend in the current UTC day/week/month."),
    ("openrouter_byok_usage_period_usd", "gauge", "BYOK spend in the current UTC period."),
    ("vast_credit_usd", "gauge", "Vast.ai account credit."),
    ("vast_burn_usd_per_hour", "gauge", "Sum of dph_total over running instances."),
    ("vast_runway_hours", "gauge", "Credit divided by burn; instances die at zero."),
    ("vast_instances_running", "gauge", "Instances in actual_status=running."),
    ("vast_instance_dph_usd", "gauge", "Per-instance dollars per hour."),
]


def build():
    lines = []
    for name, type_, help_ in TYPES:
        lines.append("# HELP %s %s" % (name, help_))
        lines.append("# TYPE %s %s" % (name, type_))
    for name, fn in (("openrouter", openrouter), ("vast", vast)):
        lines.append("# TYPE %s_up gauge" % name)
        try:
            lines.extend(fn())
            lines.append("%s_up 1" % name)
        except (OSError, ValueError, KeyError, TypeError) as exc:
            sys.stderr.write("cloud-spend-exporter: %s: %s\n" % (name, exc))
            lines.append("%s_up 0" % name)
    return "\n".join(lines) + "\n"


def write():
    body = build()
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(OUT))
    os.write(fd, body.encode())
    os.close(fd)
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    if os.environ.get("CLOUD_SPEND_ONESHOT"):
        sys.stdout.write(build())
    else:
        while True:
            write()
            time.sleep(INTERVAL)
