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

# The no-alloc-bytes check: the binary under valgrind with --trace-malloc=yes
# (valgrind --help-debug: "debugging options for Valgrind tools that replace
# malloc"), which logs "malloc(N)", "calloc(N,M)", "realloc(P,N)" and the
# memalign family, one line for each block. The blocks of exactly the size in
# $1 are counted. Uses $n and $w of the loop below. Returns 1 when a block of
# the size was made, 2 when the program did not run.
check_no_alloc () {
  size=$(cat "$1")
  (cd "$w" && $LIMIT valgrind -q --trace-malloc=yes "./dist/debug/$n") > "$TMP/$n.alloc.out" 2>&1 || return 2
  hits=$(awk -v size="$size" '
    /^--[0-9]+-- [a-z_]+\(/ {
      call = $0; sub(/^--[0-9]+-- /, "", call)
      name = call; sub(/\(.*/, "", name)
      args = call; sub(/^[^(]*\(/, "", args); sub(/\).*/, "", args)
      if (name == "malloc" || name == "valloc") bytes = args
      else if (name == "calloc") { split(args, a, ","); bytes = a[1] * a[2] }
      else if (name == "realloc") { split(args, a, ","); bytes = a[2] }
      else if (name ~ /align/) { bytes = args; sub(/.*size /, "", bytes) }
      else next
      if (bytes + 0 == size + 0) hits++
    }
    END { print hits + 0 }' "$TMP/$n.alloc.out")
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
