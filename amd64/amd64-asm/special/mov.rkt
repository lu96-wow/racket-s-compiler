#lang racket
;;; amd64/amd64-asm/special/mov.rkt
;;;
;;; mov immediate-selection policy and control/debug-register moves.

(require "../sexp.rkt"
         "../encoding-plan.rkt"
         "../registers.rkt"
         "../insn-core.rkt"
         "../operand.rkt")

(provide encode-mov)

(define (reg-class-of x)
  (define r (cond
              [(reg? x) x]
              [(symbol? x) (lookup-register x #f)]
              [else #f]))
  (and r (reg-class r)))

(define (special-register? x)
  (memq (reg-class-of x) '(control debug)))

(define (parse-special-register op)
  (define r (cond
              [(reg? op) op]
              [(symbol? op) (lookup-register op #f)]
              [else #f]))
  (unless (and r (memq (reg-class r) '(control debug)))
    (error 'parse-special-register "expected control/debug register: ~e" op))
  r)

(define (emit-special-mov opcode sr gpr)
  (define rex-r (if (>= (reg-index sr) 8) 1 0))
  (define rex-b (if (>= (reg-index gpr) 8) 1 0))
  (define rex (make-rex #f (list gpr) rex-r 0 rex-b))
  (literal-plan
   (append (if rex (list rex) '())
           (list #x0f opcode
                 (bitwise-ior #b11000000
                              (arithmetic-shift
                               (bitwise-and (reg-index sr) #b111) 3)
                              (bitwise-and (reg-index gpr) #b111))))))

(define (encode-special-mov dst src)
  (cond
    [(special-register? dst)
     (define sr (parse-special-register dst))
     (define g (parse-reg src))
     (emit-special-mov (case (reg-class sr)
                         [(control) #x22]
                         [(debug) #x23]
                         [else (error 'encode-mov "bad special register: ~e" sr)])
                       sr g)]
    [(special-register? src)
     (define sr (parse-special-register src))
     (define g (parse-reg dst))
     (emit-special-mov (case (reg-class sr)
                         [(control) #x20]
                         [(debug) #x21]
                         [else (error 'encode-mov "bad special register: ~e" sr)])
                       sr g)]
    [else (error 'encode-mov "expected a control/debug register: ~e ~e" dst src)]))

(define (encode-mov operands)
  (match operands
    [(list dst src)
     (if (or (special-register? dst) (special-register? src))
         (encode-special-mov dst src)
         (encode-mov-normal operands))]
    [_ (error 'encode-mov "mov takes two operands: ~e" operands)]))

(define (encode-mov-normal operands)
  (match operands
    [(list dst src)
     (define dst* (parse-rm dst))
     (define src* (and (rm-operand? src) (parse-rm src)))
     (cond
       [(and (reg? dst*) (reg? src*))
        (let* ([width (reg-width dst*)]
               [regs (list dst* src*)]
               [rm (encode-rm dst* src*)]
               [opcode (if (= width 8) '(#x88) '(#x89))])
          (unless (= width (reg-width src*))
            (error 'encode-mov "register widths do not match: ~e ~e" dst src))
          (rm-plan width regs rm opcode))]

       [(and (reg? dst*) (mem? src*))
        (unless (= (reg-width dst*) (mem-width src*))
          (error 'encode-mov "register/memory widths do not match: ~e ~e" dst src))
        (rm-plan (reg-width dst*)
                 (list dst*) (encode-rm src* dst*)
                 (list (if (= (reg-width dst*) 8) #x8a #x8b)))]

       [(and (mem? dst*) (reg? src*))
        (unless (= (mem-width dst*) (reg-width src*))
          (error 'encode-mov "memory/register widths do not match: ~e ~e" dst src))
        (rm-plan (mem-width dst*)
                 (list src*) (encode-rm dst* src*)
                 (list (if (= (mem-width dst*) 8) #x88 #x89)))]

       [(and (reg? dst*) (immediate-value src))
        (let* ([value (immediate-value src)]
               [width (reg-width dst*)]
               [forced (immediate-form src)]
               [regs (list dst*)])
          (define (emit-imm8)
            (check-imm8 value 'encode-mov)
            (literal-plan
             (append (prefixes 8 regs 0 0 (if (>= (reg-index dst*) 8) 1 0))
                     (u8 (+ #xb0 (bitwise-and (reg-index dst*) #b111)))
                     (u8 value))))
          (define (emit-imm16)
            (check-imm16 value 'encode-mov)
            (literal-plan
             (append (prefixes 16 regs 0 0 (if (>= (reg-index dst*) 8) 1 0))
                     (u8 (+ #xb8 (bitwise-and (reg-index dst*) #b111)))
                     (u16 value))))
          (define (emit-imm32)
            (check-imm32 value 'encode-mov)
            (literal-plan
             (append (prefixes 32 regs 0 0 (if (>= (reg-index dst*) 8) 1 0))
                     (u8 (+ #xb8 (bitwise-and (reg-index dst*) #b111)))
                     (u32 value))))
          (define (emit-imm64)
            (unless (= width 64)
              (error 'encode-mov "imm64 needs a 64-bit destination: ~e" dst))
            (let ([rex (make-rex #t regs 0 0 (if (>= (reg-index dst*) 8) 1 0))])
              (literal-plan
               (append (if rex (list rex) '())
                       (u8 (+ #xb8 (bitwise-and (reg-index dst*) #b111)))
                       (u64 value)))))
          (define (emit-by-value)
            (case width
              [(8) (emit-imm8)]
              [(16) (emit-imm16)]
              [(32) (emit-imm32)]
              [(64)
               (cond
                 [(<= (- (expt 2 31)) value (sub1 (expt 2 31)))
                  (check-imm32/signed value 'encode-mov)
                  (let ([rm (encode-rm dst* 0)])
                    (rm-plan 64 regs rm '(#xc7) (u32 value)))]
                 [(<= 0 value (sub1 (expt 2 32)))
                  ;; mov r32, imm32 zero-extends to r64
                  (emit-imm32)]
                 [else (emit-imm64)])]))
          (case forced
            [(imm8)
             (unless (= width 8)
               (error 'encode-mov "imm8 needs an 8-bit destination: ~e" dst))
             (emit-imm8)]
            [(imm16) (emit-imm16)]
            [(imm32) (emit-imm32)]
            [(imm64) (emit-imm64)]
            [else (emit-by-value)]))]
       [(and (mem? dst*) (immediate-value src))
        (let* ([value (immediate-value src)]
               [width (mem-width dst*)]
               [regs '()])
          (case width
            [(8)
             (check-imm8 value 'encode-mov)
             (rm-plan 8 regs (encode-rm dst* 0) '(#xc6) (u8 value))]
            [(16)
             (check-imm16 value 'encode-mov)
             (rm-plan 16 regs (encode-rm dst* 0) '(#xc7) (u16 value))]
            [(32)
             (check-imm32 value 'encode-mov)
             (rm-plan 32 regs (encode-rm dst* 0) '(#xc7) (u32 value))]
            [(64)
             (check-imm32/signed value 'encode-mov)
             (rm-plan 64 regs (encode-rm dst* 0) '(#xc7) (u32 value))]))]
       [else
        (error 'encode-mov "unsupported mov operands: ~e" operands)])]
    [_ (error 'encode-mov "mov takes two operands: ~e" operands)]))
