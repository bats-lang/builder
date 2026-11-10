# builder

Append-only byte buffer for building text output.

The capacity is not in the type: `builder(n)` is indexed by its length alone.
Its array starts at 64 bytes and is made twice as large, in place, when a
byte does not fit, up to `BUILDER_CAP` (524288). A builder of a few bytes
costs a few bytes. Linear — must finalize with `to_arr` / `into_arr` or free.
`builder_store` is the array's holder and is not for callers.

## Rope

A rope is text of any length, held as chunks: the chunks already filled
(`rope_list`, newest first) and the builder being filled. Each chunk is an
array of exactly `BUILDER_CAP` bytes.

A chunk is a
builder's own array, `cap` bytes of which the first `n` hold text (`n <= cap
<= BUILDER_CAP`, proved by the type). A builder's array starts at 64 bytes and
doubles, so a chunk is 64 bytes or fewer than twice the bytes it holds: a rope
of a few bytes allocates 64 bytes, not `BUILDER_CAP` (#51). The rule is in the
comment on `rope_sized_list`, not in its type. The first rope stays as
published until builder#56 removes it.
