#lang racket
;;; amd64/amd64-asm/test-generated.rkt
;;;
;;; Tests for the NASM-derived generated instruction table.  The golden
;;; bytes were independently checked against llvm-mc (see test-oracle.rkt).

(require rackunit
         "insn.rkt"
         "insn-generic.rkt")

(define (enc name . operands)
  (encode-instruction name operands))

;; The table must actually be generated from a broad source snapshot, not a
;; hand-maintained mini table.
(check-true (> (generic-form-count) 1200))
(check-true (> (generic-mnemonic-count) 500))
(check-true (string? generic-source))

;; New families that were absent from the handwritten table.
(check-true (known-instruction? 'adc))
(check-true (known-instruction? 'sbb))
(check-true (known-instruction? 'shld))
(check-true (known-instruction? 'bt))
(check-true (known-instruction? 'movbe))
(check-true (known-instruction? 'lzcnt))
(check-true (known-instruction? 'addsd))
(check-true (known-instruction? 'movdqu))
(check-true (known-instruction? 'crc32))

;; Integer carry/borrow, short and full immediate forms.
(check-equal? (enc 'adc 'rax 'rbx) (bytes #x48 #x11 #xd8))
(check-equal? (enc 'adc 'rax 1) (bytes #x48 #x83 #xd0 #x01))
(check-equal? (enc 'adc 'rax 200) (bytes #x48 #x15 #xc8 #x00 #x00 #x00))
(check-equal? (enc 'sbb 'al 1) (bytes #x1c #x01))
(check-equal? (enc 'adc 'eax #x1234) (bytes #x15 #x34 #x12 #x00 #x00))
(check-equal? (enc 'adc 'rax -1) (bytes #x48 #x83 #xd0 #xff))

;; 8-bit high registers cannot coexist with REX; spl/r9b must emit it.
(check-equal? (enc 'adc 'ah 1) (bytes #x80 #xd4 #x01))
(check-equal? (enc 'adc 'spl 1) (bytes #x40 #x80 #xd4 #x01))
(check-equal? (enc 'adc '(b8 (base r12) (disp 3)) 'r9b)
              (bytes #x45 #x10 #x4c #x24 #x03))

;; Double shifts and bit test/scan families.
(check-equal? (enc 'shld 'rax 'rbx 3) (bytes #x48 #x0f #xa4 #xd8 #x03))
(check-equal? (enc 'shld 'rax 'rbx 'cl) (bytes #x48 #x0f #xa5 #xd8))
(check-equal? (enc 'bt 'rax 3) (bytes #x48 #x0f #xba #xe0 #x03))
(check-equal? (enc 'btc 'rax 'rbx) (bytes #x48 #x0f #xbb #xd8))
(check-equal? (enc 'bts '(b64 (base rax)) 'rbx) (bytes #x48 #x0f #xab #x18))
(check-equal? (enc 'btr 'eax 'ecx) (bytes #x0f #xb3 #xc8))

;; SIB/REX boundaries in generated forms.
(check-equal? (enc 'bt '(b64 (base r12) (index r10) (scale 8) (disp 16)) 7)
              (bytes #x4b #x0f #xba #x64 #xd4 #x10 #x07))
(check-equal? (enc 'movbe 'r8 '(b64 (base r13)))
              (bytes #x4d #x0f #x38 #xf0 #x45 #x00))

;; SSE/SSE2 forms now come from the table instead of one-off encoders.
(check-equal? (enc 'addsd 'xmm1 'xmm2) (bytes #xf2 #x0f #x58 #xca))
(check-equal? (enc 'addps 'xmm1 'xmm2) (bytes #x0f #x58 #xca))
(check-equal? (enc 'movapd 'xmm1 'xmm2) (bytes #x66 #x0f #x28 #xca))
(check-equal? (enc 'pxor 'xmm1 'xmm2) (bytes #x66 #x0f #xef #xca))
(check-equal? (enc 'paddq 'xmm1 'xmm2) (bytes #x66 #x0f #xd4 #xca))
(check-equal? (enc 'movsd 'xmm1 '(b64 (base rax))) (bytes #xf2 #x0f #x10 #x08))
(check-equal? (enc 'movdqu 'xmm1 '(b128 (base rsp)))
              (bytes #xf3 #x0f #x6f #x0c #x24))
(check-equal? (enc 'cvtsi2sd 'xmm1 'rax) (bytes #xf2 #x48 #x0f #x2a #xc8))

;; Legacy mandatory prefixes and 16-bit operand-size prefix ordering.
(check-equal? (enc 'lzcnt 'rax 'rbx) (bytes #xf3 #x48 #x0f #xbd #xc3))
(check-equal? (enc 'lzcnt 'ax 'cx) (bytes #x66 #xf3 #x0f #xbd #xc1))
(check-equal? (enc 'tzcnt 'r8 'r9) (bytes #xf3 #x4d #x0f #xbc #xc1))
(check-equal? (enc 'crc32 'rax 'rbx) (bytes #xf2 #x48 #x0f #x38 #xf1 #xc3))
(check-equal? (enc 'crc32 'eax '(b8 (base rbx)))
              (bytes #xf2 #x0f #x38 #xf0 #x03))

;; Fixed/no-operand system instructions now available from the table.
(check-equal? (enc 'xgetbv) (bytes #x0f #x01 #xd0))
(check-equal? (enc 'clts) (bytes #x0f #x06))
(check-equal? (enc 'rdpkru) (bytes #x0f #x01 #xee))
(check-equal? (enc 'stac) (bytes #x0f #x01 #xcb))
(check-equal? (enc 'monitor) (bytes #x0f #x01 #xc8))
(check-equal? (enc 'mwait) (bytes #x0f #x01 #xc9))

;; rm_sel rows and /digit memory rows.
(check-equal? (enc 'verr 'ax) (bytes #x0f #x00 #xe0))
(check-equal? (enc 'verw '(b16 (base rax))) (bytes #x0f #x00 #x28))
(check-equal? (enc 'sldt 'ax) (bytes #x66 #x0f #x00 #xc0))
(check-equal? (enc 'invlpg '(b64 (base rax))) (bytes #x0f #x01 #x38))
(check-equal? (enc 'sgdt '(b64 (base rax))) (bytes #x0f #x01 #x00))

;; 32/64-bit immediate and memory selection.
(check-equal? (enc 'movbe '(b64 (base rbx)) 'rax)
              (bytes #x48 #x0f #x38 #xf1 #x03))
(check-equal? (enc 'cmpxchg8b '(b64 (base rax))) (bytes #x0f #xc7 #x08))
(check-equal? (enc 'cmpxchg16b '(b128 (base rax)))
              (bytes #x48 #x0f #xc7 #x08))

;; Constraint/selection and byte emission are separate: a plan is selected
;; and fixed first, then emission consumes only that plan.
(define adc-plan (generic-plan-instruction 'adc '(rax 200)))
(check-equal? (plan-size adc-plan) 6)
(check-equal? (encode-plan adc-plan) (list #x48 #x15 #xc8 #x00 #x00 #x00))
(check-equal? (generic-instruction-size 'adc '(rax 200))
              (plan-size adc-plan))

;; instruction-size must use the same table/plan as encode.
(for ([case (in-list '((adc rax 200)
                       (shld rax rbx 3)
                       (lzcnt ax cx)
                       (crc32 rax rbx)
                       (movdqu xmm1 (b128 (base rsp)))) )])
  (check-equal? (instruction-size (car case) (cdr case))
                (bytes-length (apply enc (car case) (cdr case))))
  ;; These names are generic-only, so layout uses generic-instruction-size
  ;; (plan-size), never encode-plan.
  (check-equal? (instruction-size (car case) (cdr case))
                (generic-instruction-size (car case) (cdr case))))

(displayln "amd64 generated NASM table tests: ok")
