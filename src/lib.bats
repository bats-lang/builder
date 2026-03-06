(* builder -- append-only byte string builder *)
(* Fixed-capacity buffer (512KB). Indexed type tracks position. *)
(* No runtime bounds checks -- callers prove safety via constraints. *)

#include "share/atspre_staload.hats"

#use array as A
#use arith as AR

(* ============================================================
   Constants
   ============================================================ *)

#pub stadef BUILDER_CAP = 524288

macdef _BUILDER_CAP = 524288

(* ============================================================
   Types
   ============================================================ *)

#pub datavtype builder(int) =
  | {lb:agz}{n:nat | n <= BUILDER_CAP}
    Builder(n) of ($A.arr(byte, lb, BUILDER_CAP), int(n))

#pub vtypedef builder_v = [n:nat | n <= BUILDER_CAP] builder(n)

(* ============================================================
   API
   ============================================================ *)

#pub fun create
  (): builder(0)

#pub fn to_arr
  (b: builder_v): @([l:agz] $A.arr(byte, l, BUILDER_CAP), int)

#pub fun builder_free
  (b: builder_v): void

#pub fun length {n:nat | n <= BUILDER_CAP}
  (b: !builder(n)): int(n)

#pub fun put_byte {n:nat | n < BUILDER_CAP}
  (b: !builder(n) >> builder(n+1), v: int): void

#pub fun put_int
  (b: !builder_v >> builder_v, n: int): void

#pub fun put_newline
  (b: !builder_v >> builder_v): void

#pub fun put_char
  (b: !builder_v >> builder_v, v: int): void

#pub fun bput_loop {sn:nat}{i:nat | i <= sn}{fuel:nat}
  (b: !builder_v >> builder_v, s: string sn, slen: int sn, i: int i, fuel: int fuel): void

#pub fn bput {sn:nat} (b: !builder_v >> builder_v, s: string sn): void

#pub fn bput_int(b: !builder_v >> builder_v, v: int): void

(* ============================================================
   Implementations
   ============================================================ *)

implement create() = let
  val buf = $A.alloc<byte>(_BUILDER_CAP)
in Builder(buf, 0) end

implement length(b) = let
  val+ @Builder(_, pos) = b
  val p = pos
  prval () = fold@(b)
in p end

implement to_arr(b) = let
  val+ ~Builder(buf, pos) = b
in @(buf, pos) end

implement builder_free(b) = let
  val+ ~Builder(buf, _) = b
in $A.free<byte>(buf) end

implement put_byte(b, v) = let
  val+ @Builder(buf, pos) = b
  val () = $A.set<byte>(buf, pos, int2byte0(v))
  val () = pos := pos + 1
  prval () = fold@(b)
in end

implement put_int(b, n) = let
  fun _put_digits {fuel:nat} .<fuel>.
    (b: !builder_v >> builder_v, n: int, fuel: int fuel): void =
    if fuel <= 0 then ()
    else if n < 10 then let
      val+ @Builder(_, pos) = b
      val p = pos
      prval () = fold@(b)
    in if p < _BUILDER_CAP then put_byte(b, n + char2int0('0')) else () end
    else let
      val () = _put_digits(b, n / 10, fuel - 1)
      val+ @Builder(_, pos) = b
      val p = pos
      prval () = fold@(b)
    in if p < _BUILDER_CAP then put_byte(b, (n mod 10) + char2int0('0')) else () end
in
  if n < 0 then let
    val+ @Builder(_, pos) = b
    val p = pos
    prval () = fold@(b)
    val () = (if p < _BUILDER_CAP then put_byte(b, char2int0('-')) else ())
    val abs_n = ~n
  in
    if abs_n < 0 then let
      val+ @Builder(_, pos2) = b
      val p2 = pos2
      prval () = fold@(b)
    in if p2 < _BUILDER_CAP then put_byte(b, char2int0('0')) else () end
    else
      _put_digits(b, abs_n, 20)
  end
  else if n = 0 then let
    val+ @Builder(_, pos) = b
    val p = pos
    prval () = fold@(b)
  in if p < _BUILDER_CAP then put_byte(b, char2int0('0')) else () end
  else
    _put_digits(b, n, 20)
end

implement put_newline(b) = let
  val+ @Builder(_, pos) = b
  val p = pos
  prval () = fold@(b)
in if p < _BUILDER_CAP then put_byte(b, char2int0('\n')) else () end

implement put_char(b, v) = let
  val+ @Builder(_, pos) = b
  val p = pos
  prval () = fold@(b)
in if p < _BUILDER_CAP then put_byte(b, v) else () end

(* ============================================================
   String writing
   ============================================================ *)

implement bput_loop(b, s, slen, i, fuel) =
  if fuel <= 0 then ()
  else if i >= slen then ()
  else let
    val+ @Builder(_, pos) = b
    val p = pos
    prval () = fold@(b)
  in
    if p < _BUILDER_CAP then let
      val c = char2int0(string_get_at(s, i))
      val () = put_byte(b, c)
    in bput_loop(b, s, slen, i + 1, fuel - 1) end
    else ()
  end

implement bput(b, s) = let
  val slen_sz = string1_length(s)
  val slen = g1u2i(slen_sz)
in bput_loop(b, s, slen, 0, slen) end

implement bput_int(b, v) = let
  val digits = $A.alloc<byte>(16)
  fun fill {ld:agz}{pos:nat}{fuel:nat | pos + fuel <= 15} .<fuel>.
    (digits: !$A.arr(byte, ld, 16), v: int, pos: int pos, fuel: int fuel): [r:nat | r <= 16] int r =
    if fuel <= 0 then pos
    else if v < 10 then let
      val () = $A.set<byte>(digits, pos, int2byte0(char2int0('0') + v))
    in pos + 1 end
    else let
      val () = $A.set<byte>(digits, pos, int2byte0(char2int0('0') + $AR.mod_int_int(v, 10)))
    in fill(digits, $AR.div_int_int(v, 10), pos + 1, fuel - 1) end
  val is_neg = v < 0
  val abs_v = (if is_neg then 0 - v else v): int
  val ndigits = fill(digits, abs_v, 0, 15)
  val () = (if is_neg then let
    val+ @Builder(_, pos) = b
    val p = pos
    prval () = fold@(b)
  in if p < _BUILDER_CAP then put_byte(b, char2int0('-')) else () end
  else ())
  fun emit {ld:agz}{pos:int | pos < 16}{fuel:nat} .<fuel>.
    (digits: !$A.arr(byte, ld, 16), b: !builder_v >> builder_v, pos: int pos, fuel: int fuel): void =
    if fuel <= 0 then ()
    else if pos < 0 then ()
    else let
      val+ @Builder(_, bpos) = b
      val bp = bpos
      prval () = fold@(b)
    in
      if bp < _BUILDER_CAP then let
        val () = put_byte(b, byte2int0($A.get<byte>(digits, pos)))
      in emit(digits, b, pos - 1, fuel - 1) end
      else ()
    end
  val () = emit(digits, b, ndigits - 1, 16)
  val () = $A.free<byte>(digits)
in end

(* ============================================================
   Static tests
   ============================================================ *)

fn _check_byte {l:agz}{idx:nat | idx < BUILDER_CAP}
  (arr: !$A.arr(byte, l, BUILDER_CAP), idx: int idx, expected: int): bool =
  $AR.eq_int_int(byte2int0($A.get<byte>(arr, idx)), expected)

fn _test_create_free(): bool = let
  val b = create()
  val () = builder_free(b)
in true end

fn _test_put_byte(): bool = let
  val b = create()
  val () = put_byte(b, char2int0('A'))
  val () = put_byte(b, char2int0('B'))
  val l = length(b)
  val @(arr, len) = to_arr(b)
  val c0 = _check_byte(arr, 0, char2int0('A'))
  val c1 = _check_byte(arr, 1, char2int0('B'))
  val ok = l = 2 && len = 2 && c0 && c1
  val () = $A.free<byte>(arr)
in ok end

fn _test_put_int(): bool = let
  val b = create()
  val () = put_int(b, 42)
  val l1 = length(b)
  val @(arr, _) = to_arr(b)
  val c0 = _check_byte(arr, 0, char2int0('4'))
  val c1 = _check_byte(arr, 1, char2int0('2'))
  val ok = l1 = 2 && c0 && c1
  val () = $A.free<byte>(arr)
in ok end

fn _test_put_int_zero(): bool = let
  val b = create()
  val () = put_int(b, 0)
  val @(arr, len) = to_arr(b)
  val c0 = _check_byte(arr, 0, char2int0('0'))
  val ok = len = 1 && c0
  val () = $A.free<byte>(arr)
in ok end

fn _test_put_int_negative(): bool = let
  val b = create()
  val () = put_int(b, ~1)
  val @(arr, len) = to_arr(b)
  val c0 = _check_byte(arr, 0, char2int0('-'))
  val c1 = _check_byte(arr, 1, char2int0('1'))
  val ok = len = 2 && c0 && c1
  val () = $A.free<byte>(arr)
in ok end

fn _test_put_newline(): bool = let
  val b = create()
  val () = put_newline(b)
  val @(arr, len) = to_arr(b)
  val c0 = _check_byte(arr, 0, char2int0('\n'))
  val ok = len = 1 && c0
  val () = $A.free<byte>(arr)
in ok end

fn _test_bput(): bool = let
  val b = create()
  val () = bput(b, "hi")
  val @(arr, len) = to_arr(b)
  val c0 = _check_byte(arr, 0, char2int0('h'))
  val c1 = _check_byte(arr, 1, char2int0('i'))
  val ok = len = 2 && c0 && c1
  val () = $A.free<byte>(arr)
in ok end

fn _test_bput_int(): bool = let
  val b = create()
  val () = bput_int(b, 123)
  val @(arr, len) = to_arr(b)
  val c0 = _check_byte(arr, 0, char2int0('1'))
  val c1 = _check_byte(arr, 1, char2int0('2'))
  val c2 = _check_byte(arr, 2, char2int0('3'))
  val ok = len = 3 && c0 && c1 && c2
  val () = $A.free<byte>(arr)
in ok end
