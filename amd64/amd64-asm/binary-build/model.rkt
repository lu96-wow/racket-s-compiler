#lang racket/base

;; ============================================================
;; Build-time data model
;;
;; raw-line     : one four-field line from NASM's preprocessed insns.dat
;; operand-def  : public operand shape, independent of encoding policy
;; encoding-def : parsed encoding byte string
;; form         : a supported resolved table entry
;; skipped      : a source line rejected with an explicit reason
;; ============================================================

(struct raw-line (mnemonic operands encoding flags path line-number)
  #:transparent)

;; kind:
;;   gpr | gpr-fixed | rm | mem | xmm | xmm-rm | imm | void
;; width: bits or #f for "any"
;; fixed: register symbol for gpr-fixed, otherwise #f
(struct operand-def (text kind width fixed)
  #:transparent)

;; A literal or semantic token in the NASM encoding column.
(struct encoding-def
  (prefixes       ; mandatory legacy prefix bytes, e.g. 66 f2 f3
   opcode         ; literal opcode bytes
   plus-r         ; operand index added to the last opcode byte, or #f
   modrm-rm       ; operand index placed in ModR/M r/m, or #f
   modrm-reg      ; (r operand-index) or (digit n)
   imm            ; list of (imm-kind width range operand-index)
   size-mode      ; o8 o16 o32 o64 osz osm odf #f
   nw?            ; NASM "nw": 64-bit default operand size, no REX.W
   force-rex-w?   ; rex.w in the source encoding
   rex-b? rex-x? rex-r? ; obligatory REX bits in the source encoding
   wait?)         ; 0x9b wait prefix
  #:transparent)

(struct form (mnemonic operands encoding flags path line-number)
  #:transparent)

(struct skipped (line-number mnemonic reason)
  #:transparent)

(provide (struct-out raw-line)
         (struct-out operand-def)
         (struct-out encoding-def)
         (struct-out form)
         (struct-out skipped))
