#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* The published rope (#51): its Rope constructor carries rope_list, the
   chunks being BUILDER_CAP arrays, and a dependent matches it (bats's
   helpers.bats, rope_text: ~$B.Rope(cs, b), cs reversed as a rope_list).
   This must type-check unchanged; the sized rope is a type of its own. *)

fun count {a:nat} .<a>. (cs: $B.rope_list(a), acc: int): int =
  case+ cs of
  | ~$B.rope_nil() => acc
  | ~$B.rope_cons(x, n, tl) => let
      val () = $A.free<byte>(x)
    in count(tl, acc + n) end

fn text_length(r: $B.rope): int =
  case+ r of
  | ~$B.Rope(cs, b) => let
      val @(last, last_len) = $B.into_arr(b)
      val () = $A.free<byte>(last)
    in count(cs, last_len) end

implement main0 () = let
  val r = $B.rope_create()
  val () = $B.rope_bput(r, "hello")
in println! ("length ", text_length(r)) end
