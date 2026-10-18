#include "share/atspre_staload.hats"
#use arith as AR
#use array as A
#use builder as B

(* A growing builder (#43) is written with the letters of a fixed pattern:
   byte i is 'a' + i mod 26. Its capacity starts at the caller's and doubles,
   so 1000 bytes from 2 end in an array of 1024; 524288 bytes from 1 fill
   BUILDER_CAP exactly. Each builder is freed; it runs under valgrind. *)

fun fill {i,m:nat | i <= m; m <= 524288}{cap:nat | i <= cap; cap <= 524288} .<m - i>.
  (b: $B.sbuilder(i, cap), i: int i, m: int m): [new_cap:nat | m <= new_cap; new_cap <= 524288] $B.sbuilder(m, new_cap) =
  if i >= m then b
  else let
    val b2 = $B.sput_byte(b, $AR.low_byte(97 + i mod 26))
  in fill(b2, i + 1, m) end

(* Prints the bytes [i, k) of arr, then a newline *)
fun show {l:agz}{cap:nat}{i,k:nat | i <= k; k <= cap} .<k - i>.
  (arr: !$A.arr(byte, l, cap), i: int i, k: int k): void =
  if i >= k then print_newline()
  else let
    val () = print_char(int2char0(byte2int0($A.get<byte>(arr, i))))
  in show(arr, i + 1, k) end

implement main0 () = let
  val e = $B.screate(3)
  val () = $B.sbuilder_free(e)
  val b = fill($B.screate(2), 0, 1000)
  val cap = $B.scapacity(b)
  val @(arr, k) = $B.sto_arr(b)
  val () = println! (k, " ", cap)
  val () = show(arr, 0, 30)
  val () = show(arr, 997, 1000)
  val () = $A.free<byte>(arr)
  val big = fill($B.screate(1), 0, 524288)
  val big_cap = $B.scapacity(big)
  val @(barr, bk) = $B.sto_arr(big)
  val () = println! (bk, " ", big_cap)
  val () = show(barr, 524285, 524288)
  val () = $A.free<byte>(barr)
in end
