#!/usr/bin/env python3
import socket, struct, time
PORT = 5002
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 8 * 1024 * 1024)
sock.settimeout(1.0)
sock.bind(("", PORT))
print(f"[probe] UDP :{PORT} 12s...")
t0 = time.time()
n = 0
while time.time() - t0 < 12:
    try:
        data, addr = sock.recvfrom(2048)
        n += 1
        if n <= 3:
            print(f"  pkt {n} from {addr[0]} len={len(data)}")
    except socket.timeout:
        pass
print(f"[probe] total packets: {n}")
