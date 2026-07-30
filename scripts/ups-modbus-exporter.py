#!/usr/bin/env python3
"""UPS Modbus -> Prometheus textfile exporter.

PowerWalker VFI 3000 ICT IoT (Phoenixtec OEM) at 192.168.8.224:502.
Reads input registers over Modbus TCP, writes a node_exporter textfile.

Register map reverse-engineered 2026-07-30 (no vendor doc); voltage/freq are x10.
Fails loudly: on Modbus error it emits `ups_modbus_up 0` and logs to stderr, so a
dead UPS shows as a clear 0 rather than a stale/faked reading.
"""
import os
import socket
import struct
import sys
import tempfile

HOST = os.environ.get("UPS_MODBUS_HOST", "192.168.8.224")
PORT = 502
UNIT = 1
OUT = os.environ.get(
    "UPS_PROM_FILE",
    os.path.expanduser("~/.local/share/node_exporter/textfile/ups_modbus.prom"),
)

# addr -> label. Reverse-engineered; input/bypass ~= grid, output = regulated 230V.
VOLT = {132: "input", 147: "output", 176: "bypass"}
FREQ = {144: "input", 173: "output"}


def read_input_registers(start, count):
    pdu = struct.pack(">BHH", 4, start, count)
    mbap = struct.pack(">HHHB", 1, 0, len(pdu) + 1, UNIT)
    with socket.create_connection((HOST, PORT), timeout=6) as s:
        s.settimeout(6)
        s.sendall(mbap + pdu)
        data = s.recv(2048)
    if len(data) < 9 or (data[7] & 0x80):
        raise IOError("modbus exception or short response")
    nb = data[8]
    return struct.unpack(">%dH" % (nb // 2), data[9:9 + nb])


def main():
    out = [
        "# HELP ups_voltage_volts UPS line voltage by point (input/output/bypass).",
        "# TYPE ups_voltage_volts gauge",
        "# HELP ups_frequency_hz UPS line frequency by point.",
        "# TYPE ups_frequency_hz gauge",
        "# HELP ups_battery_percent UPS battery capacity percent.",
        "# TYPE ups_battery_percent gauge",
        "# HELP ups_battery_voltage_volts UPS battery string voltage.",
        "# TYPE ups_battery_voltage_volts gauge",
        "# HELP ups_aux_register Raw Modbus register, mapping unconfirmed.",
        "# TYPE ups_aux_register gauge",
        "# HELP ups_modbus_up 1 if the UPS Modbus read succeeded.",
        "# TYPE ups_modbus_up gauge",
    ]
    try:
        r = read_input_registers(120, 60)
        for a, lab in VOLT.items():
            out.append('ups_voltage_volts{line="%s"} %.1f' % (lab, r[a - 120] / 10.0))
        for a, lab in FREQ.items():
            out.append('ups_frequency_hz{line="%s"} %.1f' % (lab, r[a - 120] / 10.0))
        out.append("ups_battery_percent %d" % r[169 - 120])
        out.append("ups_battery_voltage_volts %.1f" % (r[170 - 120] / 10.0))
        for a in (153, 162, 165, 166):
            out.append('ups_aux_register{reg="%d"} %d' % (a, r[a - 120]))
        out.append("ups_modbus_up 1")
    except (OSError, struct.error) as exc:
        sys.stderr.write("ups-modbus-exporter: %s\n" % exc)
        out.append("ups_modbus_up 0")
    body = "\n".join(out) + "\n"
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(OUT))
    os.write(fd, body.encode())
    os.close(fd)
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    interval = float(os.environ.get("UPS_INTERVAL", "0"))
    if interval > 0:
        import time
        while True:
            main()
            time.sleep(interval)
    else:
        main()
