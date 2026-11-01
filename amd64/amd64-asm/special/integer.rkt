#lang racket
;;; amd64/amd64-asm/special/integer.rkt
;;;
;;; Integer ALU/memory/unary/shift/multiply/bit/IO special encoders.

(require "../sexp.rkt"
         "../encoding-plan.rkt"
         "../registers.rkt"
         "../insn-core.rkt"
         "../operand.rkt")

(provide encode-alu
         encode-lea
         encode-push
         encode-pop
         encode-test
         encode-unary
         encode-shift
         encode-imul
         encode-divide
         encode-mov-extend
         encode-cqo
         encode-cdq
         encode-cdqe
         encode-bswap
         encode-xchg
         encode-bit-scan
         encode-shrd
         encode-binary-atomic
         encode-random-seed
         encode-clflush
         encode-in
         encode-out)

(define (alu-opcodes name)
  (case name
    [(add) (values '#x01 '#x03 0)]
    [(sub) (values '#x29 '#x2b 5)]
    [(and) (values '#x21 '#x23 4)]
    [(or)  (values '#x09 '#x0b 1)]
    [(xor) (values '#x31 '#x33 6)]
    [(cmp) (values '#x39 '#x3b 7)]
    [else (error 'alu-opcodes "not an ALU instruction: ~e" name)]))

(define (encode-alu name operands)
  (define-values (op-rm-reg op-reg-rm digit) (alu-opcodes name))
  (match operands
    [(list dst src)
     (define dst* (parse-rm dst))
     (cond
       [(and (rm-operand? src) (reg? (parse-rm src)))
        (define src* (parse-rm src))
        (define width (rm-width dst*))
        (unless (= width (reg-width src*))
          (error 'encode-alu "operand widths do not match: ~e ~e" dst src))
        (rm-plan width (list src*) (encode-rm dst* src*) (list op-rm-reg))]
       [(and (reg? dst*) (mem? src))
        (define width (reg-width dst*))
        (unless (= width (mem-width src))
          (error 'encode-alu "operand widths do not match: ~e ~e" dst src))
        (rm-plan width (list dst*) (encode-rm src dst*) (list op-reg-rm))]
       [(immediate-value src)
        (define value (immediate-value src))
        (define width (rm-width dst*))
        (define regs (regs-in-op dst*))
        (define forced (immediate-form src))
        (define (small? x) (<= -128 x 127))
        (cond
          [(eq? forced 'imm8)
           (check-imm8 value 'encode-alu)
           (rm-plan width regs (encode-rm dst* digit)
                    (list (if (= width 8) #x80 #x83)) (u8 value))]
          [(eq? forced 'imm16)
           (check-imm16 value 'encode-alu)
           (rm-plan width regs (encode-rm dst* digit) '(#x81) (u16 value))]
          [(eq? forced 'imm32)
           (check-imm32 value 'encode-alu) ; 64-bit uses sign-extended imm32
           (rm-plan width regs (encode-rm dst* digit) '(#x81) (u32 value))]
          [(= width 8)
           (check-imm8 value 'encode-alu)
           (rm-plan 8 regs (encode-rm dst* digit) '(#x80) (u8 value))]
          [(small? value)
           (rm-plan width regs (encode-rm dst* digit) '(#x83) (u8 value))]
          [else
           (case width
             [(16)
              (check-imm16 value 'encode-alu)
              (rm-plan 16 regs (encode-rm dst* digit) '(#x81) (u16 value))]
             [(32)
              (check-imm32 value 'encode-alu)
              (rm-plan 32 regs (encode-rm dst* digit) '(#x81) (u32 value))]
             [(64)
              (check-imm32/signed value 'encode-alu)
              (rm-plan 64 regs (encode-rm dst* digit) '(#x81) (u32 value))]
             [else (error 'encode-alu "bad operand width: ~e" width)])])]
       [else
        (error 'encode-alu "unsupported ~a operands: ~e" name operands)])]
    [_ (error 'encode-alu "~a takes two operands: ~e" name operands)]))

(define (encode-lea operands)
  (match operands
    [(list dst src)
     (define dst* (parse-reg dst))
     (define src* (parse-rm src))
     (unless (mem? src*) (error 'encode-lea "lea source must be memory: ~e" src))
     (rm-plan (reg-width dst*) (list dst*) (encode-rm src* dst*) '(#x8d))]
    [_ (error 'encode-lea "lea takes two operands: ~e" operands)]))

(define (encode-push operands)
  (match operands
    [(list src)
     (cond
       [(or (reg? src) (and (symbol? src) (lookup-register src #f)))
        (define r (parse-reg src))
        (define width (reg-width r))
        (unless (memq width '(16 64))
          (error 'encode-push "push register must be 16 or 64 bits: ~e" src))
        (define rex (make-rex #f (list r) 0 0 (if (>= (reg-index r) 8) 1 0)))
        (literal-plan
         (append (if (= width 16) (list #x66) '())
                 (if rex (list rex) '())
                 (u8 (+ #x50 (bitwise-and (reg-index r) #b111)))))]
       [(immediate-value src)
        (define v (immediate-value src))
        (cond
          [(and (not (eq? (immediate-form src) 'imm8)) (<= -128 v 127))
           (literal-plan (bytes* '(#x6a) (u8 v)))]
          [else
           (check-imm32/signed v 'encode-push)
           (literal-plan (bytes* '(#x68) (u32 v)))])]
       [(or (mem? src) (mem-form? src))
        (define m (parse-rm src))
        (unless (mem? m) (error 'encode-push "bad push operand: ~e" src))
        (define width (mem-width m))
        (unless (memq width '(16 64))
          (error 'encode-push "push memory must be b16 or b64: ~e" src))
        ;; 64-bit push/pop has a 64-bit default operand size; do not emit
        ;; a redundant REX.W (GNU as and Loko's assembler both omit it).
        (rm-plan (if (= width 64) 32 16) (regs-in-op m) (encode-rm m 6) '(#xff))]
       [else (error 'encode-push "unsupported push operand: ~e" src)])]
    [_ (error 'encode-push "push takes one operand: ~e" operands)]))

(define (encode-pop operands)
  (match operands
    [(list dst)
     (cond
       [(or (reg? dst) (and (symbol? dst) (lookup-register dst #f)))
        (define r (parse-reg dst))
        (define width (reg-width r))
        (unless (memq width '(16 64))
          (error 'encode-pop "pop register must be 16 or 64 bits: ~e" dst))
        (define rex (make-rex #f (list r) 0 0 (if (>= (reg-index r) 8) 1 0)))
        (literal-plan
         (append (if (= width 16) (list #x66) '())
                 (if rex (list rex) '())
                 (u8 (+ #x58 (bitwise-and (reg-index r) #b111)))))]
       [(or (mem? dst) (mem-form? dst))
        (define m (parse-rm dst))
        (unless (mem? m) (error 'encode-pop "bad pop operand: ~e" dst))
        (define width (mem-width m))
        (unless (memq width '(16 64))
          (error 'encode-pop "pop memory must be b16 or b64: ~e" dst))
        (rm-plan (if (= width 64) 32 16) (regs-in-op m) (encode-rm m 0) '(#x8f))]
       [else (error 'encode-pop "unsupported pop operand: ~e" dst)])]
    [_ (error 'encode-pop "pop takes one operand: ~e" operands)]))

(define (encode-test operands)
  (match operands
    [(list dst src)
     (define dst* (parse-rm dst))
     (cond
       [(and (rm-operand? src) (reg? (parse-rm src)))
        (define src* (parse-rm src))
        (define width (rm-width dst*))
        (unless (= width (reg-width src*))
          (error 'encode-test "operand widths do not match: ~e ~e" dst src))
        (rm-plan width (list src*) (encode-rm dst* src*) '(#x85))]
       [(immediate-value src)
        (define value (immediate-value src))
        (define width (rm-width dst*))
        (define regs (regs-in-op dst*))
        (case width
          [(8)
           (check-imm8 value 'encode-test)
           (rm-plan 8 regs (encode-rm dst* 0) '(#xf6) (u8 value))]
          [(16)
           (check-imm16 value 'encode-test)
           (rm-plan 16 regs (encode-rm dst* 0) '(#xf7) (u16 value))]
          [(32)
           (check-imm32 value 'encode-test)
           (rm-plan 32 regs (encode-rm dst* 0) '(#xf7) (u32 value))]
          [(64)
           (check-imm32/signed value 'encode-test)
           (rm-plan 64 regs (encode-rm dst* 0) '(#xf7) (u32 value))]
          [else (error 'encode-test "bad width: ~e" width)])]
       [else (error 'encode-test "unsupported operands: ~e" operands)])]
    [_ (error 'encode-test "test takes two operands: ~e" operands)]))

(define (encode-unary name operands)
  (match operands
    [(list rm)
     (define rm* (parse-rm rm))
     (define width (rm-width rm*))
     (define-values (op8 op digit)
       (case name
         [(inc) (values #xfe #xff 0)]
         [(dec) (values #xfe #xff 1)]
         [(not) (values #xf6 #xf7 2)]
         [(neg) (values #xf6 #xf7 3)]
         [else (error 'encode-unary "unknown unary instruction: ~e" name)]))
     (rm-plan width (regs-in-op rm*)
              (encode-rm rm* digit)
              (list (if (= width 8) op8 op)))]
    [_ (error 'encode-unary "~a takes one operand: ~e" name operands)]))

(define (encode-shift name operands)
  (match operands
    [(list rm count)
     (define rm* (parse-rm rm))
     (define width (rm-width rm*))
     (define digit (case name
                     [(rol) 0] [(ror) 1] [(rcl) 2] [(rcr) 3]
                     [(shl) 4] [(shr) 5] [(sar) 7]
                     [else (error 'encode-shift "unknown shift: ~e" name)]))
     (cond
       [(eq? count 'cl)
        (rm-plan width (regs-in-op rm*)
                 (encode-rm rm* digit)
                 (list (if (= width 8) #xd2 #xd3)))]
       [(immediate-value count)
        (define value (immediate-value count))
        (check-imm8 value 'encode-shift)
        (rm-plan width (regs-in-op rm*)
                 (encode-rm rm* digit)
                 (list (if (= width 8) #xc0 #xc1))
                 (u8 value))]
       [else (error 'encode-shift "shift count must be imm8 or cl: ~e" count)])]
    [_ (error 'encode-shift "~a takes two operands: ~e" name operands)]))

(define (encode-imul operands)
  (match operands
    [(list src)
     (define src* (parse-rm src))
     (define width (rm-width src*))
     (rm-plan width (regs-in-op src*)
              (encode-rm src* 5)
              (list (if (= width 8) #xf6 #xf7)))]
    [(list dst src)
     (define dst* (parse-reg dst))
     (define src* (parse-rm src))
     (define width (reg-width dst*))
     (unless (= width (rm-width src*))
       (error 'encode-imul "operand widths do not match: ~e ~e" dst src))
     (rm-plan width (list dst*) (encode-rm src* dst*) '(#x0f #xaf))]
    [(list dst src imm)
     (define dst* (parse-reg dst))
     (define src* (parse-rm src))
     (define width (reg-width dst*))
     (unless (= width (rm-width src*))
       (error 'encode-imul "operand widths do not match: ~e ~e" dst src))
     (unless (memq width '(16 32 64))
       (error 'encode-imul "three-operand imul needs 16/32/64-bit operands: ~e" operands))
     (define value (or (immediate-value imm)
                       (error 'encode-imul "imul immediate must be an integer: ~e" imm)))
     (cond
       [(and (not (eq? (immediate-form imm) 'imm32)) (<= -128 value 127))
        (rm-plan width (list dst*) (encode-rm src* dst*) '(#x6b) (u8 value))]
       [else
        (case width
          [(16)
           (check-imm16 value 'encode-imul)
           (rm-plan 16 (list dst*) (encode-rm src* dst*) '(#x69) (u16 value))]
          [(32)
           (check-imm32 value 'encode-imul)
           (rm-plan 32 (list dst*) (encode-rm src* dst*) '(#x69) (u32 value))]
          [(64)
           (check-imm32/signed value 'encode-imul)
           (rm-plan 64 (list dst*) (encode-rm src* dst*) '(#x69) (u32 value))])])]
    [_ (error 'encode-imul "imul takes 1, 2 or 3 operands: ~e" operands)]))

(define (encode-divide name operands)
  (match operands
    [(list rm)
     (define rm* (parse-rm rm))
     (define width (rm-width rm*))
     (define digit (case name [(div) 6] [(idiv) 7]
                         [else (error 'encode-divide "unknown divide: ~e" name)]))
     (rm-plan width (regs-in-op rm*)
              (encode-rm rm* digit)
              (list (if (= width 8) #xf6 #xf7)))]
    [_ (error 'encode-divide "~a takes one operand: ~e" name operands)]))

(define (encode-mov-extend signed? operands)
  (match operands
    [(list dst src)
     (define dst* (parse-reg dst))
     (define src* (parse-rm src))
     (define dw (reg-width dst*))
     (define sw (rm-width src*))
     (define opcode
       (cond
         [(and signed? (= sw 8)) '(#x0f #xbe)]
         [(and signed? (= sw 16)) '(#x0f #xbf)]
         [(and signed? (= sw 32) (= dw 64)) '(#x63)]
         [(and (not signed?) (= sw 8)) '(#x0f #xb6)]
         [(and (not signed?) (= sw 16)) '(#x0f #xb7)]
         [else (error 'encode-mov-extend "unsupported width combination: ~e -> ~e" sw dw)]))
     (rm-plan dw (list dst*) (encode-rm src* dst*) opcode)]
    [_ (error 'encode-mov-extend "~a takes two operands: ~e"
              (if signed? 'movsx 'movzx) operands)]))

(define (encode-cqo operands)
  (unless (null? operands) (error 'encode-cqo "cqo takes no operands: ~e" operands))
  (literal-plan '(#x48 #x99)))

(define (encode-cdq operands)
  (unless (null? operands) (error 'encode-cdq "cdq takes no operands: ~e" operands))
  (literal-plan '(#x99)))

(define (encode-cdqe operands)
  (unless (null? operands)
    (error 'encode-cdqe "cdqe takes no operands: ~e" operands))
  (literal-plan '(#x48 #x98)))

(define (encode-bswap operands)
  (match operands
    [(list reg)
     (define r (parse-reg reg))
     (define width (reg-width r))
     (unless (memq width '(32 64))
       (error 'encode-bswap "bswap needs a 32/64-bit register: ~e" reg))
     (define rex (make-rex (= width 64) (list r) 0 0
                           (if (>= (reg-index r) 8) 1 0)))
     (literal-plan
      (append (if rex (list rex) '())
              (list #x0f (+ #xc8 (bitwise-and (reg-index r) #b111)))))]
    [_ (error 'encode-bswap "bswap takes one register: ~e" operands)]))

(define (encode-xchg operands)
  (match operands
    [(list a b)
     (define a* (parse-rm a))
     (define b* (parse-rm b))
     (define regs (append (regs-in-op a*) (regs-in-op b*)))
     (cond
       [(and (reg? a*) (reg? b*))
        (define width (reg-width a*))
        (unless (= width (reg-width b*))
          (error 'encode-xchg "operand widths do not match: ~e ~e" a b))
        (rm-plan width regs (encode-rm a* b*) (list (if (= width 8) #x86 #x87)))]
       [(and (reg? a*) (mem? b*))
        (define width (reg-width a*))
        (unless (= width (mem-width b*))
          (error 'encode-xchg "operand widths do not match: ~e ~e" a b))
        (rm-plan width regs (encode-rm b* a*) (list (if (= width 8) #x86 #x87)))]
       [(and (mem? a*) (reg? b*))
        (define width (reg-width b*))
        (unless (= width (mem-width a*))
          (error 'encode-xchg "operand widths do not match: ~e ~e" a b))
        (rm-plan width regs (encode-rm a* b*) (list (if (= width 8) #x86 #x87)))]
       [else (error 'encode-xchg "unsupported xchg operands: ~e" operands)])]
    [_ (error 'encode-xchg "xchg takes two operands: ~e" operands)]))

(define (encode-bit-scan name operands)
  (match operands
    [(list dst src)
     (define d (parse-reg dst))
     (define s (parse-rm src))
     (define width (reg-width d))
     (unless (memq width '(16 32 64))
       (error name "~a needs a 16/32/64-bit destination: ~e" name dst))
     (unless (= width (rm-width s))
       (error name "operand widths do not match: ~e ~e" dst src))
     (case name
       [(bsf) (rm-plan width (list d) (encode-rm s d) '(#x0f #xbc))]
       [(bsr) (rm-plan width (list d) (encode-rm s d) '(#x0f #xbd))]
       [(popcnt) (rm-plan width (list d) (encode-rm s d)
                               '(#x0f #xb8) '() (list #xf3))]
       [else (error name "unknown bit-scan instruction: ~e" name)])]
    [_ (error name "~a takes two operands: ~e" name operands)]))

(define (encode-shrd operands)
  (match operands
    [(list dst src count)
     (define d (parse-rm dst))
     (define s (parse-reg src))
     (define width (rm-width d))
     (unless (memq width '(16 32 64))
       (error 'encode-shrd "shrd needs a 16/32/64-bit destination: ~e" dst))
     (unless (= width (reg-width s))
       (error 'encode-shrd "operand widths do not match: ~e ~e" dst src))
     (define regs (append (regs-in-op d) (list s)))
     (cond
       [(eq? count 'cl) (rm-plan width regs (encode-rm d s) '(#x0f #xad))]
       [(immediate-value count)
        (define v (immediate-value count))
        (check-imm8 v 'encode-shrd)
        (rm-plan width regs (encode-rm d s) '(#x0f #xac) (u8 v))]
       [else (error 'encode-shrd "shrd count must be imm8 or cl: ~e" count)])]
    [_ (error 'encode-shrd "shrd takes dst, src, count: ~e" operands)]))

(define (encode-binary-atomic name eight-op wide-op operands)
  (match operands
    [(list dst src)
     (define d (parse-rm dst))
     (define s (parse-reg src))
     (define width (if (mem? d) (mem-width d) (reg-width d)))
     (unless (= width (reg-width s))
       (error name "operand widths do not match: ~e ~e" dst src))
     (rm-plan width (append (regs-in-op d) (list s))
              (encode-rm d s)
              (if (= width 8) eight-op wide-op))]
    [_ (error name "~a takes dst, src: ~e" name operands)]))

(define (encode-random-seed name digit operands)
  (match operands
    [(list rm)
     (define r (parse-rm rm))
     (define width (rm-width r))
     (unless (memq width '(16 32 64))
       (error name "~a needs a 16/32/64-bit operand: ~e" name rm))
     (rm-plan width (regs-in-op r) (encode-rm r digit) '(#x0f #xc7))]
    [_ (error name "~a takes one operand: ~e" name operands)]))

(define (encode-clflush operands)
  (match operands
    [(list m)
     (define m* (parse-rm m))
     (unless (mem? m*) (error 'encode-clflush "clflush needs a memory operand: ~e" m))
     (rm-plan 8 (regs-in-op m*) (encode-rm m* 7) '(#x0f #xae))]
    [_ (error 'encode-clflush "clflush takes one memory operand: ~e" operands)]))

(define (port-reg? x)
  (and (symbol? x) (eq? x 'dx)))

(define (io-register x who)
  (define r (parse-reg x))
  (unless (and (= 0 (reg-index r)) (memq (reg-width r) '(8 16 32)))
    (error who "port I/O register must be al/ax/eax: ~e" x))
  r)

(define (encode-in operands)
  (match operands
    [(list dst port)
     (define d (io-register dst 'encode-in))
     (define width (reg-width d))
     (define p (if (= width 16) (list #x66) '()))
     (cond
       [(port-reg? port) (literal-plan (append p (list (if (= width 8) #xec #xed))))]
       [(immediate-value port)
        (define v (immediate-value port))
        (unless (<= 0 v 255) (error 'encode-in "port immediate out of range: ~e" port))
        (literal-plan (append p (list (if (= width 8) #xe4 #xe5)) (u8 v)))]
       [else (error 'encode-in "port must be dx or imm8: ~e" port)])]
    [_ (error 'encode-in "in takes dst, port: ~e" operands)]))

(define (encode-out operands)
  (match operands
    [(list port src)
     (define s (io-register src 'encode-out))
     (define width (reg-width s))
     (define p (if (= width 16) (list #x66) '()))
     (cond
       [(port-reg? port) (literal-plan (append p (list (if (= width 8) #xee #xef))))]
       [(immediate-value port)
        (define v (immediate-value port))
        (unless (<= 0 v 255) (error 'encode-out "port immediate out of range: ~e" port))
        (literal-plan (append p (list (if (= width 8) #xe6 #xe7)) (u8 v)))]
       [else (error 'encode-out "port must be dx or imm8: ~e" port)])]
    [_ (error 'encode-out "out takes port, src: ~e" operands)]))
