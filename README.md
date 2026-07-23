# kq

A `jq`-style JSON query tool, written in [kanso](https://kanso-lang.dev). Output
is byte-identical to `jq -S` on every query below — verified with `diff`, not
claimed.

## Speed

Interleaved runs (kq and jq alternate, so machine state hits both alike),
whole-process wall time (startup + read + parse + query + print), best of N
per side, byte-identity verified before any timing. Apple M-series,
**2026-07-23, loaded desktop** (interleaving keeps the comparison fair
under load). Reproduce: `sh bench/kq_race.sh`.

| workload | kq | jq 1.7.1 | |
|---|---:|---:|---|
| path query, 188 KB (`.[0].k0_30`) | **8.3 ms** | 11.4 ms | kq 1.36x faster |
| path query, 1.9 MB (`.[0].k0_30`) | **29.1 ms** | 49.2 ms | kq 1.69x faster |
| full pretty-print, 188 KB (`.`) | **10.5 ms** | 20.8 ms | kq 1.98x faster |
| full pretty-print, 1.9 MB (`.`) | **177 ms** | 338 ms | kq 1.91x faster |

Idle-machine floors from the last quiet sitting (same protocol): path
3.0 ms / 13.9 ms, pretty 6.5 ms / 49.7 ms — absolute times shrink when
the box is quiet; the ratios hold either way.

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
