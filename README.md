# builder

Append-only byte buffer for building text output.

## API

- `create()` — allocate a new empty builder
- `put_byte(b, byte)` — append a single byte
- `put_str(b, s)` — append a borrowed byte string
- `put_int(b, n)` — append the decimal representation of an integer
- `put_newline(b)` — append a newline character
- `to_arr(b)` — finalize the builder and return the byte array

Auto-grows by doubling capacity. Linear — must finalize with `to_arr` or free.

## Dependencies

- array
- arith
