(* builder -- append-only byte string builder *)
(* Fixed-capacity buffer (512KB). No $UNSAFE. *)

#include "share/atspre_staload.hats"

#use array as A
#use arith as AR

(* ============================================================
   Constants
   ============================================================ *)

#pub stadef BUILDER_CAP = 524288

(* ============================================================
   Types
   ============================================================ *)

#pub datavtype builder =
  | {lb:agz}
    builder_mk of ($A.arr(byte, lb, BUILDER_CAP), int)

(* ============================================================
   API
   ============================================================ *)

#pub fun create
  (): builder

#pub fun put_byte
  (b: !builder, v: int): void

#pub fun put_bytes
  {lb:agz}{n:nat}
  (b: !builder, src: !$A.borrow(byte, lb, n), len: int n): void

#pub fun put_int
  (b: !builder, n: int): void

#pub fun put_newline
  (b: !builder): void

#pub fun put_char
  (b: !builder, v: int): void

#pub fun length
  (b: !builder): int

#pub fn to_arr
  (b: builder): @([l:agz] $A.arr(byte, l, 524288), int)

#pub fun builder_free
  (b: builder): void

(* ============================================================
   Implementations
   ============================================================ *)

implement create() = let
  val buf = $A.alloc<byte>(524288)
in builder_mk(buf, 0) end

implement put_byte(b, v) = let
  val+ @builder_mk(buf, pos) = b
  val p = $AR.checked_idx(pos, 524288)
  val () = $A.set<byte>(buf, p, $A.int2byte($AR.checked_byte(v)))
  val () = pos := pos + 1
  prval () = fold@(b)
in end

implement put_bytes{lb}{n}(b, src, len) = let
  val+ @builder_mk(buf, pos) = b
  val p0 = pos
  fun loop {i:nat | i <= n}{lb2:agz}{lb:agz} .<n - i>.
    (buf: !$A.arr(byte, lb2, BUILDER_CAP),
     src: !$A.borrow(byte, lb, n),
     i: int i, len: int n, base: int): void =
    if i >= len then ()
    else let
      val byte_val = $A.read<byte>(src, i)
      val () = $A.set<byte>(buf, $AR.checked_idx(base + i, 524288), byte_val)
    in loop(buf, src, i + 1, len, base) end
  val () = loop(buf, src, 0, len, p0)
  val new_pos = p0 + g0ofg1(len)
  val () = pos := new_pos
  prval () = fold@(b)
in end

implement put_int(b, n) = let
  fun _put_digits {fuel:nat} .<fuel>.
    (b: !builder, n: int, fuel: int fuel): void =
    if fuel <= 0 then ()
    else if n < 10 then
      put_byte(b, n + 48)
    else let
      val () = _put_digits(b, n / 10, fuel - 1)
      val () = put_byte(b, (n mod 10) + 48)
    in end
in
  if n < 0 then let
    val () = put_byte(b, 45)
    val abs_n = ~n
  in
    if abs_n < 0 then
      (* INT_MIN edge case -- just write 0 *)
      put_byte(b, 48)
    else
      _put_digits(b, abs_n, 20)
  end
  else if n = 0 then
    put_byte(b, 48)
  else
    _put_digits(b, n, 20)
end

implement put_newline(b) =
  put_byte(b, 10)

implement put_char(b, v) =
  put_byte(b, v)

implement length(b) = let
  val+ @builder_mk(_, pos) = b
  val p = pos
  prval () = fold@(b)
in p end

implement to_arr(b) = let
  val+ ~builder_mk(buf, pos) = b
in @(buf, pos) end

implement builder_free(b) = let
  val+ ~builder_mk(buf, _) = b
in $A.free<byte>(buf) end

(* ============================================================
   String writing
   ============================================================ *)

#pub fun bput_loop {sn:nat}{i:nat | i <= sn}{fuel:nat}
  (b: !builder, s: string sn, slen: int sn, i: int i, fuel: int fuel): void

implement bput_loop(b, s, slen, i, fuel) =
  if fuel <= 0 then ()
  else if i >= slen then ()
  else let
    val c = char2int0(string_get_at(s, i))
    val () = put_byte(b, c)
  in bput_loop(b, s, slen, i + 1, fuel - 1) end

#pub fn bput {sn:nat} (b: !builder, s: string sn): void

implement bput(b, s) = let
  val slen_sz = string1_length(s)
  val slen = g1u2i(slen_sz)
in bput_loop(b, s, slen, 0, $AR.checked_nat(slen + 1)) end

#pub fn bput_int(b: !builder, v: int): void

implement bput_int(b, v) = let
  val digits = $A.alloc<byte>(16)
  fun fill {ld:agz}{fuel:nat} .<fuel>.
    (digits: !$A.arr(byte, ld, 16), v: int, pos: int, fuel: int fuel): int =
    if fuel <= 0 then pos
    else if v < 10 then let
      val () = $A.set<byte>(digits, $AR.checked_idx(pos, 16), int2byte0(48 + v))
    in pos + 1 end
    else let
      val () = $A.set<byte>(digits, $AR.checked_idx(pos, 16), int2byte0(48 + $AR.mod_int_int(v, 10)))
    in fill(digits, $AR.div_int_int(v, 10), pos + 1, fuel - 1) end
  val is_neg = v < 0
  val abs_v = (if is_neg then 0 - v else v): int
  val ndigits = fill(digits, abs_v, 0, 15)
  val () = (if is_neg then put_byte(b, 45) else ())
  fun emit {ld:agz}{fuel:nat} .<fuel>.
    (digits: !$A.arr(byte, ld, 16), b: !builder, pos: int, fuel: int fuel): void =
    if fuel <= 0 then ()
    else if pos < 0 then ()
    else let
      val () = put_byte(b, byte2int0($A.get<byte>(digits, $AR.checked_idx(pos, 16))))
    in emit(digits, b, pos - 1, fuel - 1) end
  val () = emit(digits, b, ndigits - 1, 16)
  val () = $A.free<byte>(digits)
in end

(* ============================================================
   Static tests
   ============================================================ *)

fn _test_create_free(): void = let
  val b = create()
  val () = builder_free(b)
in end

fn _test_put_byte(): void = let
  val b = create()
  val () = put_byte(b, 65)
  val () = put_byte(b, 66)
  val l = length(b)
  val @(arr, _) = to_arr(b)
  val () = $A.free<byte>(arr)
in end

fn _test_put_int(): void = let
  val b = create()
  val () = put_int(b, 42)
  val () = put_int(b, 0)
  val () = put_int(b, ~1)
  val @(arr, _) = to_arr(b)
  val () = $A.free<byte>(arr)
in end

fn _test_put_newline(): void = let
  val b = create()
  val () = put_newline(b)
  val @(arr, _) = to_arr(b)
  val () = $A.free<byte>(arr)
in end
