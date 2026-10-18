#include "share/atspre_staload.hats"
#use arith as AR
#use array as A
#use builder as B

(* A builder (#43) starts with a 64 byte array and doubles it when a byte
   does not fit. Here it is written with the letters of a fixed pattern,
   byte i being 'a' + i mod 26, through put_byte, put_char, put_int and
   bput, past 64, 4096 and BUILDER_CAP, and read back through into_arr
   (its own array) and to_arr (a BUILDER_CAP copy): the bytes written
   before each growth are still there. Each builder is freed; it runs
   under valgrind. *)

fun fill {i,m:nat | i <= m; m <= 524288} .<m - i>.
  (b: !$B.builder(i) >> $B.builder(m), i: int i, m: int m): void =
  if i >= m then ()
  else let
    val () = $B.put_byte(b, $AR.low_byte(97 + i mod 26))
  in fill(b, i + 1, m) end

(* Prints the bytes [i, k) of arr, then a newline *)
fun show {l:agz}{cap:nat}{i,k:nat | i <= k; k <= cap} .<k - i>.
  (arr: !$A.arr(byte, l, cap), i: int i, k: int k): void =
  if i >= k then print_newline()
  else let
    val () = print_char(int2char0(byte2int0($A.get<byte>(arr, i))))
  in show(arr, i + 1, k) end

(* The number of places in [i, k) whose byte is not 'a' + place mod 26 *)
fun wrong {l:agz}{cap:nat}{i,k:nat | i <= k; k <= cap} .<k - i>.
  (arr: !$A.arr(byte, l, cap), i: int i, k: int k, acc: int): int =
  if i >= k then acc
  else if byte2int0($A.get<byte>(arr, i)) = 97 + i mod 26 then wrong(arr, i + 1, k, acc)
  else wrong(arr, i + 1, k, acc + 1)

implement main0 () = let
  (* nothing written: freed, and taken as an array *)
  val e = $B.create()
  val () = $B.builder_free(e)
  val e2 = $B.create()
  val @(earr, ek) = $B.into_arr(e2)
  val () = println! (ek)
  val () = $A.free<byte>(earr)

  (* 1000 bytes: 64, 128, ..., 1024 *)
  val b = $B.create()
  val () = fill(b, 0, 1000)
  val () = println! ($B.length(b))
  val @(arr, k) = $B.into_arr(b)
  val () = println! (k, " ", wrong(arr, 0, k, 0))
  val () = show(arr, 0, 30)
  val () = show(arr, 997, 1000)
  val () = $A.free<byte>(arr)

  (* the same, as a BUILDER_CAP array *)
  val b2 = $B.create()
  val () = fill(b2, 0, 5000)
  val @(arr2, k2) = $B.to_arr(b2)
  val () = println! (k2, " ", wrong(arr2, 0, k2, 0))
  val () = show(arr2, 4997, 5000)
  val () = $A.free<byte>(arr2)

  (* put_int, bput and put_newline across the growth from 64 to 128 *)
  val c = $B.create()
  val () = fill(c, 0, 60)
  val () = $B.put_int(c, ~2147483648)
  val () = $B.bput(c, "xyz")
  val () = $B.put_newline(c)
  val @(carr, ck) = $B.into_arr(c)
  val () = println! (ck)
  val () = show(carr, 56, ck)
  val () = $A.free<byte>(carr)

  (* the whole of BUILDER_CAP *)
  val big = $B.create()
  val () = fill(big, 0, 524288)
  val @(barr, bk) = $B.to_arr(big)
  val () = println! (bk, " ", wrong(barr, 0, bk, 0))
  val () = show(barr, 524285, 524288)
  val () = $A.free<byte>(barr)

  (* rope_append takes a builder's own array (into_arr), no copy *)
  val r = $B.rope_create()
  val () = $B.rope_bput(r, "hello ")
  val d = $B.create()
  val () = $B.bput(d, "world")
  val () = $B.rope_append(r, d)
  val cs = $B.rope_chunks(r)
  val () = $B.rope_list_free(cs)
in end
