#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* A chunk of a rope is not BUILDER_CAP bytes: its array has the capacity
   of the builder it came from, so a function that takes a BUILDER_CAP
   array of a chunk is refused (#51). This is the old form of the chunks. *)

fn needs_full {l:agz} (a: !$A.arr(byte, l, $B.BUILDER_CAP)): void = ()

fun first_chunk_full {k:nat} .<k>. (cs: !$B.rope_list(k)): void =
  case+ cs of
  | $B.rope_nil() => ()
  | @$B.rope_cons(a, _, tl) => let
      val () = needs_full(a)
      prval () = fold@(cs)
    in end

implement main0 () = ()
