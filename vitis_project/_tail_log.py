import sys
p = sys.argv[1]
with open(p, encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
n = int(sys.argv[2]) if len(sys.argv) > 2 else 30
for line in lines[-n:]:
    print(line, end="")
