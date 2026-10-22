#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* A chunk holds no more bytes than its array has: a chunk of 100 bytes in
   a 64 byte array is refused by rope_sized_cons's n <= cap (#51). *)

fn chunk_over_cap (): $B.rope_sized_list(1) = let
  val arr = $A.alloc<byte>(64)
in $B.rope_sized_cons(arr, 100, $B.rope_sized_nil()) end

implement main0 () = ()
