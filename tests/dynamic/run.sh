#!/bin/sh
# Dynamic tests. Each package under tests/dynamic/ is a binary that
# depends on this checkout (uploaded to a scratch copy of the repository
# first); it must build and exit 0. Used where a property cannot be
# expressed in types (e.g. which value a comparison returns).
#
# If the package has an `expected` file, the binary's output must match
# it exactly. If it has a `no-leaks` file, it runs under valgrind, which
# must find no block definitely or indirectly lost (there is no GC: a
# cell nothing frees is lost for good). If it has a `no-alloc-bytes` file
# holding a size, it runs under valgrind's --trace-malloc=yes, which prints
# one line for every block the program allocates, and no block may be of
# that size: a small rope must not make a BUILDER_CAP array (builder#51).
# Every block is counted, not a site's total (DHAT's "tb" is a site's total
# bytes and "tbk" its blocks, so a site that makes the size twice, or the size
# and other blocks, has a total that is not the size: builder#55). A package
# with a `no-alloc-bytes-control` file instead is a negative control: it
# allocates a block of that size from a site whose total is not the size, and
# passes only when the check finds the block and fails.
#
# usage: tests/dynamic/run.sh <repository-dir>   (bats must be on PATH)
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# count_blocks SIZE LOG: how many blocks of SIZE bytes a --trace-malloc log
# (valgrind --help-debug: "debugging options for Valgrind tools that replace
# malloc") records, one line "--pid-- name(args) = address" for each call.
# The size is the requested one: malloc(N) and the operator new forms take
# N, calloc(N,M) N*M, realloc(P,N) the new size N, and the aligned forms
# (memalign, posix_memalign, aligned_alloc, new with an alignment) the
# number after "size ". The frees are skipped. A line of any other name
# prints "unrecognised: <line>" instead of a count, so no allocator form is
# silently ignored. Lines without the "--pid-- " prefix are the program's.
count_blocks () {
  awk -v size="$1" '
    /^--[0-9]+-- / {
      call = $0; sub(/^--[0-9]+-- /, "", call)
      name = call; sub(/\(.*/, "", name)
      args = call; sub(/^[^(]*\(/, "", args); sub(/\).*/, "", args)
      if (name == "malloc" || name ~ /^(__builtin_(vec_)?new|_Zn[wa]m(RKSt9nothrow_t)?)$/) bytes = args
      else if (name == "calloc") { split(args, a, ","); bytes = a[1] * a[2] }
      else if (name == "realloc") { split(args, a, ","); bytes = a[2] }
      else if (name ~ /^(memalign|posix_memalign|aligned_alloc|_Zn[wa]mSt11align_val_t(RKSt9nothrow_t)?)$/) { bytes = args; sub(/.*size /, "", bytes) }
      else if (name ~ /^(free|cfree|malloc_usable_size|__builtin_(vec_)?delete|_Zd[la]Pv.*)$/) next
      else { print "unrecognised: " $0; bad = 1; exit }
      if (bytes + 0 == size + 0) hits++
    }
    END { if (!bad) print hits + 0 }' "$2"
}

# The table of fixed log lines (trace-malloc-lines: size, the count
# count_blocks must report or "unrecognised", the log line, tab separated)
# is run first, so every branch of count_blocks is exercised and a
# mismatch fails the run.
tab=$(printf '\t')
table_bad=0
while IFS="$tab" read -r tsize want line; do
  case "$tsize" in ''|'#'*) continue ;; esac
  printf '%s\n' "$line" > "$TMP/table.log"
  got=$(count_blocks "$tsize" "$TMP/table.log")
  case "$got" in unrecognised*) got=unrecognised ;; esac
  if [ "$got" != "$want" ]; then
    echo "FAIL trace-malloc-lines: size $tsize, line '$line': want $want, got $got"; table_bad=1
  fi
done < "$ROOT/tests/dynamic/trace-malloc-lines"
[ "$table_bad" -eq 0 ] || exit 1
echo "ok   trace-malloc-lines"

cp -R "$1" "$TMP/repo"
(cd "$ROOT" && bats upload --repository "$TMP/repo" >/dev/null)
# Keep only the archive just uploaded, so lock cannot pick a published
# version instead (an uncommitted checkout uploads as <version>dev1,
# which sorts below a release of the same commit).
PKG=$(sed -n 's/^name *= *"\(.*\)"/\1/p' "$ROOT/bats.toml" | head -1)
NEW=$(ls -t "$TMP/repo/$PKG"/*.bats | head -1)
for a in "$TMP/repo/$PKG"/*.bats; do
  [ "$a" = "$NEW" ] || rm -f "$a" "$a.sha256"
done

# A test that hangs must fail, not stall CI. `timeout` is GNU coreutils;
# where it is missing the binary runs without a limit.
LIMIT=""
if command -v timeout >/dev/null 2>&1; then LIMIT="timeout 300"; fi
if ! command -v valgrind >/dev/null 2>&1; then
  echo "error: valgrind is needed for the no-leaks tests" >&2; exit 1
fi

# The no-alloc-bytes check: the binary under valgrind with --trace-malloc=yes,
# and the blocks of exactly the size in $1 are counted (count_blocks). Uses $n
# and $w of the loop below. Returns 1 when a block of the size was made, 2
# when the program did not run or its log has an allocation line count_blocks
# does not know (a check that can miss a block must fail, not pass).
check_no_alloc () {
  size=$(cat "$1")
  (cd "$w" && $LIMIT valgrind -q --trace-malloc=yes "./dist/debug/$n") > "$TMP/$n.alloc.out" 2>&1 || return 2
  hits=$(count_blocks "$size" "$TMP/$n.alloc.out")
  case "$hits" in
    unrecognised*) echo "     $hits"; return 2 ;;
  esac
  echo "     $hits block(s) of $size bytes in $n (valgrind --trace-malloc)"
  [ "$hits" -eq 0 ] || return 1
}

# A negative control: the check must find a block of the size (status 1).
control_fails () {
  if check_no_alloc "$1"; then rc=0; else rc=$?; fi
  [ "$rc" -eq 1 ]
}

fail=0
for d in "$ROOT"/tests/dynamic/*/; do
  [ -f "$d/bats.toml" ] || continue
  n=$(basename "$d"); w="$TMP/w-$n"
  cp -R "$d" "$w"
  RUN=""
  [ -f "$d/no-leaks" ] && RUN="valgrind -q --leak-check=full --errors-for-leak-kinds=definite,indirect --error-exitcode=1"
  # --dev: the checkout uploads as a dev version, which bats lock skips
  # without it (as the Rust bats does).
  if (cd "$w" && bats lock --dev --repository "$TMP/repo" && bats build --only debug --only native --repository "$TMP/repo") > "$TMP/$n.log" 2>&1 \
     && (cd "$w" && $LIMIT $RUN "./dist/debug/$n") > "$TMP/$n.out" 2>&1 \
     && { [ ! -f "$d/no-alloc-bytes" ] || check_no_alloc "$d/no-alloc-bytes"; } \
     && { [ ! -f "$d/no-alloc-bytes-control" ] || control_fails "$d/no-alloc-bytes-control"; } \
     && { [ ! -f "$d/expected" ] || diff -u "$d/expected" "$TMP/$n.out"; }; then
    echo "ok   $n"
  else
    echo "FAIL $n"; grep -E 'error|FAIL|lost' "$TMP/$n.log" "$TMP/$n.out" 2>/dev/null | head -10; fail=1
  fi
done
exit $fail
