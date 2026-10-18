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

## Dependencies

- array
- arith
