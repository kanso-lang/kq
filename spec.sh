#!/bin/sh
# kq's spec suite: unit tests, then fixture goldens, then (when jq is
# present) byte-identity against jq -S on every fixture x query. CI gates
# on all three. KANSO points at the compiler binary.
#
# KQ_STORED=report downgrades the checks that compare against a FILE — the
# cost goldens and the published-numbers stamp — from gating to reporting.
# Nothing else changes, and the default is unchanged.
#
# The split is by what a check compares itself to, not by what it measures.
# Unit tests, the fixture goldens and the scale gate all compute their
# reference inside the same run, so they cannot be stale and stay gating
# wherever they run. The cost goldens and the stamp compare against values
# committed here, which are only true for the compiler this repo pins.
#
# That matters upstream. kanso's CI runs this suite against the compiler on
# its pull request, and between a kanso merge and the pin bump here the two
# disagree — so every unrelated kanso PR opened in that window failed on a
# stored number that had nothing to do with it. Correctness is what kanso
# needs to gate on; these numbers are this repo's to judge, at the moment it
# chooses to absorb a compiler.
set -e
KANSO=${KANSO:-kanso}
STORED=${KQ_STORED:-gate}

echo "== unit tests =="
"$KANSO" test query

echo "== build =="
"$KANSO" build "$(pwd)" --release >/dev/null

run_case() {
  query=$1; fixture=$2; name=$3
  actual=$(./kq "$query" "fixtures/$fixture.json")
  expected=$(cat "fixtures/expected/$name.out")
  if [ "$actual" != "$expected" ]; then
    echo "GOLDEN MISMATCH: $name ($query on $fixture)"; exit 1
  fi
  if command -v jq >/dev/null; then
    theirs=$(jq -S "$query" "fixtures/$fixture.json")
    if [ "$actual" != "$theirs" ]; then
      echo "JQ DIVERGENCE: $name ($query on $fixture)"; exit 1
    fi
  fi
  echo "ok: $name"
}

run_case '.'                    unicode  unicode_identity
run_case '.mixed[3].deep_key'   unicode  unicode_path
run_case '.escapes'             unicode  unicode_escapes
run_case '.'                    numbers  numbers_identity
run_case '.big_int'             numbers  numbers_bigint
run_case '.floats[3]'           numbers  numbers_exponent
run_case '.'                    edge     edge_identity
run_case '.deep.a.b.c.d.e[1].f' edge     edge_deep_path
run_case '.empty_obj'           edge     edge_empty
run_case '.'                    nested   nested_identity
run_case '.[0].k0_30'           nested   nested_path

echo "kq specs: all green"

echo "== cost goldens (allocator counters, deterministic, diffed) =="
check_costs() {
  query=$1; golden=$2
  KANSO_COUNTERS=1 ./kq "$query" bench/large.json >/dev/null 2>/tmp/kq_counters.txt
  grep -E "^[a-z0-9_]+=" /tmp/kq_counters.txt > /tmp/kq_counters_clean.txt
  if ! diff "$golden" /tmp/kq_counters_clean.txt; then
    echo "COST DRIFT: $golden — the allocator counters moved. A fall is a win"
    echo "to bank and a rise is a regression to explain; either way, say which"
    echo "in the PR and regenerate the golden there. This diff has no opinion"
    echo "about direction — the scale gate below is what refuses a regression."
    [ "$STORED" = report ] || exit 1
    echo "(reported, not gated: this golden belongs to the pinned compiler)"
    return 0
  fi
  echo "ok: $golden"
}
check_costs '.'           bench/cost_golden.txt
check_costs '.[0].k0_30'  bench/cost_golden_decode.txt

echo "== scale gate (every counter linear in the input) =="
"$KANSO" run bench/scale_gate.kso

echo "== published numbers still describe this compiler =="
if [ "$STORED" = report ]; then
  "$KANSO" run bench/numbers_gate.kso \
    || echo "(reported, not gated: the stamp belongs to the pinned compiler)"
else
  "$KANSO" run bench/numbers_gate.kso
fi
