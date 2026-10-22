#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* The shape a consumer of a rope's chunks takes (bats's helpers.bats,
   fd_write_chunks): a chunk is an array of its own capacity, whose first n
   bytes are the text; it is frozen, split at n, and given back, whatever
   its capacity is. A chunk is not typed BUILDER_CAP, so this must type-check
   for any chunk the rope gives (#51). *)

fun drain {k:nat} .<k>. (cs: !$B.rope_sized_list(k)): int =
  case+ cs of
  | $B.rope_sized_nil() => 0
  | @$B.rope_sized_cons(a, n, tl) => let
      val @(fz, bv) = $A.freeze<byte>(a)
      val @(left, right) = $A.borrow_split<byte>(fz, bv, n)
      val () = $A.drop<byte>(fz, $A.borrow_join<byte>(fz, left, right))
      val () = a := $A.thaw<byte>(fz)
      val r = n + drain(tl)
      prval () = fold@(cs)
    in r end

implement main0 () = let
  val r = $B.rope_create()
  val () = $B.rope_bput(r, "hello")
  val cs = $B.rope_sized_chunks(r)
  val total = drain(cs)
  val () = $B.rope_sized_list_free(cs)
in println! ("drained ", total) end
