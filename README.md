# builder

Append-only byte buffer for building text output.

## API

- `create()` — a new empty builder (64 bytes of array)
- `put_byte(b, byte)` — append a single byte
- `put_str(b, s)` — append a borrowed byte string
- `put_int(b, n)` — append the decimal representation of an integer
- `put_newline(b)` — append a newline character
- `bput(b, s)` — append a string
- `length(b)` — the number of bytes written
- `to_arr(b)` — finalize: an array of `BUILDER_CAP` bytes (a copy), the first `n` the text
- `into_arr(b)` — finalize: the builder's own array, `cap` bytes with `n <= cap <= BUILDER_CAP`, no copy
- `builder_free(b)` — release it

The capacity is not in the type: `builder(n)` is indexed by its length alone.
Its array starts at 64 bytes and is made twice as large, in place, when a
byte does not fit, up to `BUILDER_CAP` (524288). A builder of a few bytes
costs a few bytes. Linear — must finalize with `to_arr` / `into_arr` or free.
`builder_store` is the array's holder and is not for callers.

## Rope

A rope is text of any length, held as chunks: the chunks already filled
(`rope_list`, newest first) and the builder being filled.

- `rope_create()`, `rope_put(r, v)`, `rope_bput(r, s)`, `rope_copy(r, src, start, stop)`, `rope_append(r, b)` — append
- `rope_chunks(r)` — the chunks, oldest first, the rope given up; `rope_list_free(cs)` frees them

A chunk is a builder's own array, `cap` bytes of which the first `n` hold
text (`n <= cap <= BUILDER_CAP`, proved by the type). A builder's array starts
at 64 bytes and doubles, so a chunk is 64 bytes or fewer than twice the bytes
it holds: a rope of a few bytes allocates 64 bytes, not `BUILDER_CAP` (#51). The rule is in the comment on `rope_list`, not in its type.

## Dependencies

- array
- arith
