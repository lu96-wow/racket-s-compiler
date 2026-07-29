#lang racket

(require racket/string
         "../riscv/parse/main.rkt")

;; ============================================================
;; Mezzano Common Lisp LAP code generator for RISC-V
;; ============================================================
;;
;; Generates lap-riscv64-gen.lisp — pure define-instruction forms.
;; Mezzano-specific infrastructure (helpers, macros, pseudo-instructions)
;; lives in the hand-maintained lap-riscv64.lisp.
;;
;; Target: RV64GC (I + M + A + F + D + Zicsr + Zifencei + Zba + Zbb + Zbs)

;; ============================================================
;; Operand classification
;; ============================================================

(define (classify-operand op-name)
  (cond [(member op-name '("rd" "rs1" "rs2" "rs3" "rd_n0" "rs1_n0" "rs2_n0"
                           "rd_rs1_n0" "rd_p" "rs1_p" "rs2_p" "rd_rs1_p"))
         'reg]
        [(equal? op-name "csr")     'imm]
        [(equal? op-name "imm12")   'imm]
        [(equal? op-name "simm12")  'simm]
        [(equal? op-name "bimm12")  'bimm]
        [(equal? op-name "jimm20")  'jimm]
        [(equal? op-name "imm20")   'uimm]
        [(equal? op-name "shamtw")  'shamt5]
        [(equal? op-name "shamtd")  'shamt6]
        [(member op-name '("aq"))   'aq]
        [(member op-name '("rl"))   'rl]
        [(equal? op-name "rm")      'rm]
        [(equal? op-name "fm")      'fm]
        [(equal? op-name "pred")    'pred]
        [(equal? op-name "succ")    'succ]
        [else 'generic-imm]))

;; ============================================================
;; Fixed field computation
;; ============================================================

(define (fixed-field-contribution ff)
  (bitwise-and
   (arithmetic-shift (fixed-field-value ff)
                     (min (fixed-field-high ff) (fixed-field-low ff)))
   #xFFFFFFFF))

(define (compute-const-value idef)
  (for/fold ([val 0])
            ([ff (in-list (instruction-def-fixed-fields idef))])
    (bitwise-ior val (fixed-field-contribution ff))))

;; ============================================================
;; Generate operand encoding expression
;; ============================================================

(define (gen-operand-lisp op)
  (define mode (classify-operand op))
  (define shift
    (cond [(equal? op "rd") 7]
          [(equal? op "rs1") 15]
          [(equal? op "rs2") 20]
          [(equal? op "rs3") 27]
          [else 0]))
  (case mode
    [(reg)   (format "(ash (resolve-register ~a) ~a)" op shift)]
    [(imm)   (format "(i-immediate ~a)" op)]
    [(simm)  (format "(s-immediate ~a)" op)]
    [(bimm)  (format "(b-immediate ~a)" op)]
    [(jimm)  (format "(j-immediate ~a)" op)]
    [(uimm)  (format "(u-immediate ~a)" op)]
    [(shamt5) (format "(ash (resolve-immediate ~a) 20)" op)]
    [(shamt6) (format "(ash (resolve-immediate ~a) 20)" op)]
    [(aq)    (format "(ash (resolve-immediate ~a) 26)" op)]
    [(rl)    (format "(ash (resolve-immediate ~a) 25)" op)]
    [(rm)    (format "(ash (resolve-immediate ~a) 12)" op)]
    [(fm)    (format "(ash (resolve-immediate ~a) 28)" op)]
    [(pred)  (format "(ash (resolve-immediate ~a) 24)" op)]
    [(succ)  (format "(ash (resolve-immediate ~a) 20)" op)]
    [else    (format "(generic-immediate ~a)" op)]))

;; ============================================================
;; Reorder S-type operand list for LAP convention
;; ============================================================
;; S-type instructions in riscv-opcodes: (simm12 rs1 rs2)
;; Our LAP convention:                 (rs2 rs1 simm12)  ← matches (value base offset)
;; The encoding bits do NOT change: rs2→bit20, rs1→bit15, simm12→s-immediate.

(define (reorder-s-type-operands ops)
  (if (member "simm12" ops)
      (list "rs2" "rs1" "simm12")
      ops))

;; ============================================================
;; Generate one instruction
;; ============================================================

(define (gen-lisp-instruction idef)
  (define raw-operands (instruction-def-operands idef))
  (define operands (reorder-s-type-operands raw-operands))
  (define const-val (compute-const-value idef))
  (define const-hex (~r const-val #:base 16 #:min-width 8 #:pad-string "0"))

  (if (null? operands)
      ;; Pure constant: ecall, ebreak, etc.
      (format "  (emit-instruction #x~a))" const-hex)
      ;; Normal instruction: register + immediate parts
      (string-join
       (append
        (list "  (emit-instruction"
              "   (logior")
        (map (λ (op) (format "    ~a" (gen-operand-lisp op))) operands)
        (list (format "    #x~a)))" const-hex)))
       "\n")))

;; ============================================================
;; Lisp name conversion
;; ============================================================

(define (lisp-name name)
  (string-replace name "." "-"))

;; ============================================================
;; Section for one extension
;; ============================================================

(define (gen-lisp-extension-section type-sym defs)
  (string-join
   (append
    (list (format ";;;; ~a instructions (~a)" type-sym (length defs)) "")
    (for/list ([idef (in-list defs)])
      (define raw-ops (instruction-def-operands idef))
      (define ops (reorder-s-type-operands raw-ops))
      (format "(define-instruction ~a (~a)~%~a~%"
              (lisp-name (instruction-def-name idef))
              (string-join ops " ")
              (gen-lisp-instruction idef))))
   "\n"))

;; ============================================================
;; Master file generator
;; ============================================================

(define target-extensions
  '(rv_i rv64_i rv_m rv64_m rv_a rv64_a
    rv_f rv_d rv64_f rv64_d
    rv_zicsr rv_zifencei
    rv_zba rv64_zba rv_zbb rv64_zbb rv_zbs rv64_zbs))

(define (gen-lisp-master-file ext-sources)
  "Generate only the auto-generated define-instruction forms.
   Mezzano-specific infrastructure lives in lap-riscv64.lisp."
  (string-join
   (append
    (list ";;;; RISC-V 64-bit (RV64GC) instruction definitions for Mezzano LAP"
          ";;;; Auto-generated by racket-s-compiler from riscv-opcodes"
          ";;;; DO NOT EDIT — changes will be overwritten."
          ";;;; This file is loaded by lap-riscv64.lisp."
          ""
          "(in-package :mezzano.lap.riscv64)"
          "")
    (for/list ([ext-sym (in-list target-extensions)])
      (define esrc (findf (λ (e) (equal? (extension-source-type-sym e) ext-sym))
                          ext-sources))
      (if esrc
          (let* ([defs (parse-file (extension-source-path esrc))])
            (gen-lisp-extension-section ext-sym defs))
          (format ";;;; ~a: source NOT FOUND~%~%" ext-sym)))
    '(";;; ============================================================"
      ";;; End of auto-generated instruction definitions"
      ";;; ============================================================"))
   "\n"))

;; ============================================================
;; Provide
;; ============================================================

(provide
 gen-lisp-instruction
 gen-lisp-extension-section
 gen-lisp-master-file)
