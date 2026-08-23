#!/bin/sh
# The dimension none of kq's other veins can see.
#
# Bumping the pin fourteen commits on 2026-08-14 moved the headline row from
# 147 ms to 39.8 ms — a 3.7x change in the number the README publishes — and
# every deterministic gate in this repo stayed green without regeneration.
# Both cost goldens passed, the scale gate passed, and bench/numbers_gate,
# whose entire job is to notice that the published numbers no longer describe
# the compiler in the tree, passed too.
#
# That is because both quadratics were invisible to an allocator counter: one
# was a survival check that allocates nothing, the other a copy into a buffer
# that already existed. The gate answers "were the allocations the same" and
# gets read as "do the published numbers still hold". Here those came apart in
# the favourable direction; nothing stopped the next one going the other way.
#
# Callgrind counts rather than samples, so three runs give the same digits and
# no other process on the box can reach it. The environment is emptied because
# the kernel copies it onto the new process's stack and libc walks it before
# main, so a run id that gained a digit reads as work nobody wrote.
set -e
: "${KQ:=./kq}"

# Whose numbers these are. The first line of the golden says these rows are
# counted on the linux runner, and until this existed nothing checked it —
# kanso learned on 2026-08-23 that two ubuntu 24.04 boxes one glibc revision
# apart read a vein like this one hundreds of instructions apart, which is
# larger than most of what it exists to catch. Anywhere but the host named in
# the golden, this refuses before spending a minute measuring, and prints no
# numbers at all: a diff is what invites somebody to paste it.
#
# glibc alone, not valgrind: callgrind's version moves every row at once the
# way any toolchain bump does, and pinning it here would make this unanswerable
# on a box with no valgrind to ask.
glibc=$(ldd --version 2>/dev/null | head -1 | sed -n 's/.*GLIBC \([^)]*\)).*/\1/p')
if [ -z "$glibc" ]; then
  glibc=$(ldd --version 2>/dev/null | head -1 | awk '{print $NF}')
fi
have="glibc=${glibc:-unknown}"
want=$(sed -n 's/^# measured-on //p' bench/instructions_golden.txt)
echo "instructions vein: measured-on $want; here $have"
if [ "$want" != "$have" ]; then
  echo "::error::these rows were measured on $want and this host is $have,"
  echo "::error::so the two cannot be compared. Do not regenerate"
  echo "::error::bench/instructions_golden.txt from here — let CI measure it"
  echo "::error::and copy the rows out of the job log. If the runner image"
  echo "::error::itself moved, every row moves with it and none has"
  echo "::error::regressed: regenerate all four in one go, update the"
  echo "::error::measured-on line, and say so in the pull request."
  exit 1
fi

# The 1.9 MB fixture is ten flat copies of what the repo already carries, the
# same one bench/kq_race.sh builds. It is the row the two quadratics lived in,
# so a vein that skipped it would miss the thing it exists for.
python3 -c "
import json
d = json.load(open('bench/large.json'))
json.dump(d * 10, open('/tmp/kq_big.json', 'w'), separators=(',', ':'))
"

for row in ".:bench/large.json:print_small" \
           ".:/tmp/kq_big.json:print_big" \
           ".[0].k0_30:bench/large.json:path_small" \
           ".[0].k0_30:/tmp/kq_big.json:path_big"; do
  q=${row%%:*}; rest=${row#*:}; f=${rest%%:*}; name=${rest#*:}
  env -i PATH=/usr/bin:/bin \
    valgrind --tool=callgrind --callgrind-out-file=/tmp/cg.$name "$KQ" "$q" "$f" \
    >/dev/null 2>/tmp/ir.$name
  printf '%s %s\n' "$name" "$(grep -o 'I   refs:.*' /tmp/ir.$name | tr -dc 0-9)"
done > work.txt

if [ ! -f bench/instructions_golden.txt ]; then
  echo "no golden yet — these are the numbers to commit:"
  cat work.txt
  exit 1
fi

grep -v '^#' bench/instructions_golden.txt > work_want.txt
if diff work_want.txt work.txt; then
  echo "instructions: every row is where it was"
else
  echo "::error::the work kq does changed. A rise is a regression to explain"
  echo "::error::and a fall is a win to bank — say which in the PR and"
  echo "::error::regenerate bench/instructions_golden.txt. This is the vein"
  echo "::error::that would have caught the two quadratics whose fix took the"
  echo "::error::1.9 MB print from 147 ms to 39.8 ms while every allocator"
  echo "::error::counter in this repo held still."
  exit 1
fi
