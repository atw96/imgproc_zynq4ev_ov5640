#!/usr/bin/env python3
"""Bind UDP to Realtek IP 192.168.10.100 explicitly."""
import socket, time
BIND = "192.168.10.100"
PORT = 5002
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 8 * 1024 * 1024)
sock.settimeout(1.0)
sock.bind((BIND, PORT))
print(f"[RX] bind {BIND}:{PORT} 20s...")
t0 = time.time()
n = 0
while time.time() - t0 < 20:
    try:
        data, addr = sock.recvfrom(2048)
        n += 1
        if n <= 5:
            print(f"  pkt {n} from {addr[0]} len={len(data)}")
    except socket.timeout:
        pass
print(f"[RX] total: {n}")
