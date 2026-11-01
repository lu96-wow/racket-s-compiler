# NASM instruction database snapshot

- `insns.dat`: upstream `x86/insns.dat` from
  `https://github.com/netwide-assembler/nasm`, commit
  `fbdc88565ccccfa0e8c69b21b1953d1eded02e89`.
- `insns.pre.dat`: output of NASM's `x86/preinsns.pl` on that file.  The
  Racket generator consumes this expanded form so builds do not require Perl.
- `LICENSE`: upstream BSD-2-Clause license.

Refresh instructions and the full generation pipeline are documented in
[`../NASM.md`](../NASM.md).
