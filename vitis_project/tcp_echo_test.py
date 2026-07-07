import socket
try:
    s = socket.socket()
    s.settimeout(8)
    s.connect(("10.0.0.10", 7))
    s.send(b"hello\n")
    print("recv:", s.recv(64))
    print("TCP_OK")
except Exception as e:
    print("TCP_FAIL:", e)
finally:
    s.close()
