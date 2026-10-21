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
# holding a size, it runs under valgrind's DHAT, and no allocation site may
# allocate that total: a small rope must not make a BUILDER_CAP array
# (builder#51). DHAT's sites carry their total bytes as "tb".
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

# The no-alloc-bytes check: the binary under DHAT, and the program points
# whose total is the size in $1 are counted; any is a failure. Uses $n and
# $w of the loop below.
check_no_alloc () {
  size=$(cat "$1")
  (cd "$w" && $LIMIT valgrind -q --tool=dhat --dhat-out-file="$TMP/$n.dhat" "./dist/debug/$n") > "$TMP/$n.dhat.out" 2>&1 || return 1
  hits=$(grep -c "\"tb\":$size[^0-9]" "$TMP/$n.dhat" || true)
  echo "     $hits allocation site(s) of $size bytes in $n (DHAT)"
  [ "$hits" -eq 0 ]
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
     && { [ ! -f "$d/expected" ] || diff -u "$d/expected" "$TMP/$n.out"; }; then
    echo "ok   $n"
  else
    echo "FAIL $n"; grep -E 'error|FAIL|lost' "$TMP/$n.log" "$TMP/$n.out" 2>/dev/null | head -10; fail=1
  fi
done
exit $fail
