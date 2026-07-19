#!/bin/sh
# kq's spec suite: unit tests, then fixture goldens, then (when jq is
# present) byte-identity against jq -S on every fixture x query. CI gates
# on all three. KANSO points at the compiler binary.
set -e
KANSO=${KANSO:-kanso}

echo "== unit tests =="
"$KANSO" test .

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
