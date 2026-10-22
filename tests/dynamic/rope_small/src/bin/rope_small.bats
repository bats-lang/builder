#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* A rope holding a few bytes is one chunk of those bytes: its chunk is
   the builder's own array, not a BUILDER_CAP (524288 byte) copy, so a
   rope of five bytes or of none allocates what its text needs (#51).
   The chunks are counted and their lengths added up, then freed; under
   valgrind every chunk must be freed. The allocations are counted by
   tests/dynamic/run.sh from this package's no-alloc-bytes file (524288):
   under DHAT no allocation site of that size may remain. The types bound a
   chunk's capacity (the static rejects in tests/static say so). *)

fun chunk_count {k:nat} .<k>. (cs: !$B.rope_sized_list(k), acc: int): int =
  case+ cs of
  | $B.rope_sized_nil() => acc
  | $B.rope_sized_cons(_, _, tl) => chunk_count(tl, acc + 1)

fun text_total {k:nat} .<k>. (cs: !$B.rope_sized_list(k), acc: int): int =
  case+ cs of
  | $B.rope_sized_nil() => acc
  | $B.rope_sized_cons(_, n, tl) => text_total(tl, acc + n)

implement main0 () = let
  val r = $B.sized_rope_create()
  val () = $B.sized_rope_bput(r, "hello")
  val cs = $B.sized_rope_chunks(r)
  val () = println! ("chunks ", chunk_count(cs, 0), " total ", text_total(cs, 0))
  val () = $B.rope_sized_list_free(cs)
  val e = $B.sized_rope_create()
  val ce = $B.sized_rope_chunks(e)
  val () = println! ("chunks ", chunk_count(ce, 0), " total ", text_total(ce, 0))
  val () = $B.rope_sized_list_free(ce)
in end
