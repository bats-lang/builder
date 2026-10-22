#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* The old chunk form (#51), kept for one published version: rope_chunks
   gives chunks that are arrays of exactly BUILDER_CAP bytes, and a
   consumer that names that size (json's tests/dynamic/caps, rope_into and
   its copy) type-checks and reads the text. The chunk's text is copied
   into one array and printed; under valgrind every chunk must be freed.
   Remove with the ticket that removes the old form. *)

fun copy {lc,la:agz}{m:pos}{n:nat | n <= $B.BUILDER_CAP}{i:nat | i <= n} .<n - i>.
  (c: !$A.arr(byte, lc, $B.BUILDER_CAP), a: !$A.arr(byte, la, m), m: int m,
   off: int, i: int i, n: int n): bool =
  if i >= n then true
  else let
    val at = off + i
  in
    if at < m then let
      val () = $A.set<byte>(a, at, $A.get<byte>(c, i))
    in copy(c, a, m, off, i + 1, n) end
    else false
  end

fun into {k:nat}{la:agz}{m:pos} .<k>.
  (cs: !$B.rope_list(k), a: !$A.arr(byte, la, m), m: int m, off: int): bool =
  case+ cs of
  | $B.rope_nil() => true
  | $B.rope_cons(c, n, tl) =>
      if copy(c, a, m, off, 0, n) then into(tl, a, m, off + n) else false

fun show {la:agz}{m:pos}{j:nat | j <= m} .<m - j>.
  (a: !$A.arr(byte, la, m), m: int m, j: int j, n: int): void =
  if j >= n || j >= m then println! ()
  else let
    val () = print_char(int2char0(byte2int0($A.get<byte>(a, j))))
  in show(a, m, j + 1, n) end

implement main0 () = let
  val r = $B.rope_create()
  val () = $B.rope_bput(r, "hello old chunks")
  val cs = $B.rope_chunks(r)
  val a = $A.alloc<byte>(64)
  val ok = into(cs, a, 64, 0)
  val () = println! ("copied ", ok)
  val () = show(a, 64, 0, 16)
  val () = $A.free<byte>(a)
  val () = $B.rope_list_free(cs)
in end
