#include "share/atspre_staload.hats"
#use array as A
#use builder as B

(* put_byte on a builder that holds BUILDER_CAP bytes: no room, however
   the array inside grows *)
fn put_full {n:nat | n == $B.BUILDER_CAP}
  (b: !$B.builder(n) >> $B.builder(n+1)): void = $B.put_byte(b, 65)

implement main0 () = ()
