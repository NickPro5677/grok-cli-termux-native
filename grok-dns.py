#!/data/data/com.termux/files/usr/bin/env python3
"""Patch grok's hardcoded DNS path, or ask one DNS server for a name.

Both paths are 16 bytes, so the swap does not change the file size:

    /etc/resolv.conf
    /sdcard/.grokdns

Usage:
    grok-dns.py <binary> <native|sdcard>
    grok-dns.py query <server> <hostname>

The shell scripts print the user-facing notes. This program stays quiet
when the file is already in the requested mode.
"""

import mmap
import os
import socket
import sys

NATIVE = b"/etc/resolv.conf"
SDCARD = b"/sdcard/.grokdns"


def build_query(host):
    """Build a DNS A query for host."""
    if not host or len(host) > 253:
        raise ValueError("bad hostname")
    header = b"\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00"
    qname = b""
    for label in host.split("."):
        if not label or len(label) > 63:
            raise ValueError("bad hostname")
        raw = label.encode("ascii")
        qname += bytes([len(raw)]) + raw
    qname += b"\x00"
    return header + qname + b"\x00\x01\x00\x01"


def dns_query(server, host, timeout=3):
    """Return True when server answers with at least one record."""
    message = build_query(host)
    family = socket.AF_INET6 if ":" in server else socket.AF_INET
    sock = socket.socket(family, socket.SOCK_DGRAM)
    try:
        sock.settimeout(timeout)
        sock.sendto(message, (server, 53))
        data, _addr = sock.recvfrom(2048)
    finally:
        sock.close()
    if len(data) < 12:
        return False
    rcode = data[3] & 0x0F
    ancount = int.from_bytes(data[6:8], "big")
    return rcode == 0 and ancount > 0


def cmd_query(server, host):
    try:
        found = dns_query(server, host)
    except (OSError, ValueError) as exc:
        sys.stderr.write(f"FAIL {exc}\n")
        return 1
    if found:
        sys.stdout.write("OK\n")
        return 0
    sys.stderr.write("FAIL no answer\n")
    return 1


def cmd_patch(path, mode):
    if mode not in ("native", "sdcard"):
        sys.stderr.write("Mode must be native or sdcard.\n")
        return 1
    target = NATIVE if mode == "native" else SDCARD
    other = SDCARD if mode == "native" else NATIVE
    if len(target) != 16 or len(other) != 16:
        sys.stderr.write("DNS paths must be 16 bytes.\n")
        return 1
    try:
        with open(path, "r+b") as handle:
            try:
                mapped = mmap.mmap(handle.fileno(), 0)
            except ValueError as exc:
                sys.stderr.write(f"Could not patch {path}: {exc}\n")
                return 1
            try:
                if mapped.find(other) == -1:
                    if mapped.find(target) == -1:
                        sys.stderr.write(
                            "This file does not contain the DNS path. "
                            "It is not a grok program this patch understands.\n"
                        )
                        return 1
                    return 0
                index = mapped.find(other)
                count = 0
                while index != -1:
                    mapped[index : index + 16] = target
                    count += 1
                    index = mapped.find(other, index + 16)
                mapped.flush()
                os.fsync(handle.fileno())
                if count < 1 or mapped.find(other) != -1 or mapped.find(target) == -1:
                    sys.stderr.write("Patch verification failed.\n")
                    return 1
            finally:
                mapped.close()
    except OSError as exc:
        sys.stderr.write(f"Could not patch {path}: {exc}\n")
        return 1
    return 0


def main(argv):
    if len(NATIVE) != 16 or len(SDCARD) != 16:
        sys.stderr.write("DNS paths must be 16 bytes.\n")
        return 1
    if len(argv) >= 2 and argv[1] == "query":
        if len(argv) != 4:
            sys.stderr.write("Usage: grok-dns.py query <server> <hostname>\n")
            return 1
        return cmd_query(argv[2], argv[3])
    if len(argv) != 3:
        sys.stderr.write("Usage: grok-dns.py <binary> <native|sdcard>\n")
        return 1
    return cmd_patch(argv[1], argv[2])


if __name__ == "__main__":
    sys.exit(main(sys.argv))
