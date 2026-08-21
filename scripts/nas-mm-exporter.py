#!/usr/bin/env python3
"""nas-mm-exporter: pageblock migratetype state + extfrag driver counters.

Fragmentation science (Aug 2026 bcachefs/mm pathology): buddyinfo (already
exported) is the SYMPTOM. This exports the STATE - pageblock ownership from
/proc/pagetypeinfo (root-only) - and the DRIVER - kmem:mm_page_alloc_extfrag
events counted stacks-free in a DEDICATED tracing instance, so manual trace
sessions on the main instance are unaffected. Counters are monotonic;
rate() in PromQL gives events/s. fragmenting=1 = sub-pageblock fallback
(real fragmentation); change_ownership=1 = pageblock retag.
"""
import os, re, threading, time, sys

OUT = "/var/lib/prometheus/node-exporter/nas_mm.prom"
INST = "/sys/kernel/tracing/instances/extfrag-exporter"
EVDIR = INST + "/events/kmem/mm_page_alloc_extfrag"
P = "nas_mm"

LINE = re.compile(rb"alloc_order=(\d+) fallback_order=\d+ pageblock_order=\d+ "
                  rb"alloc_migratetype=\d+ fallback_migratetype=\d+ "
                  rb"fragmenting=(\d) change_ownership=(\d)")

lock = threading.Lock()
flags = {(f, o): 0 for f in "01" for o in "01"}   # pre-seeded so rate() works from t0
orders = {}   # alloc_order -> count

def reader():
    with open(INST + "/trace_pipe", "rb") as f:
        for line in f:
            m = LINE.search(line)
            if not m:
                continue
            o, fr, ow = int(m.group(1)), m.group(2).decode(), m.group(3).decode()
            with lock:
                flags[(fr, ow)] = flags.get((fr, ow), 0) + 1
                orders[o] = orders.get(o, 0) + 1

def parse_pagetypeinfo():
    """-> (pageblocks{(zone,type)}, free_pages{(zone,type)}, free_ge6{(zone,type)})"""
    blocks, freep, ge6 = {}, {}, {}
    section = None
    for raw in open("/proc/pagetypeinfo"):
        if raw.startswith("Free pages count per migrate type"):
            section = "free"; continue
        if raw.startswith("Number of blocks type"):
            section = "blocks"; continue
        f = raw.split()
        if section == "free" and len(f) >= 17 and f[0] == "Node":
            zone, mtype = f[3].rstrip(","), f[5]
            counts = [int(x) for x in f[6:17]]
            freep[(zone, mtype)] = sum(c * (1 << o) for o, c in enumerate(counts))
            ge6[(zone, mtype)] = sum(counts[6:])
        elif section == "blocks" and len(f) >= 9 and f[0] == "Node":
            zone = f[3]
            for i, t in enumerate(("Unmovable", "Movable", "Reclaimable",
                                   "HighAtomic", "Isolate")):
                blocks[(zone, t)] = int(f[4 + i])
    return blocks, freep, ge6

def write_prom():
    lines = [
        "# HELP %s_pageblocks 2MiB pageblocks by migratetype (the ratchet state)." % P,
        "# TYPE %s_pageblocks gauge" % P,
        "# HELP %s_free_pages Free 4K pages sitting inside blocks of each migratetype." % P,
        "# TYPE %s_free_pages gauge" % P,
        "# HELP %s_free_blocks_order6plus Free order>=6 blocks by migratetype." % P,
        "# TYPE %s_free_blocks_order6plus gauge" % P,
        "# HELP %s_extfrag_events_total Cross-migratetype fallback events (driver)." % P,
        "# TYPE %s_extfrag_events_total counter" % P,
        "# HELP %s_extfrag_order_events_total Fallback events by requested order." % P,
        "# TYPE %s_extfrag_order_events_total counter" % P,
        "# HELP %s_up 1 if the probe succeeded this cycle." % P,
        "# TYPE %s_up gauge" % P,
    ]
    blocks, freep, ge6 = parse_pagetypeinfo()
    for (z, t), v in sorted(blocks.items()):
        lines.append('%s_pageblocks{zone="%s",type="%s"} %d' % (P, z, t, v))
    for (z, t), v in sorted(freep.items()):
        lines.append('%s_free_pages{zone="%s",type="%s"} %d' % (P, z, t, v))
    for (z, t), v in sorted(ge6.items()):
        lines.append('%s_free_blocks_order6plus{zone="%s",type="%s"} %d' % (P, z, t, v))
    with lock:
        for (fr, ow), v in sorted(flags.items()):
            lines.append('%s_extfrag_events_total{fragmenting="%s",change_ownership="%s"} %d'
                         % (P, fr, ow, v))
        for o, v in sorted(orders.items()):
            lines.append('%s_extfrag_order_events_total{order="%d"} %d' % (P, o, v))
    lines.append("%s_up 1" % P)
    tmp = OUT + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)

def setup_instance():
    os.makedirs(INST, exist_ok=True)
    with open(EVDIR + "/enable", "w") as f:
        f.write("1")
    with open(INST + "/tracing_on", "w") as f:
        f.write("1")
    # modest buffer: events are ~200B, worst observed burst ~750/s
    with open(INST + "/buffer_size_kb", "w") as f:
        f.write("1024")

def main():
    setup_instance()
    t = threading.Thread(target=reader, daemon=True)
    t.start()
    while True:
        try:
            write_prom()
        except OSError as exc:
            sys.stderr.write("nas-mm-exporter: %s\n" % exc)
            try:
                with open(OUT, "w") as f:
                    f.write("%s_up 0\n" % P)
                os.chmod(OUT, 0o644)
            except OSError:
                pass
        if not t.is_alive():
            sys.stderr.write("nas-mm-exporter: reader thread died, exiting\n")
            sys.exit(1)
        time.sleep(30)

if __name__ == "__main__":
    main()
