# kq

A `jq`-style JSON query tool, written in [kanso](https://kanso-lang.dev). Output
is byte-identical to `jq -S` on every query below — verified with `diff`, not
claimed.

## Speed

Interleaved runs (kq and jq alternate, so machine state hits both alike),
whole-process wall time (startup + read + parse + query + print), best of N
per side, byte-identity verified before any timing. Apple M-series,
**2026-07-27, loaded desktop** (load average 3.5; every row measured in that
one sitting, after outgrown collection buffers started reaching the reuse
shelf and string literals started building once). Reproduce:
`sh bench/kq_race.sh`.

| workload | kq | jq 1.7.1 | wall | kq cpu | jq cpu | cpu |
|---|---:|---:|---|---:|---:|---|
| path query, 188 KB (`.[0].k0_30`) | **3.0 ms** | 4.8 ms | 1.61x | **2.3 ms** | 4.2 ms | 1.87x |
| path query, 1.9 MB (`.[0].k0_30`) | **12.6 ms** | 25.6 ms | 2.03x | **11.5 ms** | 24.6 ms | 2.13x |
| full pretty-print, 188 KB (`.`) | **5.2 ms** | 13.4 ms | 2.57x | **4.4 ms** | 12.6 ms | 2.89x |
| full pretty-print, 1.9 MB (`.`) | **34.9 ms** | 106.1 ms | 3.04x | **33.5 ms** | 104.7 ms | 3.13x |

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
| instructions retired | **681,402,687** | 2,340,205,820 | kq does 3.43x less work |
| cycles elapsed | **138,839,540** | 433,314,812 | and 3.12x fewer cycles |
| instructions per cycle | 4.91 | **5.40** | jq packs its work tighter |
| peak footprint | **30.0 MB** | 30.8 MB | kq now holds less |
| peak / input size | **15.2x** | 15.6x | |
| page reclaims | **2,027** | 2,102 | and faults fewer pages |

Reading the rows together is the point. kq does under a third of jq's
work, wins every clock, and now holds less memory on every workload: the
pretty printer streams — each top-level element is rendered, written, and
dead before the next is built, so the output never exists as one string —
and every loop on the print path rewinds the arena between iterations, so
each iteration's temporaries die at the boundary. The one row jq keeps is
instructions per cycle, and it reads correctly: kq spends fewer total
instructions and more of them are the stream's bookkeeping.

The machinery under those rows is kanso's, and it is worth a paragraph. The
arena rewinds between loop iterations when the compiler proves the iteration
keeps nothing across the line, and a byte accumulator earns that proof by
pointer identity: it is the very object that arrived at the loop's entry,
threaded through appends the uniqueness analysis showed in place, with its
growth outside the arena where a rewind cannot reach. Every loop on kq's
print path qualifies, so each element's temporaries die the moment the next
element begins.

What remains of kq's footprint is the decoded document — live across the
whole run by construction — plus the decode-phase transients the region
holds until exit. The output no longer contributes: it streams.

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
