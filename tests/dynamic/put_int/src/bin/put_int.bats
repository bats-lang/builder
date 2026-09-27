#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* put_int writes each value's decimal digits, with a '-' when negative,
   including the minimum and maximum int and values with ten digits; bput
   appends a string. Each line is compared with the expected file. *)

(* Prints the first k bytes of arr *)
fun show {l:agz}{i,k:nat | i <= k; k <= $B.BUILDER_CAP} .<k - i>.
  (arr: !$A.arr(byte, l, $B.BUILDER_CAP), i: int i, k: int k): void =
  if i >= k then print_newline()
  else let
    val () = print_char(int2char0(byte2int0($A.get<byte>(arr, i))))
  in show(arr, i + 1, k) end

fn one {v:int} (v: int v): void = let
  val b = $B.create()
  val () = $B.put_int(b, v)
  val @(arr, k) = $B.to_arr(b)
  val () = show(arr, 0, k)
in $A.free<byte>(arr) end

implement main0 () = let
  val () = one(0)
  val () = one(7)
  val () = one(10)
  val () = one(42)
  val () = one(~1)
  val () = one(~9)
  val () = one(~10)
  val () = one(~120)
  val () = one(999999999)
  val () = one(1000000000)
  val () = one(~1000000000)
  val () = one(2147483647)
  val () = one(~2147483647)
  val () = one(~2147483647 - 1)
  val b = $B.create()
  val () = $B.bput(b, "hi ")
  val () = $B.put_int(b, ~305)
  val () = $B.put_char(b, 33)
  val @(arr, k) = $B.to_arr(b)
  val () = show(arr, 0, k)
in $A.free<byte>(arr) end
