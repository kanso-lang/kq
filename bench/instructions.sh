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

# glibc is not the whole host. Its ifunc resolvers pick memcpy, memcmp,
# strlen and their neighbours by CPU feature at load time, so the same libc on
# other silicon counts differently — measured at a 0.63% spread from the
# dispatch alone, and 1.02% on print_small for one switch that differs between
# the container these were prepared in and a runner. bench/dispatch.txt carries
# that evidence and the block itself.
#
# THE RUNNER POOL IS NOT ONE CPU. Three CI runs on 2026-09-01 landed on three
# different ones: an AMD EPYC Zen 3 (family 0x19, model 0x1), an Intel Ice
# Lake-SP (0x6/0x6a), and the container these were prepared in is a Cascade
# Lake (0x6/0x55). So the first shape of this check — refuse wherever the block
# differs — would have been red on most runs for a reason no pull request
# causes, which is a gate nobody can act on.
#
# The dispatch block is therefore read AFTER the rows, and only when a row
# moved. A row that lands on its recorded value is right whatever counted it,
# and needs no question asked. A row that moved gets the question, and the
# answer is printed BESIDE the failure rather than instead of it: the vein
# fails on a moved row whatever counted it, and names the differing feature
# lines when it can, so a reader knows in one screen whether to re-run for the
# recorded CPU or start reading the diff.
#
# bench/dispatch.txt IS NOT IN THE TREE YET, and its absence is deliberate.
# The file has to hold a CPU on which these rows are known to verify, and no
# run has both named its silicon and matched the golden — the naming only
# starts here. A guessed block would be worse than none: it would let a real
# regression on the true recorded CPU read as other silicon, which is the one
# failure this whole check exists to prevent in the opposite direction. Absent,
# the vein gates exactly as it always has. The block goes in from the first run
# that prints its CPU and matches all four rows.
dispatch=bench/dispatch.txt
loader=/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
host_block() {
  # cpuid[0x1] is leaf 1 EBX and its top byte is the initial APIC id, which
  # is to say which core this process happened to start on. Six runs on one
  # host gave three values for it and one value for every other line, so it
  # is the only line excluded, and the exclusion is measured not assumed.
  [ -x "$loader" ] || return 1
  "$loader" --list-diagnostics 2>/dev/null \
    | grep '^x86\.cpu_features' \
    | grep -v 'features\[0x0\]\.cpuid\[0x1\]=' \
    | sort
}
host_block > /tmp/kq_dispatch_now.txt || true
[ -f "$dispatch" ] && grep -v '^#' "$dispatch" > /tmp/kq_dispatch_want.txt
if [ -s /tmp/kq_dispatch_now.txt ]; then
  fam=$(sed -n 's/^x86.cpu_features.basic.family=//p' /tmp/kq_dispatch_now.txt)
  mod=$(sed -n 's/^x86.cpu_features.basic.model=//p' /tmp/kq_dispatch_now.txt)
  echo "instructions vein: this cpu is family $fam model $mod"
  # While no block is recorded, CI prints the whole thing, because that is the
  # only way one ever gets recorded: a block may be taken only from a run that
  # BOTH names its cpu and matches every row, and a run that matches never
  # reaches the mismatch path below. Printing 123 lines on every green run
  # afterwards would be noise, so this stops as soon as the file exists.
  if [ ! -f "$dispatch" ] && [ -n "$GITHUB_ACTIONS" ]; then
    echo "--- no block recorded; if every row below matches, this is the one"
    echo "--- to copy into $dispatch"
    cat /tmp/kq_dispatch_now.txt
  fi
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
  # A row moved. If this is not the silicon the rows were counted on, say so
  # and name the lines — but BESIDE the failure, never instead of it.
  #
  # An earlier shape of this exited 0 here, and it was wrong twice over. Four
  # CPUs turned up in four runs on 2026-09-01, so roughly three runs in four
  # land off the recorded block and would have waved a real regression
  # through. And kanso's ratchet keeps mutations whose whole job is to redden
  # this gate through the kq specs row: on those runs they would have proved
  # nothing, which is a BLIND row — the one failure that machinery exists to
  # catch. A gate that manufactures them is worse than no gate.
  #
  # Deciding that silicon accounts for a move is a person's job in a pull
  # request, with a re-run that lands on the recorded CPU as the evidence.
  if [ -s /tmp/kq_dispatch_now.txt ] && [ -s /tmp/kq_dispatch_want.txt ] \
     && ! diff -q /tmp/kq_dispatch_want.txt /tmp/kq_dispatch_now.txt >/dev/null
  then
    echo "::error::and this is NOT the silicon these rows were counted on, so"
    echo "::error::the dispatch below may account for some of the move. It"
    echo "::error::does not excuse it: re-run until the job lands on the"
    echo "::error::recorded CPU, and say in the PR which way it went."
    echo "the CPU features that differ (recorded < , here > ):"
    diff /tmp/kq_dispatch_want.txt /tmp/kq_dispatch_now.txt || true
    if [ -n "$GITHUB_ACTIONS" ]; then
      echo "--- this host's block, should a fresh sitting record it ---"
      cat /tmp/kq_dispatch_now.txt
    fi
  fi
  # The rows again, AFTER the dispatch block, because that block is 123 lines
  # and the diff above it is what a reader actually needs. kanso's twin of
  # this gate learned the same thing about its own eighty-line profile: a
  # diagnostic the log API will not hand back is one nobody can fetch, and
  # the tail is the only part it reliably hands back. A session bumping the
  # pin from a container cannot measure these rows itself — that is the whole
  # point of the measured-on refusal above — so this print is how the numbers
  # travel from the runner into the golden.
  echo "=== every row as measured here, to copy into the golden"
  cat work.txt
  echo "::error::the work kq does changed. A rise is a regression to explain"
  echo "::error::and a fall is a win to bank — say which in the PR and"
  echo "::error::regenerate"
  echo "::error::bench/instructions_golden.txt. This is the vein that would"
  echo "::error::have caught the two quadratics whose fix took the 1.9 MB"
  echo "::error::print from 147 ms to 39.8 ms while every allocator counter"
  echo "::error::in this repo held still."
  exit 1
fi
