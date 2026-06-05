import socket, time

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4*1024*1024)
s.bind(('', 5002))
s.settimeout(10)
print('[TEST] Listening 10s on UDP :5002 (broadcast)...')
try:
    d, addr = s.recvfrom(65535)
    print(f'[TEST] GOT {len(d)} bytes from {addr}')
except socket.timeout:
    print('[TEST] TIMEOUT - no packets in 10s')
s.close()
