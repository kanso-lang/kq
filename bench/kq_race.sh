#!/bin/sh
# kq vs jq, interleaved, whole-process wall time (spawn + parse + query +
# print). Verifies byte-identity before racing — a fast wrong answer is
# not a result. Run from the repo root with ./kq built.
set -e
python3 - <<'PY'
import json, re, resource, subprocess, time
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
def c(cmd):
    # cpu time counts only what the process spent, so a busy box cannot
    # inflate it — the instrument that settles a disputed multiple
    b = resource.getrusage(resource.RUSAGE_CHILDREN)
    subprocess.run(cmd, capture_output=True)
    a = resource.getrusage(resource.RUSAGE_CHILDREN)
    return ((a.ru_utime - b.ru_utime) + (a.ru_stime - b.ru_stime)) * 1000
FIELDS = ('instructions retired', 'cycles elapsed', 'peak memory footprint',
          'page reclaims')
def hw(cmd):
    # the process's own work, unaffected by anything else on the box and
    # reproducible to a fraction of a percent. instructions against cycles
    # separates how much work a program does from how well that work runs,
    # and the memory rows are usually the reason the two differ. darwin only.
    out = subprocess.run(['/usr/bin/time', '-l'] + cmd, capture_output=True, text=True).stderr
    got = []
    for label in FIELDS:
        m = re.search(r'(\d+)\s+' + re.escape(label), out)
        if not m:
            return None
        got.append(int(m.group(1)))
    return got
races = [('.[0].k0_30', 'bench/large.json', 25),
         ('.[0].k0_30', '/tmp/kq_big.json', 15),
         ('.', 'bench/large.json', 25),
         ('.', '/tmp/kq_big.json', 15)]
for q, f, n in races:
    gate(q, f)
    kq, jq, kqc, jqc = [], [], [], []
    for _ in range(n):
        kq.append(t(['./kq', q, f]))
        jq.append(t(['jq', '-S', q, f]))
        kqc.append(c(['./kq', q, f]))
        jqc.append(c(['jq', '-S', q, f]))
    wins = sum(1 for a, b in zip(kq, jq) if a < b)
    print(f"{q:12} {f:22} wall kq {min(kq):6.1f} jq {min(jq):6.1f} ({min(jq)/min(kq):.2f}x)  "
          f"cpu kq {min(kqc):6.1f} jq {min(jqc):6.1f} ({min(jqc)/min(kqc):.2f}x)  "
          f"kq wins {wins}/{n}")
    kh, jh = hw(['./kq', q, f]), hw(['jq', '-S', q, f])
    if kh and jh:
        print(f"{'':12} {'':22} work {jh[0]/kh[0]:.2f}x less  cycles {jh[1]/kh[1]:.2f}x fewer  "
              f"ipc {kh[0]/kh[1]:.2f} vs {jh[0]/jh[1]:.2f}")
        print(f"{'':12} {'':22} peak {kh[2]/1e6:.1f}M vs {jh[2]/1e6:.1f}M ({kh[2]/jh[2]:.1f}x)  "
              f"pages {kh[3]:,} vs {jh[3]:,}")
PY
