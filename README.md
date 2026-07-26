# kq

A `jq`-style JSON query tool, written in [kanso](https://kanso-lang.dev). Output
is byte-identical to `jq -S` on every query below — verified with `diff`, not
claimed.

## Speed

Interleaved runs (kq and jq alternate, so machine state hits both alike),
whole-process wall time (startup + read + parse + query + print), best of N
per side, byte-identity verified before any timing. Apple M-series,
**2026-07-26, loaded desktop** (load average 9.6; every row measured in that
one sitting, after the utf-8 validator stopped paying vector setup on short
ascii keys). Reproduce: `sh bench/kq_race.sh`.

| workload | kq | jq 1.7.1 | wall | kq cpu | jq cpu | cpu |
|---|---:|---:|---|---:|---:|---|
| path query, 188 KB (`.[0].k0_30`) | **2.7 ms** | 4.6 ms | 1.72x | **2.0 ms** | 4.0 ms | 2.01x |
| path query, 1.9 MB (`.[0].k0_30`) | **12.7 ms** | 24.3 ms | 1.91x | **11.4 ms** | 23.5 ms | 2.06x |
| full pretty-print, 188 KB (`.`) | **5.5 ms** | 12.5 ms | 2.28x | **4.4 ms** | 11.6 ms | 2.67x |
| full pretty-print, 1.9 MB (`.`) | **40.5 ms** | 103.8 ms | 2.57x | **36.5 ms** | 102.0 ms | 2.79x |

Both instruments, same sitting. cpu time counts only what each process spent,
so a passing background task cannot inflate it; wall time is what a user
waits. kq leads by more under cpu because its wall figure carries process
startup that the query itself does not.

There is a third instrument that no sitting can move at all: retired
instructions, which count the work a process actually did. It reproduces to
within a few tenths of a percent run to run, and it is the honest answer to
"which program does less."

| workload | kq instructions | jq instructions | |
|---|---:|---:|---|
| path query, 188 KB | 31,854,045 | 66,121,065 | 2.08x less work |
| path query, 1.9 MB | 221,348,374 | 421,427,785 | 1.90x less work |
| full pretty-print, 188 KB | 81,624,617 | 257,638,100 | 3.16x less work |
| full pretty-print, 1.9 MB | 723,351,894 | 2,341,189,352 | 3.24x less work |

Reading it beside the clock is the interesting part. On the largest row kq
does 3.24x less work but takes only 2.85x fewer cycles, because its
instructions retire at 4.55 per cycle against jq's 5.16 — kq's arena grows
monotonically and touches more distinct cache lines, where jq's malloc reuses
memory that is already hot. kq is further ahead in work than in time, and the
difference between those two numbers is what is still on the table.

Absolutes here carry the load; a quiet box brings every row down.

An earlier table published 4.70x on the last row. That figure does not
reproduce and should not have been a headline. It came from a sitting at load
~50, where the same binary timed twice ran 87% apart — jq measured 261 ms there
against 104 ms today, and jq is unchanged software, so the old number was the
artifact. kq's own absolute fell over the same period, 55.5 ms to 40.5 ms.
Today's multiples reproduce across two loads and both instruments, which is why
they are the ones here.

Racing the previous kq binary against this one in a single sitting isolates
what the compiler change bought, with byte-identity checked first: +5.7% and
+9.4% on the path queries, +2.9% and +4.4% on the pretty-prints. Whole-process
timing dilutes it — the decode itself got about a tenth faster, but startup,
the file read and the print do not.

The path-query gap grows with document size: kq decodes, walks to the subtree,
and prints only that — the win compounds as the part you didn't ask for gets
bigger. Pretty-printing used to be jq's board; the byte builder in the encode
path (one accumulator threaded through the whole tree, escape scanning proven
clean in one SIMD pass) flipped it, hardest on the biggest documents.

**One deliberate difference:** on a path that doesn't exist, `jq` prints
`null`; kq reports an error naming the missing key. kanso treats a missing
index as a failure to surface, not a nothing to pass along — if you want
jq's silence, query a path that exists. The race harness verifies
byte-identity per query before timing anything, which is exactly how this
difference was caught.

## Use

```
kq <path> [file.json]        # or pipe json on stdin
kq .users[3].name data.json
```

## Why it's fast

kq is ~400 lines of kanso sharing its decoder with the standard library — the
same decoder that outruns hand-tuned serde_json on the language's json
gauntlet. No hand-written parser tricks live in this directory; the speed is
the compiler's. The story: [kanso-lang.dev/compiler.html](https://kanso-lang.dev/compiler.html).

## Specs

`sh spec.sh` (with `KANSO` pointing at a kanso build) runs the unit tests,
then eleven fixture cases over non-trivial JSON — unicode/CJK/emoji and
escapes, precision-edge numbers, deep nesting and empty containers, and the
188 KB nested document — each checked against a committed golden AND against
live `jq -S` byte-for-byte. CI gates on all of it.

Intel macs: no GitHub runners exist for that target anymore; build from
source (`kanso build .`) or use Rosetta until a cross-build lands.
