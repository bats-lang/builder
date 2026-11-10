# builder

## rope-chunks: a rope's chunk is the builder's own array (#51)

The published `rope` made every chunk an array of `BUILDER_CAP` (524288) bytes
(`to_arr` copies a builder into one), so a rope of a few bytes cost 512 KiB; bats
made one per module per `bats check` (bats#368). `sized_rope` is beside it: its
chunk is the builder's own array (`into_arr`, no copy), typed
`rope_sized_cons of ($A.arr(byte, lb, cap), int n, ...)` with `n <= cap <= BUILDER_CAP`
(the way `into_arr` and process's `arg_entry` carry a capacity). A builder's array
starts at 64 bytes and doubles when a byte does not fit, so a chunk is 64 bytes or
fewer than twice the bytes it holds; that rule is in the comment on
`rope_sized_list`, not in the type, because `builder(n)` hides its capacity.
No runtime check, no `$UNSAFE`, `praxi` or `assume`.

The change is additive (repository-prototype's overlap rule): `rope`, `rope_list`
and the `rope_*` functions keep their published types, `sized_rope`,
`rope_sized_list` and the `sized_rope_*` functions are the new form, and the old
form is removed by builder#56 (p2) once its dependents have moved (bats#473 for
bats; json's tests name the old chunk). Tests: `tests/dynamic/rope_small` runs
a rope of five bytes and of none under valgrind `--trace-malloc` and fails when
any block is 524288 bytes (`no-alloc-bytes`, counted by `tests/dynamic/run.sh`);
`tests/dynamic/rope_old` is the old form and its `no-alloc-bytes-control` passes
only when that run does make a 524288-byte block, so the count is shown to see
the allocation and the old form cannot be dropped; `tests/static/reject/rope-chunk-full`
and `rope-cons-over-cap` refuse a chunk typed `BUILDER_CAP` where its capacity is
smaller and a chunk of more bytes than its capacity; `tests/static/accept/rope-old-consumer`
and `rope-constructor` use the old form.
