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
  val p = g1ofg0(pos)
in
  if p >= 0 then
    if p < 524288 then let
      val () = $A.set<byte>(buf, p, $A.int2byte($AR.checked_byte(v)))
      val () = pos := g0ofg1(p + 1)
      prval () = fold@(b)
    in end
    else let
      val () = println! ("FATAL: builder overflow at ", p, " bytes (capacity 524288)")
      prval () = fold@(b)
      val () = assertloc(false)
    in end
  else let prval () = fold@(b) in end
end

implement put_bytes{lb}{n}(b, src, len) = let
  val+ @builder_mk(buf, pos) = b
  val p0 = pos
  fun loop {i:nat | i <= n}{lb2:agz}{lb:agz} .<n - i>.
    (buf: !$A.arr(byte, lb2, BUILDER_CAP),
     src: !$A.borrow(byte, lb, n),
     i: int i, len: int n, base: int): void =
    if i >= len then ()
    else let
      val off = g1ofg0(base + i)
    in
      if off >= 0 then
        if off < 524288 then let
          val byte_val = $A.read<byte>(src, i)
          val () = $A.set<byte>(buf, off, byte_val)
        in loop(buf, src, i + 1, len, base) end
      else ()
    end
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
