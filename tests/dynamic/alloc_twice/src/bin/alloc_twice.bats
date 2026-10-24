#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* Negative control for tests/dynamic/run.sh's no-alloc-bytes check (#55).
   The old form of the rope makes a 524288 byte (BUILDER_CAP) chunk, and
   `once` is called twice from one call site, so both chunks come from one
   allocation site: a site whose total is 2 * 524288, not 524288. A check
   that counts only a site whose total equals the size misses it. This
   package has a no-alloc-bytes-control file (524288): run.sh must find the
   blocks of that size and so report the check as failed, and this test
   passes only then. Everything is freed (no-leaks). *)

fun once (): void = let
  val r = $B.rope_create()
  val () = $B.rope_bput(r, "hello")
  val cs = $B.rope_chunks(r)
in $B.rope_list_free(cs) end

fun rounds {k:nat} .<k>. (k: int k): void =
  if k <= 0 then () else let
    val () = once()
  in rounds(k - 1) end

implement main0 () = let
  val () = rounds(2)
in println! ("rounds 2") end
