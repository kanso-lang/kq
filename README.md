# kq

A `jq`-style JSON query tool, written in [kanso](https://kanso-lang.dev). Output
is byte-identical to `jq -S` on every query below — verified with `diff`, not
claimed.

## Speed

Interleaved runs (kq and jq alternate, so machine state hits both alike),
whole-process wall time (startup + read + parse + query + print), best of N
per side on an idle machine, byte-identity verified before any timing.
Apple M-series. Reproduce: `sh bench/kq_race.sh`.

| workload | kq | jq 1.7.1 | |
|---|---:|---:|---|
| path query, 188 KB (`.[0].k0_30`) | **3.0 ms** | 4.8 ms | kq 1.62x faster, 25/25 runs |
| path query, 1.9 MB (`.[0].k0_30`) | **13.9 ms** | 24.6 ms | kq 1.78x faster, 15/15 runs |
| full pretty-print, 188 KB (`.`) | **6.5 ms** | 12.7 ms | kq 1.97x faster, 25/25 runs |
| full pretty-print, 1.9 MB (`.`) | **49.7 ms** | 104.9 ms | kq 2.11x faster, 15/15 runs |

**Latest sitting (2026-07-23, after the compiler gained the eisel-lemire
float parser; loaded desktop, interleaved so both tools face the same
conditions):** path 1.36x / 1.69x, pretty-print 1.98x / 1.91x over jq,
kq ahead on all four boards. The idle-machine table above refreshes on
the next quiet sitting.

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
