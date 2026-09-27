#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* 1200000 bytes into a rope, byte i being i mod 251, then "end": more
   than two builders' worth, so the text spans three chunks. Their
   lengths add up to 1200003 and every byte, across the chunk boundaries,
   is in place. *)

fun fill {i:nat | i <= 1200000} .<1200000 - i>. (r: !$B.rope, i: int i): void =
  if i >= 1200000 then ()
  else let
    val () = $B.rope_put(r, nmod(i, 251))
  in fill(r, i + 1) end

(* The byte at position p: the pattern, then "end" *)
fn want (p: int): int =
  if p < 1200000 then p mod 251
  else if p = 1200000 then 101 else if p = 1200001 then 110 else 100

(* Checks chunk bytes [0, n) against positions from p; the next position,
   or ~1 at the first byte out of place *)
fun check {l:agz}{n:nat | n <= $B.BUILDER_CAP}{j:nat | j <= n} .<n - j>.
  (a: !$A.arr(byte, l, $B.BUILDER_CAP), n: int n, j: int j, p: int): int =
  if j >= n then p
  else if byte2int0($A.get<byte>(a, j)) <> want(p) then ~1
  else check(a, n, j + 1, p + 1)

(* The chunks' total length, or ~1; frees them *)
fun walk {k:nat} .<k>. (cs: $B.rope_list(k), p: int, count: int): @(int, int) =
  case+ cs of
  | ~$B.rope_nil() => @(p, count)
  | ~$B.rope_cons(a, n, tl) => let
      val q = (if p < 0 then ~1 else check(a, n, 0, p)): int
      val () = $A.free<byte>(a)
    in walk(tl, q, count + 1) end

implement main0 () = let
  val r = $B.rope_create()
  val () = fill(r, 0)
  val () = $B.rope_bput(r, "end")
  val @(total, chunks) = walk($B.rope_chunks(r), 0, 0)
in
  println! ("total ", total, " chunks ", chunks)
end
