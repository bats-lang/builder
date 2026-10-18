#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* to_arr's array is BUILDER_CAP bytes, into_arr's is not: handing the latter
   to a consumer typed arr(byte, l, BUILDER_CAP) does not type-check *)
fn consume {l:agz} (a: $A.arr(byte, l, $B.BUILDER_CAP)): void = $A.free<byte>(a)

fn wrong_one {n:nat | n <= $B.BUILDER_CAP}
  (b: $B.builder(n)): void = let
  val @(arr, _) = $B.into_arr(b)
in consume(arr) end

implement main0 () = ()
