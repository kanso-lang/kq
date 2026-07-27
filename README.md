# kq

A `jq`-style JSON query tool, written in [kanso](https://kanso-lang.dev). Output
is byte-identical to `jq -S` on every query below — verified with `diff`, not
claimed.

## Speed

Interleaved runs (kq and jq alternate, so machine state hits both alike),
whole-process wall time (startup + read + parse + query + print), best of N
per side, byte-identity verified before any timing. Apple M-series,
**2026-07-26, loaded desktop** (load average 4.0; every row measured in that
one sitting, after the encoder stopped allocating a header for every append).
Reproduce: `sh bench/kq_race.sh`.

| workload | kq | jq 1.7.1 | wall | kq cpu | jq cpu | cpu |
|---|---:|---:|---|---:|---:|---|
| path query, 188 KB (`.[0].k0_30`) | **2.6 ms** | 4.4 ms | 1.73x | **2.0 ms** | 3.9 ms | 1.97x |
| path query, 1.9 MB (`.[0].k0_30`) | **12.3 ms** | 23.3 ms | 1.89x | **11.2 ms** | 22.7 ms | 2.02x |
| full pretty-print, 188 KB (`.`) | **5.0 ms** | 12.1 ms | 2.43x | **4.0 ms** | 11.4 ms | 2.88x |
| full pretty-print, 1.9 MB (`.`) | **35.4 ms** | 101.0 ms | 2.85x | **32.4 ms** | 100.3 ms | 3.10x |

Both instruments, same sitting. cpu time counts only what each process spent,
so a passing background task cannot inflate it; wall time is what a user
waits. kq leads by more under cpu because its wall figure carries process
startup that the query itself does not.

There is a third instrument that no sitting can move at all: the hardware
counters. Retired instructions are the work a process actually did, cycles are
what that work cost the processor, and neither is affected by anything else
running. They reproduce to within a few tenths of a percent run to run.

| full pretty-print, 1.9 MB | kq | jq 1.7.1 | |
|---|---:|---:|---|
| instructions retired | **680,353,290** | 2,341,058,047 | kq does 3.44x less work |
| cycles elapsed | **144,050,539** | 438,457,550 | and 3.04x fewer cycles |
| instructions per cycle | 4.72 | **5.34** | so kq stalls ~12% more often |
| peak footprint | 139.9 MB | **30.7 MB** | kq holds 4.6x more |
| peak / input size | 71.0x | **15.6x** | |
| page reclaims | 8,731 | **2,096** | kq faults 4.2x more pages |

Reading the rows together is the point, and the story they tell is not
flattering in one place. kq does under a third of jq's work and wins every
clock, but it banks only part of that lead: a working set four and a half times
larger costs it about an eighth of its instruction throughput.

The reason is upstream in the compiler rather than in kq. kanso's arena rewinds
between loop iterations when it can prove the iteration keeps nothing across
the line, and an accumulator breaks that proof by construction:
`encode_items acc xs i` hands `(elem_onto acc xs[i])` onward, so the value
crossing the boundary was born this iteration and has to outlive the rewind.
The analysis declines, and then nothing is reclaimed — including everything the
iteration allocated that was *not* the accumulator. Exactly one of kq's loops
rewinds today; the three on the pretty-print path all decline on their
accumulator.

The output being accumulated is a few megabytes. The process holds 139.9. That
gap is the opportunity, it is a named entry on kanso's optimisation ledger, and
closing it takes both the footprint and the rest of the stall back.

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
