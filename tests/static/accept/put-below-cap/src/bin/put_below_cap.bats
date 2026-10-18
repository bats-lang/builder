#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* put_byte below BUILDER_CAP, and the byte past the length of what into_arr
   gives (the array has at least n bytes, so index n - 1 is in it) *)
fn last_of {n:pos | n < $B.BUILDER_CAP}
  (b: $B.builder(n)): int = let
  val @(arr, k) = $B.into_arr(b)
  val c = byte2int0($A.get<byte>(arr, k - 1))
  val () = $A.free<byte>(arr)
in c end

fn put_one {n:nat | n < $B.BUILDER_CAP}
  (b: !$B.builder(n) >> $B.builder(n+1)): void = $B.put_byte(b, 65)

implement main0 () = let
  val b = $B.create()
  val () = put_one(b)
  val c = last_of(b)
in println! (c) end
