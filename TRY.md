# Try kq

Install:

```sh
brew install kanso-lang/tap/kq
```

The commands below assume a clone of the kanso repo for its benchmark
fixture (or use any large JSON file you have):

```sh
cd ~/dev/kanso

# correctness: full-document output, byte-identical to jq -S
diff <(kq . bench/large.json) <(jq -S . bench/large.json) && echo IDENTICAL

# a path query: pull one subtree out of the document
kq '.[0].k0_30' bench/large.json | head -20
diff <(kq '.[0].k0_30' bench/large.json) <(jq -S '.[0].k0_30' bench/large.json) && echo IDENTICAL

# eyeball the speed difference on paths
time kq '.[0].k0_30' bench/large.json > /dev/null
time jq -S '.[0].k0_30' bench/large.json > /dev/null

# the honest race: interleaved, byte-identity gated, all four workloads
sh bench/kq_race.sh

# bigger document: the path-query gap grows with size
python3 -c "import json; d=json.load(open('bench/large.json')); json.dump(d*10, open('/tmp/big.json','w'))"
time kq '.[0].k0_30' /tmp/big.json > /dev/null
time jq -S '.[0].k0_30' /tmp/big.json > /dev/null

# stdin works too
cat bench/large.json | kq '.[0].k0_30'
```

Notes:

- Quote paths containing `[` — zsh globs them otherwise.
- Expected: both diffs print IDENTICAL; the path query runs ~3.6ms vs ~5.8ms at
  188 KB and ~16ms vs ~28ms at 1.9 MB (kq walks to the subtree and prints
  only that). The race script refuses to time anything that is not
  byte-identical to jq first.
- The race script rebuilds kq from source; the other commands exercise the
  brew-installed binary.
