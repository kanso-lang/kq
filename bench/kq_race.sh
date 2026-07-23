#!/bin/sh
# kq vs jq, interleaved, whole-process wall time (spawn + parse + query +
# print). Verifies byte-identity before racing — a fast wrong answer is
# not a result. Run from the repo root with ./kq built.
set -e
python3 - <<'PY'
import json, subprocess, time
d = json.load(open('bench/large.json'))
json.dump(d * 10, open('/tmp/kq_big.json', 'w'), separators=(',', ':'))
def gate(q, f):
    a = subprocess.run(['./kq', q, f], capture_output=True).stdout
    b = subprocess.run(['jq', '-S', q, f], capture_output=True).stdout
    assert a == b, f"kq and jq disagree on {q} {f}"
def t(cmd):
    x = time.perf_counter()
    subprocess.run(cmd, capture_output=True)
    return (time.perf_counter() - x) * 1000
races = [('.[0].k0_30', 'bench/large.json', 25),
         ('.[0].k0_30', '/tmp/kq_big.json', 15),
         ('.', 'bench/large.json', 25),
         ('.', '/tmp/kq_big.json', 15)]
for q, f, n in races:
    gate(q, f)
    kq, jq = [], []
    for _ in range(n):
        kq.append(t(['./kq', q, f]))
        jq.append(t(['jq', '-S', q, f]))
    wins = sum(1 for a, b in zip(kq, jq) if a < b)
    print(f"{q:12} {f:22} kq {min(kq):6.1f}ms  jq {min(jq):6.1f}ms  "
          f"({min(jq)/min(kq):.2f}x, kq wins {wins}/{n})")
PY
