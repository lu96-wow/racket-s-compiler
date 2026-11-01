#lang racket/base

;; ============================================================
;; Support filter and normalization
;;
;; NASM describes every legacy, x87, MMX, SSE, AVX, APX, ... form.
;; The amd64 backend is a 64-bit GPR/XMM legacy encoder, so this stage
;; rejects forms outside that contract *loudly* and records the reason.
;; No source line is silently dropped.
;; ============================================================

(require racket/list
         racket/string
         "model.rkt")

(define forbidden-flags
  '(PSEUDO KILL EVEX APX VEX XOP AVX AVX2 AVX512 AVX512F AVX512VL
    FPU MMX AMX AMX_TRANSPOSE AMX_TF32 MPX X87
    NOLONG OBSOLETE UNDOC))

(define control-mnemonics
  '(jmp call loop jcxz jecxz jrcxz jcc setcc cmovcc))

(define (flag-present? flags name)
  (and (memq name flags) #t))

(define (forbidden-flag flags)
  (for/first ([f (in-list flags)]
              #:when (or (memq f forbidden-flags)
                         (string-prefix? (symbol->string f) "AVX512")))
    f))

(define (flag-size flags)
  (cond
    [(flag-present? flags 'SD) 32]
    [(flag-present? flags 'SQ) 64]
    [(flag-present? flags 'SO) 128]
    [else #f]))

(define (normalize-operands operands flags)
  (define inferred (flag-size flags))
  (for/list ([op (in-list operands)])
    (case (operand-def-kind op)
      [(xmm-rm)
       (operand-def (operand-def-text op)
                    'xmm-rm
                    (or (operand-def-width op) inferred 128)
                    #f)]
      [(mem)
       (operand-def (operand-def-text op)
                    'mem
                    (or (operand-def-width op) inferred)
                    #f)]
      [else op])))

(define (index-ok? index operands)
  (and (exact-nonnegative-integer? index)
       (< index (length operands))))

(define (resolve-line raw)
  (define line-no (raw-line-line-number raw))
  (define mnemonic (raw-line-mnemonic raw))
  (define flags (raw-line-flags raw))
  (define enc (raw-line-encoding raw))
  (define (skip reason) (values #f (skipped line-no mnemonic reason)))
  (define bad-operand
    (for/first ([op (in-list (raw-line-operands raw))]
                #:when (memq (operand-def-kind op) '(unity rel)))
      op))

  (cond
    [(memq mnemonic control-mnemonics)
     (skip "control form belongs to insn.rkt")]
    [(forbidden-flag flags)
     => (lambda (f)
          (skip (format "unsupported flag: ~a" f)))]
    [bad-operand
     (skip "unsupported operand class (rel/unity)")]
    [(null? (encoding-def-opcode enc))
     (skip "empty opcode")]
    [(> (length (encoding-def-imm enc)) 1)
     (skip "multiple immediates are not supported")]
    [(for/first ([imm (in-list (encoding-def-imm enc))]
                 #:when (string-prefix? (symbol->string (car imm)) "rel"))
       imm)
     (skip "relative-control encoding belongs to insn.rkt")]
    [else
     (define operands (normalize-operands (raw-line-operands raw) flags))
     (define plus-r (encoding-def-plus-r enc))
     (define rm-index (encoding-def-modrm-rm enc))
     (define reg-field (encoding-def-modrm-reg enc))
     (define imm-list (encoding-def-imm enc))
     (define imm (and (pair? imm-list) (car imm-list)))
     (cond
       [(and plus-r (not (index-ok? plus-r operands)))
        (skip "+r refers to a missing operand")]
       [(and rm-index (not (index-ok? rm-index operands)))
        (skip "ModR/M r/m refers to a missing operand")]
       [(and reg-field (eq? (car reg-field) 'r)
             (not (index-ok? (cadr reg-field) operands)))
        (skip "ModR/M reg refers to a missing operand")]
       [(and imm (not (index-ok? (list-ref imm 3) operands)))
        (skip "immediate refers to a missing operand")]
       [else
        (define opindex (and imm (list-ref imm 3)))
        (if (and opindex
                 (not (eq? (operand-def-kind (list-ref operands opindex))
                           'imm)))
            (skip "immediate token does not point at an immediate operand")
            (values (form mnemonic operands enc flags
                          (raw-line-path raw) line-no)
                    #f))])]))

(define (resolve-source raws)
  (define forms '())
  (define skipped '())
  (for ([raw (in-list raws)])
    (define-values (form reason) (resolve-line raw))
    (cond
      [form (set! forms (cons form forms))]
      [else (set! skipped (cons reason skipped))]))
  (values (reverse forms) (reverse skipped)))

(provide forbidden-flags
         resolve-line
         resolve-source)
