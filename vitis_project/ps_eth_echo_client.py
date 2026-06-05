#!/usr/bin/env python3
"""09_ps_net TCP echo test without telnet client."""
import socket
import sys

HOST = "10.0.0.10"
PORT = 7
MSG = b"hello_ps_eth\n"

def main():
    print(f"[TCP] connect {HOST}:{PORT} ...")
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(10)
    try:
        s.connect((HOST, PORT))
    except socket.timeout:
        print("[FAIL] connect timeout — board->PC path or board not listening")
        return 1
    except OSError as e:
        print(f"[FAIL] connect error: {e}")
        return 1

    s.sendall(MSG)
    print(f"[TX] {MSG!r}")
    try:
        data = s.recv(64)
    except socket.timeout:
        print("[FAIL] connected but no echo (half-open?)")
        return 1
    print(f"[RX] {data!r}")
    if data:
        print("[PASS] ps_eth TCP echo OK")
        return 0
    print("[FAIL] empty echo")
    return 1
    finally:
        s.close()

if __name__ == "__main__":
    sys.exit(main())
