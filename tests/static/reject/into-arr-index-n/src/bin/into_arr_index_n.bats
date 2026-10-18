#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* into_arr's array holds at least n bytes, not n + 1: index n is not in it *)
fn past_end {n:nat | n <= $B.BUILDER_CAP}
  (b: $B.builder(n)): void = let
  val @(arr, k) = $B.into_arr(b)
  val c = $A.get<byte>(arr, k)
  val () = $A.free<byte>(arr)
in end

implement main0 () = ()
