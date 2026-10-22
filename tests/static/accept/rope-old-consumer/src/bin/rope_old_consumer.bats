#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* The old chunk form (#51) is kept for one published version: a consumer
   that takes a chunk as an array of exactly BUILDER_CAP bytes (json's
   tests/dynamic/caps, rope_into and its copy) type-checks against
   rope_chunks unchanged. *)

fn needs_full {l:agz} (a: !$A.arr(byte, l, $B.BUILDER_CAP)): void = ()

fun each_full {k:nat} .<k>. (cs: !$B.rope_list(k)): void =
  case+ cs of
  | $B.rope_nil() => ()
  | @$B.rope_cons(a, _, tl) => let
      val () = needs_full(a)
      val () = each_full(tl)
      prval () = fold@(cs)
    in end

implement main0 () = let
  val r = $B.rope_create()
  val cs = $B.rope_chunks(r)
  val () = each_full(cs)
  val () = $B.rope_list_free(cs)
in end
