#!/usr/bin/env python3
"""UPS Modbus -> Prometheus textfile exporter.

PowerWalker VFI 3000 ICT IoT (Phoenixtec OEM) at 192.168.8.224:502.
Samples input registers fast over a persistent Modbus TCP connection and writes
a node_exporter textfile once per WRITE window, exposing per-window MIN/MAX
voltage so a sub-second mains sag between Prometheus scrapes is still visible.

Register map reverse-engineered (no vendor doc); voltage/freq are x10. Voltage
line labels confirmed 2026-08-10 by cross-referencing the PDU's UPS-output
reading; load% (reg162) correlated to the PDU's measured load. Status/temp/
runtime registers are NOT confidently decoded -> exported raw (ups_status_register
/ ups_aux_register) so the data is captured for later empirical decoding rather
than mislabeled. Fails loud: ups_modbus_up 0 on read failure.
"""
import os
import socket
import struct
import sys
import tempfile
import time

HOST = os.environ.get("UPS_MODBUS_HOST", "192.168.8.224")
PORT = 502
UNIT = 1
BASE, COUNT = 100, 80
OUT = os.environ.get(
    "UPS_PROM_FILE",
    os.path.expanduser("~/.local/share/node_exporter/textfile/ups_modbus.prom"),
)
SAMPLE_HZ = float(os.environ.get("UPS_SAMPLE_HZ", "20"))
WRITE_SEC = float(os.environ.get("UPS_WRITE_SEC", "1"))

VOLT = {132: "input", 147: "output", 176: "bypass"}  # confirmed vs PDU output
FREQ = {144: "input", 173: "output"}
LOAD_PCT_REG = 162                     # correlated to PDU measured load %
STATUS_REGS = (112, 114, 116)          # bit-packed mode/flags (undecoded)
AUX_REGS = (128, 153, 156, 159, 165, 166)  # temp/current/runtime candidates

_sock = None


def _recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise IOError("connection closed")
        buf += chunk
    return buf


def read_input_registers(start, count):
    global _sock
    if _sock is None:
        _sock = socket.create_connection((HOST, PORT), timeout=6)
        _sock.settimeout(6)
    pdu = struct.pack(">BHH", 4, start, count)
    mbap = struct.pack(">HHHB", 1, 0, len(pdu) + 1, UNIT)
    try:
        _sock.sendall(mbap + pdu)
        head = _recv_exact(_sock, 6)
        length = struct.unpack(">H", head[4:6])[0]
        rest = _recv_exact(_sock, length)
    except OSError:
        try:
            _sock.close()
        finally:
            _sock = None
        raise
    if rest[1] & 0x80:
        raise IOError("modbus exception 0x%02x" % rest[2])
    nb = rest[2]
    return struct.unpack(">%dH" % (nb // 2), rest[3:3 + nb])


HEADER = [
    "# HELP ups_voltage_volts UPS line voltage by point (input/output/bypass).",
    "# TYPE ups_voltage_volts gauge",
    "# HELP ups_voltage_min_volts Lowest voltage in the last write window.",
    "# TYPE ups_voltage_min_volts gauge",
    "# HELP ups_voltage_max_volts Highest voltage in the last write window.",
    "# TYPE ups_voltage_max_volts gauge",
    "# HELP ups_frequency_hz UPS line frequency by point.",
    "# TYPE ups_frequency_hz gauge",
    "# HELP ups_load_percent UPS output load percent (reg162, PDU-correlated).",
    "# TYPE ups_load_percent gauge",
    "# HELP ups_battery_percent UPS battery capacity percent.",
    "# TYPE ups_battery_percent gauge",
    "# HELP ups_battery_voltage_volts UPS battery string voltage.",
    "# TYPE ups_battery_voltage_volts gauge",
    "# HELP ups_status_register Raw bit-packed UPS status/mode register (undecoded).",
    "# TYPE ups_status_register gauge",
    "# HELP ups_aux_register Raw UPS register, mapping unconfirmed.",
    "# TYPE ups_aux_register gauge",
    "# HELP ups_modbus_up 1 if the UPS Modbus read succeeded.",
    "# TYPE ups_modbus_up gauge",
]


def write_prom(lines):
    body = "\n".join(HEADER + lines) + "\n"
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(OUT))
    os.write(fd, body.encode())
    os.close(fd)
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)


def run_window():
    vmin, vmax, last, err = {}, {}, None, None
    deadline = time.monotonic() + WRITE_SEC
    period = 1.0 / SAMPLE_HZ
    while time.monotonic() < deadline:
        try:
            r = read_input_registers(BASE, COUNT)
        except (OSError, struct.error) as exc:
            err = exc
            time.sleep(0.2)
            continue
        last = r
        for a in VOLT:
            v = r[a - BASE] / 10.0
            vmin[a] = min(vmin.get(a, v), v)
            vmax[a] = max(vmax.get(a, v), v)
        time.sleep(period)
    lines = []
    if last is not None:
        for a, lab in VOLT.items():
            lines.append('ups_voltage_volts{line="%s"} %.1f' % (lab, last[a - BASE] / 10.0))
            lines.append('ups_voltage_min_volts{line="%s"} %.1f' % (lab, vmin[a]))
            lines.append('ups_voltage_max_volts{line="%s"} %.1f' % (lab, vmax[a]))
        for a, lab in FREQ.items():
            lines.append('ups_frequency_hz{line="%s"} %.1f' % (lab, last[a - BASE] / 10.0))
        lines.append("ups_load_percent %d" % last[LOAD_PCT_REG - BASE])
        lines.append("ups_battery_percent %d" % last[169 - BASE])
        lines.append("ups_battery_voltage_volts %.1f" % (last[170 - BASE] / 10.0))
        for a in STATUS_REGS:
            lines.append('ups_status_register{reg="%d"} %d' % (a, last[a - BASE]))
        for a in AUX_REGS:
            lines.append('ups_aux_register{reg="%d"} %d' % (a, last[a - BASE]))
        lines.append("ups_modbus_up 1")
    else:
        sys.stderr.write("ups-modbus-exporter: %s\n" % err)
        lines.append("ups_modbus_up 0")
    write_prom(lines)


if __name__ == "__main__":
    if os.environ.get("UPS_ONESHOT"):
        run_window()
    else:
        while True:
            run_window()
