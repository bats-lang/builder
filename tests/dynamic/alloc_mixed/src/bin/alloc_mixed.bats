#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* Negative control for tests/dynamic/run.sh's no-alloc-bytes check (#55).
   `make` is called from one call site of `rounds`, first for 524288 bytes
   and then for 100: one allocation site whose total is 524388, the size
   plus other blocks. A check that counts only a site whose total equals
   the size misses it. This package has a no-alloc-bytes-control file
   (524288): run.sh must find the block of that size and so report the
   check as failed, and this test passes only then. Everything is freed
   (no-leaks). *)

fn make {n:pos | n <= 1048576} (n: int n): void = let
  val a = $A.alloc<byte>(n)
in $A.free<byte>(a) end

fun rounds {k:nat}{n:pos | n <= 1048576} .<k>. (k: int k, n: int n): void =
  if k <= 0 then () else let
    val () = make(n)
  in rounds(k - 1, 100) end

implement main0 () = let
  val () = rounds(2, 524288)
in println! ("rounds 2") end
