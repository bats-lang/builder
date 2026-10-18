(* builder -- append-only byte string builder *)
(* Fixed-capacity buffer (512KB). Indexed type tracks position. *)
(* No runtime checks: callers prove capacity and byte ranges via constraints. *)

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

#pub fn to_arr {n:nat | n <= BUILDER_CAP}
  (b: builder(n)): @([l:agz] $A.arr(byte, l, BUILDER_CAP), int n)

#pub fun builder_free
  (b: builder_v): void

#pub fun length {n:nat | n <= BUILDER_CAP}
  (b: !builder(n)): int(n)

#pub fun put_byte {n:nat | n < BUILDER_CAP}{v:nat | v < 256}
  (b: !builder(n) >> builder(n+1), v: int v): void

#pub fun put_char {n:nat | n < BUILDER_CAP}{v:nat | v < 256}
  (b: !builder(n) >> builder(n+1), v: int v): void

#pub fun put_newline {n:nat | n < BUILDER_CAP}
  (b: !builder(n) >> builder(n+1)): void

(* Decimal digits of num, with a leading '-' when negative: at most 11
   bytes (an int is 32 bits: 10 digits and the sign). *)
#pub fun put_int {n:nat | n + 11 <= BUILDER_CAP}
  (b: !builder(n) >> [m:nat | n < m; m <= n + 11] builder(m), num: int): void

#pub fn bput {sn:nat}{n:nat | n + sn <= BUILDER_CAP}
  (b: !builder(n) >> builder(n + sn), s: string sn): void

(* ============================================================
   Rope: text of any length, in builder-sized chunks
   ============================================================ *)

(* k chunks, each an array of BUILDER_CAP bytes whose first n hold text *)
#pub datavtype rope_list(int) =
  | rope_nil(0)
  | {k:nat}{lb:agz}{n:nat | n <= BUILDER_CAP}
    rope_cons(k + 1) of ($A.arr(byte, lb, BUILDER_CAP), int n, rope_list(k))

(* Text of any length: the chunks already filled (newest first) and the
   one being filled. Each chunk is one BUILDER_CAP allocation, so no
   allocation grows with the text. *)
#pub datavtype rope =
  | {k:nat} Rope of (rope_list(k), builder_v)

#pub fun rope_create (): rope

(* Appends the byte v *)
#pub fun rope_put {v:nat | v < 256} (r: !rope, v: int v): void

(* Appends s *)
#pub fun rope_bput {sn:nat} (r: !rope, s: string sn): void

(* Appends src[start, stop) *)
#pub fun rope_copy {l:agz}{n:pos}{i,j:nat | i <= j; j <= n}
  (r: !rope, src: !$A.borrow(byte, l, n), start: int i, stop: int j): void

(* Appends b's text *)
#pub fun rope_append (r: !rope, b: builder_v): void

(* The rope's chunks, oldest first: its text is their texts in order *)
#pub fun rope_chunks (r: rope): [k:nat] rope_list(k)

(* Frees a list of chunks *)
#pub fun rope_list_free {k:nat} (cs: rope_list(k)): void

(* ============================================================
   Growing builder (#43): the array is as large as the caller's first
   capacity and is made larger, by doubling, when a byte does not fit. So
   a builder of a few bytes costs a few bytes, not BUILDER_CAP: create's
   512 KiB is zeroed by alloc, and making one per path or line is what
   bats check spent its system time on (page faults; measured in the PR).
   The capacity is in the type, as the array's length is in builder's: a
   byte is written only where the array has room, and the bytes are never
   more than BUILDER_CAP. create and builder are unchanged, so no
   dependent's proof or call changes.
   ============================================================ *)

#pub datavtype growing_builder(int, int) =
  | {lb:agz}{n,cap:nat | n <= cap; cap <= BUILDER_CAP}
    GrowingBuilder(n, cap) of ($A.arr(byte, lb, cap), int(n), int(cap))

#pub vtypedef growing_builder_v = [n,cap:nat | n <= cap; cap <= BUILDER_CAP] growing_builder(n, cap)

(* An empty builder whose array holds cap bytes to begin with *)
#pub fun growing_create {cap:pos | cap <= BUILDER_CAP}
  (cap: int cap): growing_builder(0, cap)

#pub fun growing_length {n,cap:nat | n <= cap}
  (b: !growing_builder(n, cap)): int(n)

#pub fun growing_capacity {n,cap:nat | n <= cap}
  (b: !growing_builder(n, cap)): int(cap)

#pub fun growing_free {n,cap:nat | n <= cap}
  (b: growing_builder(n, cap)): void

#pub fun growing_to_arr {n,cap:nat | n <= cap}
  (b: growing_builder(n, cap)): @([l:agz] $A.arr(byte, l, cap), int n)

(* Appends the byte v, growing the array first when it is full *)
#pub fun growing_put_byte {n,cap:nat | n < BUILDER_CAP; n <= cap; cap <= BUILDER_CAP}
  {v:nat | v < 256}
  (b: growing_builder(n, cap), v: int v): [new_cap:nat | n + 1 <= new_cap; new_cap <= BUILDER_CAP] growing_builder(n + 1, new_cap)

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

implement put_char(b, v) = put_byte(b, v)

implement put_newline(b) = put_byte(b, 10)

(* |num| is written as head digits then one last digit, and is never
   computed itself: for the minimum int it does not fit in an int. For
   num < 0, ~(num + 1) = |num| - 1 always fits, and adding the 1 back
   carries into head when its last digit is 9. head = |num| / 10 is
   below 10^9, so it has at most nine digits. *)
implement put_int(b, num) = let
  (* The digits of u in its k lowest decimal places, without leading
     zeros: the higher places first, then this place's digit when u (this
     digit and the higher ones) is not 0. low_byte gives the digit's byte
     value its bound; it is the identity on 48 .. 57. *)
  fun head_digits {n:nat}{k:nat | n + k <= BUILDER_CAP} .<k>.
    (b: !builder(n) >> [m:nat | n <= m; m <= n + k] builder(m), u: int, k: int k): void =
    if k = 0 then ()
    else let
      val () = head_digits(b, u / 10, k - 1)
    in
      if u > 0 then put_byte(b, $AR.low_byte(u mod 10 + 48)) else ()
    end
  (* head's digits, then the last digit *)
  fn digits {n:nat | n + 10 <= BUILDER_CAP}
    (b: !builder(n) >> [m:nat | n < m; m <= n + 10] builder(m), head: int, last: int): void = let
    val () = head_digits(b, head, 9)
  in put_byte(b, $AR.low_byte(last + 48)) end
in
  if num < 0 then let
    val () = put_byte(b, 45)
    val m = ~(num + 1)
    val r = m mod 10
  in
    if r = 9 then digits(b, m / 10 + 1, 0) else digits(b, m / 10, r + 1)
  end
  else digits(b, num / 10, num mod 10)
end

implement bput(b, s) = let
  fun loop {sn:nat}{i:nat | i <= sn}{p:nat | p + sn - i <= BUILDER_CAP} .<sn - i>.
    (b: !builder(p) >> builder(p + sn - i),
     s: string sn, slen: int sn, i: int i): void =
    if i >= slen then ()
    else let
      val () = put_byte(b, $AR.byte_of_char(string_get_at(s, i)))
    in loop(b, s, slen, i + 1) end
  val slen = g1u2i(string1_length(s))
in loop(b, s, slen, 0) end

implement rope_create () = Rope(rope_nil(), create())

implement rope_put (r, v) = let
  val+ @Rope(cs, cur) = r
  val n = length(cur)
in
  if n < _BUILDER_CAP then let
    val () = put_byte(cur, v)
    prval () = fold@(r)
  in end
  else let
    val @(arr, len) = to_arr(cur)
    val () = cs := rope_cons(arr, len, cs)
    val () = cur := create()
    val () = put_byte(cur, v)
    prval () = fold@(r)
  in end
end

implement rope_bput (r, s) = let
  fun loop {sn:nat}{i:nat | i <= sn} .<sn - i>.
    (r: !rope, s: string sn, slen: int sn, i: int i): void =
    if i >= slen then ()
    else let
      val () = rope_put(r, $AR.byte_of_char(string_get_at(s, i)))
    in loop(r, s, slen, i + 1) end
in loop(r, s, g1u2i(string1_length(s)), 0) end

implement rope_copy {l}{n}{i,j} (r, src, start, stop) = let
  fun loop {k:nat | i <= k; k <= j} .<j - k>.
    (r: !rope, src: !$A.borrow(byte, l, n), k: int k): void =
    if k >= stop then ()
    else let
      val () = rope_put(r, $AR.low_byte(byte2int0($A.read<byte>(src, k))))
    in loop(r, src, k + 1) end
in loop(r, src, start) end

implement rope_append (r, b) = let
  val @(arr, len) = to_arr(b)
  val @(fz, bv) = $A.freeze<byte>(arr)
  val () = rope_copy(r, bv, 0, len)
  val () = $A.drop<byte>(fz, bv)
in $A.free<byte>($A.thaw<byte>(fz)) end

implement rope_chunks (r) = let
  val+ ~Rope(cs, cur) = r
  val @(arr, len) = to_arr(cur)
  (* cs is newest first: reversed onto acc, it comes out oldest first *)
  fun rev {a,b:nat} .<a>. (cs: rope_list(a), acc: rope_list(b)): rope_list(a + b) =
    case+ cs of
    | ~rope_nil() => acc
    | ~rope_cons(x, n, tl) => rev(tl, rope_cons(x, n, acc))
in rev(rope_cons(arr, len, cs), rope_nil()) end

implement rope_list_free (cs) = let
  fun loop {k:nat} .<k>. (cs: rope_list(k)): void =
    case+ cs of
    | ~rope_nil() => ()
    | ~rope_cons(x, _, tl) => let val () = $A.free<byte>(x) in loop(tl) end
in loop(cs) end

implement growing_create(cap) = let
  val buf = $A.alloc<byte>(cap)
in GrowingBuilder(buf, 0, cap) end

implement growing_length(b) = let
  val+ @GrowingBuilder(_, pos, _) = b
  val p = pos
  prval () = fold@(b)
in p end

implement growing_capacity(b) = let
  val+ @GrowingBuilder(_, _, cap) = b
  val c = cap
  prval () = fold@(b)
in c end

implement growing_free(b) = let
  val+ ~GrowingBuilder(buf, _, _) = b
in $A.free<byte>(buf) end

implement growing_to_arr(b) = let
  val+ ~GrowingBuilder(buf, pos, _) = b
in @(buf, pos) end

(* The bytes [0, k) of src, into dst at the same places. Both arrays are
   proved to hold them: k <= n, and n is no more than either capacity. *)
fun copy_bytes {l,m:agz}{n,cap,new_cap,k:nat | n <= cap; n <= new_cap; k <= n} .<n - k>.
  (src: !$A.arr(byte, l, cap), dst: !$A.arr(byte, m, new_cap), n: int n, k: int k): void =
  if k >= n then ()
  else let
    val () = $A.set<byte>(dst, k, $A.get<byte>(src, k))
  in copy_bytes(src, dst, n, k + 1) end

(* A new capacity for a builder of capacity cap holding n bytes, with room
   for one more and at most BUILDER_CAP: twice cap, or n + 1 when that is
   more. Doubling makes the cost of a byte amortised constant. *)
fn grown_cap {n,cap:nat | n < BUILDER_CAP; n <= cap; cap <= BUILDER_CAP}
  (n: int n, cap: int cap): [new_cap:nat | n + 1 <= new_cap; new_cap <= BUILDER_CAP] int(new_cap) =
  if cap + cap < n + 1 then n + 1
  else if cap + cap <= _BUILDER_CAP then cap + cap
  else _BUILDER_CAP

(* The byte put where the array has room: the builder is the same value,
   its length one more *)
fn put_fits {n,cap:nat | n < cap; cap <= BUILDER_CAP} {v:nat | v < 256}
  (b: growing_builder(n, cap), v: int v): growing_builder(n + 1, cap) = let
  val+ @GrowingBuilder(buf, pos, _) = b
  val () = $A.set<byte>(buf, pos, int2byte0(v))
  val () = pos := pos + 1
  prval () = fold@(b)
in b end

(* The byte put in an array made larger: the old one is copied and freed *)
fn put_grow {n,cap:nat | n < BUILDER_CAP; n <= cap; cap <= BUILDER_CAP} {v:nat | v < 256}
  (b: growing_builder(n, cap), v: int v):
  [new_cap:nat | n + 1 <= new_cap; new_cap <= BUILDER_CAP] growing_builder(n + 1, new_cap) = let
  val+ ~GrowingBuilder(buf, pos, old_cap) = b
  val new_cap = grown_cap(pos, old_cap)
  val grown = $A.alloc<byte>(new_cap)
  val () = copy_bytes(buf, grown, pos, 0)
  val () = $A.set<byte>(grown, pos, int2byte0(v))
  val () = $A.free<byte>(buf)
in GrowingBuilder(grown, pos + 1, new_cap) end

implement growing_put_byte(b, v) =
  if growing_length(b) < growing_capacity(b) then put_fits(b, v)
  else put_grow(b, v)

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
  val () = put_byte(b, 65)
  val () = put_byte(b, 66)
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
