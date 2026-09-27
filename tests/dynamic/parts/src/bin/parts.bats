#include "share/atspre_staload.hats"
#use array as A
#use builder as B
#use str as S

(* Builds "ab\n", frees one builder whole, appends a builder and a copied
   slice to a rope ("xyz" then "bcd" out of "abcde") and frees its chunks
   with rope_list_free. It runs under valgrind: every builder and chunk
   must be freed. Exits 1 on a wrong length. *)
fun total {k:nat} .<k>. (cs: !$B.rope_list(k), acc: int): int =
  case+ cs of
  | $B.rope_nil() => acc
  | $B.rope_cons(_, n, tl) => total(tl, acc + n)

implement main0 () = let
  val b = $B.create()
  val () = $B.put_byte(b, 97)
  val () = $B.put_char(b, 98)
  val () = $B.put_newline(b)
  val l1 = $B.length(b)
  val () = $B.builder_free(b)
  val r = $B.rope_create()
  val b2 = $B.create()
  val () = $B.bput(b2, "xyz")
  val () = $B.rope_append(r, b2)
  var src = @[char][5]('a', 'b', 'c', 'd', 'e')
  val @(f, s) = $A.freeze<byte>($S.from_char_array(src, 5))
  val () = $B.rope_copy(r, s, 1, 4)
  val () = $A.drop<byte>(f, s)
  val () = $A.free<byte>($A.thaw<byte>(f))
  val cs = $B.rope_chunks(r)
  val l2 = total(cs, 0)
  val () = $B.rope_list_free(cs)
  val ok = l1 = 3 && l2 = 6
  val () = (if ok then () else println! ("FAIL: ", l1, " ", l2))
in if ok then () else exit(1) end
