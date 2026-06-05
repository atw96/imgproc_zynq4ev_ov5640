#!/usr/bin/env python3
"""Listen probe (5003) and stream (5002) for 25s."""
import socket, time

def listen(port, label, sec=25):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("192.168.10.100", port))
    s.settimeout(0.5)
    print(f"[{label}] bind 192.168.10.100:{port} ...")
    t0 = time.time()
    n = 0
    while time.time() - t0 < sec:
        try:
            d, a = s.recvfrom(512)
            n += 1
            if n <= 5:
                print(f"  {label} pkt{n} from {a[0]}:{a[1]} len={len(d)} data={d[:24]!r}")
        except socket.timeout:
            pass
    print(f"[{label}] total {n}")
    s.close()
    return n

listen(5003, "PROBE", 20)
listen(5002, "STREAM", 20)
