#lang racket/base

;; ============================================================
;; Build-time data model
;;
;; Parse structs describe source files. resolve.rkt turns candidates
;; into resolved-def values that carry both the instruction definition
;; and its provenance.
;; ============================================================

(require "runtime/lib/limits.rkt")

;; A fixed bit range [lo, hi] with a constant value.
(struct fixed-field (lo hi value)
  #:transparent
  #:guard
  (lambda (lo hi value who)
    (unless (exact-nonnegative-integer? lo)
      (raise-argument-error who "exact-nonnegative-integer?" lo))
    (unless (exact-nonnegative-integer? hi)
      (raise-argument-error who "exact-nonnegative-integer?" hi))
    (unless (<= lo hi)
      (error who "lo (~a) must be <= hi (~a)" lo hi))
    (when (> hi max-target-bit-index)
      (error who
             "hi (~a) must be <= ~a"
             hi
             max-target-bit-index))
    (unless (exact-nonnegative-integer? value)
      (raise-argument-error who "exact-nonnegative-integer?" value))
    (define width (add1 (- hi lo)))
    (unless (< value (arithmetic-shift 1 width))
      (error who "value ~a does not fit in ~a bit(s) [~a..~a]"
             value width lo hi))
    (values lo hi value)))

;; One source instruction definition. Operand tokens keep their exact
;; source order; imm12hi/imm12lo are NOT merged here.
(struct instruction-def (name operands fixed-fields)
  #:transparent
  #:guard
  (lambda (name operands fixed-fields who)
    (unless (string? name)
      (raise-argument-error who "string?" name))
    (unless (and (list? operands) (andmap string? operands))
      (raise-argument-error who "(listof string?)" operands))
    (unless (and (list? fixed-fields) (andmap fixed-field? fixed-fields))
      (raise-argument-error who "(listof fixed-field?)" fixed-fields))
    (values name operands fixed-fields)))

;; $pseudo_op source-extension::source-instruction new-name ...
(struct pseudo-def (source-extension source-instruction name instruction)
  #:transparent)

;; $import source-extension::instruction-name
(struct import-def (source-extension instruction-name)
  #:transparent)

(struct extension-file (path standard pseudo imports)
  #:transparent)

;; Build-time provenance. This is intentionally separate from the runtime
;; instruction-origin struct: build-time code never shares live values with
;; generated modules.
(struct definition-origin
  (kind                ; 'standard | 'import | 'pseudo
   source-extension    ; symbol or #f
   source-instruction) ; symbol or #f
  #:transparent)

;; Candidate before winner selection.
(struct candidate
  (definition kind origin standard-form?)
  #:transparent)

;; Final definition after winner selection.
(struct resolved-def (definition origin)
  #:transparent)

(struct skipped-definition (name reason)
  #:transparent)

(provide fixed-field
         fixed-field?
         fixed-field-lo
         fixed-field-hi
         fixed-field-value

         instruction-def
         instruction-def?
         instruction-def-name
         instruction-def-operands
         instruction-def-fixed-fields

         pseudo-def
         pseudo-def?
         pseudo-def-source-extension
         pseudo-def-source-instruction
         pseudo-def-name
         pseudo-def-instruction

         import-def
         import-def?
         import-def-source-extension
         import-def-instruction-name

         extension-file
         extension-file?
         extension-file-path
         extension-file-standard
         extension-file-pseudo
         extension-file-imports

         definition-origin
         definition-origin?
         definition-origin-kind
         definition-origin-source-extension
         definition-origin-source-instruction

         candidate
         candidate?
         candidate-definition
         candidate-kind
         candidate-origin
         candidate-standard-form?

         resolved-def
         resolved-def?
         resolved-def-definition
         resolved-def-origin

         skipped-definition
         skipped-definition?
         skipped-definition-name
         skipped-definition-reason)
