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

## Growing builder

`growing_create(cap)` makes an empty builder whose array holds `cap`
bytes; `growing_put_byte` appends a byte and, when the array is full,
makes it twice as large (at most BUILDER_CAP). `create()` still makes a
BUILDER_CAP builder, so a dependent that has one keeps it. Use the
growing builder where most builders hold a few bytes (one per path or
line): `create()` zeroes 512 KiB for each. `growing_length`,
`growing_capacity`, `growing_to_arr` and `growing_free` complete it.
The type is `growing_builder(n, cap)`, with `n <= cap <= BUILDER_CAP`.
