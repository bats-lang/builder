#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* into_arr's array is at most BUILDER_CAP bytes, not more *)
fn too_big {n:nat | n <= $B.BUILDER_CAP}
  (b: $B.builder(n)): [l:agz] $A.arr(byte, l, 524289) = let
  val @(arr, _) = $B.into_arr(b)
in arr end

implement main0 () = ()
