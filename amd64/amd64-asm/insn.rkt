#lang racket
;;; amd64/amd64-asm/insn.rkt
;;;
;;; 单条 amd64 指令 -> 字节。第一版只覆盖整数/控制流的一小撮形式。
;;;
;;; 约定:
;;;   - 操作数里的寄存器必须是物理寄存器名；
;;;   - 内存操作数是 (b8/b16/b32/b64 (base ...) (index ...) (scale ...) (disp ...));
;;;   - 分支/跳转目标在这一层已经是相对偏移(整数)，标签解析在 layout/bind 之后。
;;;
;;; 这是一个可执行的起点，不是完整 x86 编码器。表里没有的 form 直接报错。

(require "sexp.rkt"
         "registers.rkt")

(provide encode-instruction
         instruction-size
         instruction-arity
         known-instruction?
         immediate-form
         symbolic-immediate?
         choose-symbolic-immediate-forms)

;; ---------------------------------------------------------------------------
;; 寄存器/内存编码
;; ---------------------------------------------------------------------------

(struct rm-encoding (modrm sib disp rex-r rex-x rex-b seg) #:transparent)

(define (reg-field-index x)
  (cond
    [(reg? x) (reg-index x)]
    [(exact-integer? x) x]
    [else (error 'reg-field-index "expected register or digit: ~e" x)]))

(define (reg-field-rex-r x)
  (cond
    [(reg? x) (if (>= (reg-index x) 8) 1 0)]
    [else 0]))

(define (reg-rm-modrm reg index)
  (bitwise-ior (arithmetic-shift #b11 6)
               (arithmetic-shift (bitwise-and (reg-field-index reg) #b111) 3)
               (bitwise-and index #b111)))

(define (encode-rm op reg-field)
  ;; Returns rm-encoding. REG-FIELD is a register or a /digit (0..7).
  (cond
    [(reg? op)
     (rm-encoding (reg-rm-modrm reg-field (reg-index op))
                  #f
                  '()
                  (reg-field-rex-r reg-field)
                  0
                  (if (>= (reg-index op) 8) 1 0)
                  #f)]
    [(mem? op)
     (encode-mem-rm op reg-field)]
    [else
     (error 'encode-rm "expected register or memory operand: ~e" op)]))

(define (encode-mem-rm m reg-field)
  (define width (mem-width m))
  (define base-name (mem-base m))
  (define index-name (mem-index m))
  (define base (and base-name (not (eq? base-name 'rip))
                    (lookup-register base-name)))
  (define index (and index-name (lookup-register index-name)))
  (define scale (mem-scale m))
  (define disp (mem-disp m))
  (define disp-width (mem-disp-width m))
  (define seg (mem-seg m))
  (unless (exact-integer? disp)
    (error 'encode-mem-rm "memory displacement must be resolved to an integer: ~e" disp))
  ;; rsp cannot be a SIB index.  r12 is encoded as index 4 with REX.X=1.
  (when (and index (eq? (reg-name index) 'rsp))
    (error 'encode-mem-rm "rsp cannot be used as an index register: ~e" index-name))
  (define seg-prefix
    (case seg
      [(fs) #x64]
      [(gs) #x65]
      [else #f]))
  (define (disp8? x) (<= -128 x 127))
  (define (disp32-bytes x)
    (unless (<= (- (expt 2 31)) x (sub1 (expt 2 32)))
      (error 'encode-mem-rm "displacement does not fit in 32 bits: ~e" x))
    (u32 x))
  (define rex-r (reg-field-rex-r reg-field))
  (define rex-x (if (and index (>= (reg-index index) 8)) 1 0))
  (define rex-b-base (if (and base (>= (reg-index base) 8)) 1 0))
  (define rm (bitwise-and (reg-field-index reg-field) #b111))

  (cond
    [(eq? base-name 'rip)
     (when index
       (error 'encode-mem-rm "rip-relative addressing cannot use an index register"))
     (rm-encoding (bitwise-ior (arithmetic-shift #b00 6)
                               (arithmetic-shift rm 3)
                               #b101)
                  #f
                  (disp32-bytes disp)
                  rex-r
                  0
                  0
                  seg-prefix)]

    [(and (not base) (not index))
     ;; [disp32] in 64-bit mode: SIB with no base and no index.
     (rm-encoding (bitwise-ior (arithmetic-shift #b00 6)
                               (arithmetic-shift rm 3)
                               #b100)
                  #x25
                  (disp32-bytes disp)
                  rex-r
                  0
                  0
                  seg-prefix)]

    [(not base)
     ;; [index*scale+disp32]
     (define scale-bits (case scale [(1) #b00] [(2) #b01] [(4) #b10] [(8) #b11]))
     (rm-encoding (bitwise-ior (arithmetic-shift #b00 6)
                               (arithmetic-shift rm 3)
                               #b100)
                  (bitwise-ior (arithmetic-shift scale-bits 6)
                               (arithmetic-shift (bitwise-and (reg-index index) #b111) 3)
                               #b101)
                  (disp32-bytes disp)
                  rex-r
                  rex-x
                  0                                ; no base, REX.B is ignored
                  seg-prefix)]

    [else
     (define base-low (bitwise-and (reg-index base) #b111))
     (define need-sib? (or index (= base-low #b100)))
     (define rm-field (if need-sib? #b100 base-low))
     (define-values (mod disp-bytes)
       (cond
         [(eq? disp-width 32)
          (values #b10 (disp32-bytes disp))]
         [(eq? disp-width 8)
          (unless (disp8? disp)
            (error 'encode-mem-rm "forced disp8 does not fit: ~e" disp))
          (values #b01 (u8 disp))]
         [(and (zero? disp) (not (= base-low #b101))) (values #b00 '())]
         [(disp8? disp) (values #b01 (u8 disp))]
         [else (values #b10 (disp32-bytes disp))]))
     (define sib
       (and need-sib?
            (let* ([scale-bits (case scale [(1) #b00] [(2) #b01] [(4) #b10] [(8) #b11])]
                   [idx (if index (bitwise-and (reg-index index) #b111) #b100)])
              (bitwise-ior (arithmetic-shift scale-bits 6)
                           (arithmetic-shift idx 3)
                           base-low))))
     (rm-encoding (bitwise-ior (arithmetic-shift mod 6)
                               (arithmetic-shift rm 3)
                               rm-field)
                  sib
                  disp-bytes
                  rex-r
                  rex-x
                  rex-b-base
                  seg-prefix)]))

;; ---------------------------------------------------------------------------
;; 字节工具
;; ---------------------------------------------------------------------------

(define (u8 x) (list (bitwise-and x #xff)))
(define (u16 x) (list (bitwise-and x #xff) (bitwise-and (arithmetic-shift x -8) #xff)))
(define (u32 x)
  (list (bitwise-and x #xff)
        (bitwise-and (arithmetic-shift x -8) #xff)
        (bitwise-and (arithmetic-shift x -16) #xff)
        (bitwise-and (arithmetic-shift x -24) #xff)))
(define (u64 x) (append (u32 x) (u32 (arithmetic-shift x -32))))
(define (bytes* . xs) (append* xs))
(define (list->bytevector xs) (list->bytes xs))

(define (check-s8 x who)
  (unless (<= -128 x 127) (error who "value does not fit in signed 8 bits: ~e" x)))
(define (check-s32 x who)
  (unless (<= (- (expt 2 31)) x (sub1 (expt 2 31)))
    (error who "value does not fit in signed 32 bits: ~e" x)))
(define (check-u32 x who)
  (unless (<= 0 x (sub1 (expt 2 32)))
    (error who "value does not fit in unsigned 32 bits: ~e" x)))
(define (check-s16 x who)
  (unless (<= (- (expt 2 15)) x (sub1 (expt 2 15)))
    (error who "value does not fit in signed 16 bits: ~e" x)))
(define (check-u16 x who)
  (unless (<= (- (expt 2 15)) x (sub1 (expt 2 16)))
    (error who "value does not fit in 16 bits: ~e" x)))
(define (check-imm8 x who)
  (unless (<= -128 x 255)
    (error who "value does not fit in an 8-bit immediate: ~e" x)))
(define (check-imm16 x who)
  (unless (<= (- (expt 2 15)) x (sub1 (expt 2 16)))
    (error who "value does not fit in a 16-bit immediate: ~e" x)))
(define (check-imm32 x who)
  (unless (<= (- (expt 2 31)) x (sub1 (expt 2 32)))
    (error who "value does not fit in a 32-bit immediate: ~e" x)))
(define (check-imm32/signed x who)
  (unless (<= (- (expt 2 31)) x (sub1 (expt 2 31)))
    (error who "value does not fit in a sign-extended 32-bit immediate: ~e" x)))

;; ---------------------------------------------------------------------------
;; 前缀 / REX
;; ---------------------------------------------------------------------------

(define (regs-in-op op)
  (cond
    [(reg? op) (list op)]
    [(mem? op)
     (append
      (for/list ([name (in-list (list (mem-base op) (mem-index op)))]
                 #:when (and name (not (eq? name 'rip))))
        (lookup-register name))
      '())]
    [else '()]))

(define (make-rex width? regs rex-r rex-x rex-b)
  ;; Return a REX byte or #f.
  (define high8? (for/or ([r (in-list regs)]) (reg-high8? r)))
  (define rex8? (for/or ([r (in-list regs)]) (reg-rex8? r)))
  (define needed? (or width? rex8? (positive? rex-r) (positive? rex-x) (positive? rex-b)))
  (when (and high8? needed?)
    (error 'make-rex "high-byte register cannot be encoded with REX"))
  (and needed?
       (bitwise-ior #x40
                    (if width? #x08 0)
                    (if (positive? rex-r) #x04 0)
                    (if (positive? rex-x) #x02 0)
                    (if (positive? rex-b) #x01 0))))

(define (prefixes width regs rex-r rex-x rex-b)
  (define p (if (= width 16) (list #x66) '()))
  (define rex (make-rex (= width 64) regs rex-r rex-x rex-b))
  (append p (if rex (list rex) '())))

;; `extra-prefixes` are mandatory legacy prefixes such as F3 for POPCNT.
;; They go after 0x66 and before REX.
(define (emit-rm-with-prefixes width regs rm-enc opcode imm extra-prefixes)
  (append
   (if (rm-encoding-seg rm-enc) (list (rm-encoding-seg rm-enc)) '())
   (if (= width 16) (list #x66) '())
   extra-prefixes
   (let ([rex (make-rex (= width 64) regs
                        (rm-encoding-rex-r rm-enc)
                        (rm-encoding-rex-x rm-enc)
                        (rm-encoding-rex-b rm-enc))])
     (if rex (list rex) '()))
   opcode
   (list (rm-encoding-modrm rm-enc))
   (if (rm-encoding-sib rm-enc) (list (rm-encoding-sib rm-enc)) '())
   (rm-encoding-disp rm-enc)
   imm))

(define (emit-rm width regs rm-enc opcode [imm '()])
  (emit-rm-with-prefixes width regs rm-enc opcode imm '()))

(define (rm-width op)
  (cond
    [(reg? op) (reg-width op)]
    [(mem? op) (mem-width op)]
    [else (error 'rm-width "expected register or memory operand: ~e" op)]))

(define (rm-operand? op)
  (or (symbol? op) (reg? op) (mem-form? op) (mem? op)))

(define (parse-rm op)
  (cond
    [(mem? op) op]
    [(mem-form? op) (parse-mem op)]
    [(or (reg? op) (symbol? op))
     (define r (if (reg? op) op (lookup-register op)))
     (unless (gpr-register? r)
       (error 'parse-rm "expected GPR or memory, got XMM register: ~e" op))
     r]
    [else (error 'parse-rm "expected register or memory operand: ~e" op)]))

(define (parse-reg op)
  (define r (cond
              [(reg? op) op]
              [(symbol? op) (lookup-register op #f)]
              [else #f]))
  (cond
    [(and r (gpr-register? r)) r]
    [(and r (xmm-register? r))
     (error 'parse-reg "expected GPR, got XMM register: ~e" op)]
    [else (error 'parse-reg "expected register operand: ~e" op)]))

(define (parse-xmm op)
  (define r (cond
              [(reg? op) op]
              [(symbol? op) (lookup-register op #f)]
              [else #f]))
  (cond
    [(and r (xmm-register? r)) r]
    [(and r (gpr-register? r))
     (error 'parse-xmm "expected XMM register, got GPR: ~e" op)]
    [else (error 'parse-xmm "expected XMM register: ~e" op)]))

(define (parse-xmm-or-mem op)
  (cond
    [(mem? op) op]
    [(mem-form? op) (parse-mem op)]
    [(or (reg? op) (symbol? op)) (parse-xmm op)]
    [else (error 'parse-xmm-or-mem "expected XMM register or memory: ~e" op)]))

(define (immediate-value op)
  (cond
    [(exact-integer? op) op]
    [(and (form? op) (memq (car op) '(imm8 imm16 imm32 imm64)) (= 2 (length op)))
     (cadr op)]
    [else #f]))

(define (immediate-form op)
  (and (form? op) (memq (car op) '(imm8 imm16 imm32 imm64)) (= 2 (length op))
       (car op)))

(define (symbolic-immediate? op)
  (and (address-expr? op) (not (exact-integer? op))))

;; Choose one fixed immediate width for each unresolved address expression.
;; Layout and encode must agree on the form, so the choice is made once, here,
;; from the instruction and its operands -- never from the final value.
(define (choose-symbolic-immediate-forms name operands)
  (define (wrap op)
    (if (symbolic-immediate? op) (list 'imm32 op) op))
  (cond
    [(eq? name 'prefix)
     (match operands
       [(list pname inner)
        (and (form? inner)
             (list pname (cons (car inner)
                               (choose-symbolic-immediate-forms (car inner) (cdr inner)))))]
       [_ operands])]
    [(memq name '(jmp-short jmp-near jcc-short jcc-near call-near))
     operands]
    [(eq? name 'mov)
     (match operands
       [(list dst src)
        (cond
          [(symbolic-immediate? src)
           (define dst* (and (rm-operand? dst) (parse-rm dst)))
           (list dst (if (and (reg? dst*) (= 64 (reg-width dst*)))
                         (list 'imm64 src)
                         (list 'imm32 src)))]
          [else operands])]
       [_ operands])]
    [else (map wrap operands)]))

;; ---------------------------------------------------------------------------
;; 条件码
;; ---------------------------------------------------------------------------

(define (cc-index cc)
  (case cc
    [(o) 0] [(no) 1]
    [(b) 2] [(ae) 3]
    [(e) 4] [(ne) 5]
    [(be) 6] [(a) 7]
    [(s) 8] [(ns) 9]
    [(p) 10] [(np) 11]
    [(l) 12] [(ge) 13]
    [(le) 14] [(g) 15]
    [else (error 'cc-index "unknown condition code: ~e" cc)]))

;; ---------------------------------------------------------------------------
;; 指令编码器
;; ---------------------------------------------------------------------------

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
  (append (if rex (list rex) '())
          (list #x0f opcode
                (bitwise-ior #b11000000
                             (arithmetic-shift
                              (bitwise-and (reg-index sr) #b111) 3)
                             (bitwise-and (reg-index gpr) #b111)))))

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
          (emit-rm width regs rm opcode))]

       [(and (reg? dst*) (mem? src*))
        (unless (= (reg-width dst*) (mem-width src*))
          (error 'encode-mov "register/memory widths do not match: ~e ~e" dst src))
        (emit-rm (reg-width dst*)
                 (list dst*) (encode-rm src* dst*)
                 (list (if (= (reg-width dst*) 8) #x8a #x8b)))]

       [(and (mem? dst*) (reg? src*))
        (unless (= (mem-width dst*) (reg-width src*))
          (error 'encode-mov "memory/register widths do not match: ~e ~e" dst src))
        (emit-rm (mem-width dst*)
                 (list src*) (encode-rm dst* src*)
                 (list (if (= (mem-width dst*) 8) #x88 #x89)))]

       [(and (reg? dst*) (immediate-value src))
        (let* ([value (immediate-value src)]
               [width (reg-width dst*)]
               [forced (immediate-form src)]
               [regs (list dst*)])
          (define (emit-imm8)
            (check-imm8 value 'encode-mov)
            (append (prefixes 8 regs 0 0 (if (>= (reg-index dst*) 8) 1 0))
                    (u8 (+ #xb0 (bitwise-and (reg-index dst*) #b111)))
                    (u8 value)))
          (define (emit-imm16)
            (check-imm16 value 'encode-mov)
            (append (prefixes 16 regs 0 0 (if (>= (reg-index dst*) 8) 1 0))
                    (u8 (+ #xb8 (bitwise-and (reg-index dst*) #b111)))
                    (u16 value)))
          (define (emit-imm32)
            (check-imm32 value 'encode-mov)
            (append (prefixes 32 regs 0 0 (if (>= (reg-index dst*) 8) 1 0))
                    (u8 (+ #xb8 (bitwise-and (reg-index dst*) #b111)))
                    (u32 value)))
          (define (emit-imm64)
            (unless (= width 64)
              (error 'encode-mov "imm64 needs a 64-bit destination: ~e" dst))
            (let ([rex (make-rex #t regs 0 0 (if (>= (reg-index dst*) 8) 1 0))])
              (append (if rex (list rex) '())
                      (u8 (+ #xb8 (bitwise-and (reg-index dst*) #b111)))
                      (u64 value))))
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
                    (emit-rm 64 regs rm '(#xc7) (u32 value)))]
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
             (emit-rm 8 regs (encode-rm dst* 0) '(#xc6) (u8 value))]
            [(16)
             (check-imm16 value 'encode-mov)
             (emit-rm 16 regs (encode-rm dst* 0) '(#xc7) (u16 value))]
            [(32)
             (check-imm32 value 'encode-mov)
             (emit-rm 32 regs (encode-rm dst* 0) '(#xc7) (u32 value))]
            [(64)
             (check-imm32/signed value 'encode-mov)
             (emit-rm 64 regs (encode-rm dst* 0) '(#xc7) (u32 value))]))]
       [else
        (error 'encode-mov "unsupported mov operands: ~e" operands)])]
    [_ (error 'encode-mov "mov takes two operands: ~e" operands)]))

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
        (emit-rm width (list src*) (encode-rm dst* src*) (list op-rm-reg))]
       [(and (reg? dst*) (mem? src))
        (define width (reg-width dst*))
        (unless (= width (mem-width src))
          (error 'encode-alu "operand widths do not match: ~e ~e" dst src))
        (emit-rm width (list dst*) (encode-rm src dst*) (list op-reg-rm))]
       [(immediate-value src)
        (define value (immediate-value src))
        (define width (rm-width dst*))
        (define regs (regs-in-op dst*))
        (define forced (immediate-form src))
        (define (small? x) (<= -128 x 127))
        (cond
          [(eq? forced 'imm8)
           (check-imm8 value 'encode-alu)
           (emit-rm width regs (encode-rm dst* digit)
                    (list (if (= width 8) #x80 #x83)) (u8 value))]
          [(eq? forced 'imm16)
           (check-imm16 value 'encode-alu)
           (emit-rm width regs (encode-rm dst* digit) '(#x81) (u16 value))]
          [(eq? forced 'imm32)
           (check-imm32 value 'encode-alu) ; 64-bit uses sign-extended imm32
           (emit-rm width regs (encode-rm dst* digit) '(#x81) (u32 value))]
          [(= width 8)
           (check-imm8 value 'encode-alu)
           (emit-rm 8 regs (encode-rm dst* digit) '(#x80) (u8 value))]
          [(small? value)
           (emit-rm width regs (encode-rm dst* digit) '(#x83) (u8 value))]
          [else
           (case width
             [(16)
              (check-imm16 value 'encode-alu)
              (emit-rm 16 regs (encode-rm dst* digit) '(#x81) (u16 value))]
             [(32)
              (check-imm32 value 'encode-alu)
              (emit-rm 32 regs (encode-rm dst* digit) '(#x81) (u32 value))]
             [(64)
              (check-imm32/signed value 'encode-alu)
              (emit-rm 64 regs (encode-rm dst* digit) '(#x81) (u32 value))]
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
     (emit-rm (reg-width dst*) (list dst*) (encode-rm src* dst*) '(#x8d))]
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
        (append (if (= width 16) (list #x66) '())
                (if rex (list rex) '())
                (u8 (+ #x50 (bitwise-and (reg-index r) #b111))))]
       [(immediate-value src)
        (define v (immediate-value src))
        (cond
          [(and (not (eq? (immediate-form src) 'imm8)) (<= -128 v 127))
           (bytes* '(#x6a) (u8 v))]
          [else
           (check-imm32/signed v 'encode-push)
           (bytes* '(#x68) (u32 v))])]
       [(or (mem? src) (mem-form? src))
        (define m (parse-rm src))
        (unless (mem? m) (error 'encode-push "bad push operand: ~e" src))
        (define width (mem-width m))
        (unless (memq width '(16 64))
          (error 'encode-push "push memory must be b16 or b64: ~e" src))
        ;; 64-bit push/pop has a 64-bit default operand size; do not emit
        ;; a redundant REX.W (GNU as and Loko's assembler both omit it).
        (emit-rm (if (= width 64) 32 16) (regs-in-op m) (encode-rm m 6) '(#xff))]
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
        (append (if (= width 16) (list #x66) '())
                (if rex (list rex) '())
                (u8 (+ #x58 (bitwise-and (reg-index r) #b111))))]
       [(or (mem? dst) (mem-form? dst))
        (define m (parse-rm dst))
        (unless (mem? m) (error 'encode-pop "bad pop operand: ~e" dst))
        (define width (mem-width m))
        (unless (memq width '(16 64))
          (error 'encode-pop "pop memory must be b16 or b64: ~e" dst))
        (emit-rm (if (= width 64) 32 16) (regs-in-op m) (encode-rm m 0) '(#x8f))]
       [else (error 'encode-pop "unsupported pop operand: ~e" dst)])]
    [_ (error 'encode-pop "pop takes one operand: ~e" operands)]))

(define (encode-jmp-short operands)
  (match operands
    [(list off)
     (check-s8 off 'encode-jmp-short)
     (bytes* '(#xeb) (u8 off))]
    [_ (error 'encode-jmp-short "jmp-short takes one offset: ~e" operands)]))

(define (encode-jmp-near operands)
  (match operands
    [(list off)
     (check-s32 off 'encode-jmp-near)
     (bytes* '(#xe9) (u32 off))]
    [_ (error 'encode-jmp-near "jmp-near takes one offset: ~e" operands)]))

(define (encode-jcc-short operands)
  (match operands
    [(list cc off)
     (check-s8 off 'encode-jcc-short)
     (bytes* (u8 (+ #x70 (cc-index cc))) (u8 off))]
    [_ (error 'encode-jcc-short "jcc-short takes cc and offset: ~e" operands)]))

(define (encode-jcc-near operands)
  (match operands
    [(list cc off)
     (check-s32 off 'encode-jcc-near)
     (bytes* '(#x0f) (u8 (+ #x80 (cc-index cc))) (u32 off))]
    [_ (error 'encode-jcc-near "jcc-near takes cc and offset: ~e" operands)]))

(define (encode-call-near operands)
  (match operands
    [(list off)
     (check-s32 off 'encode-call-near)
     (bytes* '(#xe8) (u32 off))]
    [_ (error 'encode-call-near "call-near takes one offset: ~e" operands)]))

(define (encode-indirect-transfer name opcode operands)
  (match operands
    [(list rm)
     (define rm* (parse-rm rm))
     (emit-rm 64 (regs-in-op rm*) (encode-rm rm* opcode) '(#xff))]
    [_ (error name "~a takes one operand: ~e" name operands)]))

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
        (emit-rm width (list src*) (encode-rm dst* src*) '(#x85))]
       [(immediate-value src)
        (define value (immediate-value src))
        (define width (rm-width dst*))
        (define regs (regs-in-op dst*))
        (case width
          [(8)
           (check-imm8 value 'encode-test)
           (emit-rm 8 regs (encode-rm dst* 0) '(#xf6) (u8 value))]
          [(16)
           (check-imm16 value 'encode-test)
           (emit-rm 16 regs (encode-rm dst* 0) '(#xf7) (u16 value))]
          [(32)
           (check-imm32 value 'encode-test)
           (emit-rm 32 regs (encode-rm dst* 0) '(#xf7) (u32 value))]
          [(64)
           (check-imm32/signed value 'encode-test)
           (emit-rm 64 regs (encode-rm dst* 0) '(#xf7) (u32 value))]
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
     (emit-rm width (regs-in-op rm*)
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
        (emit-rm width (regs-in-op rm*)
                 (encode-rm rm* digit)
                 (list (if (= width 8) #xd2 #xd3)))]
       [(immediate-value count)
        (define value (immediate-value count))
        (check-imm8 value 'encode-shift)
        (emit-rm width (regs-in-op rm*)
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
     (emit-rm width (regs-in-op src*)
              (encode-rm src* 5)
              (list (if (= width 8) #xf6 #xf7)))]
    [(list dst src)
     (define dst* (parse-reg dst))
     (define src* (parse-rm src))
     (define width (reg-width dst*))
     (unless (= width (rm-width src*))
       (error 'encode-imul "operand widths do not match: ~e ~e" dst src))
     (emit-rm width (list dst*) (encode-rm src* dst*) '(#x0f #xaf))]
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
        (emit-rm width (list dst*) (encode-rm src* dst*) '(#x6b) (u8 value))]
       [else
        (case width
          [(16)
           (check-imm16 value 'encode-imul)
           (emit-rm 16 (list dst*) (encode-rm src* dst*) '(#x69) (u16 value))]
          [(32)
           (check-imm32 value 'encode-imul)
           (emit-rm 32 (list dst*) (encode-rm src* dst*) '(#x69) (u32 value))]
          [(64)
           (check-imm32/signed value 'encode-imul)
           (emit-rm 64 (list dst*) (encode-rm src* dst*) '(#x69) (u32 value))])])]
    [_ (error 'encode-imul "imul takes 1, 2 or 3 operands: ~e" operands)]))

(define (encode-divide name operands)
  (match operands
    [(list rm)
     (define rm* (parse-rm rm))
     (define width (rm-width rm*))
     (define digit (case name [(div) 6] [(idiv) 7]
                         [else (error 'encode-divide "unknown divide: ~e" name)]))
     (emit-rm width (regs-in-op rm*)
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
     (emit-rm dw (list dst*) (encode-rm src* dst*) opcode)]
    [_ (error 'encode-mov-extend "~a takes two operands: ~e"
              (if signed? 'movsx 'movzx) operands)]))

(define (encode-setcc operands)
  (match operands
    [(list cc rm)
     (define rm* (parse-rm rm))
     (unless (= (rm-width rm*) 8)
       (error 'encode-setcc "setcc requires an 8-bit destination: ~e" rm))
     (emit-rm 8 (regs-in-op rm*)
              (encode-rm rm* 0)
              (list #x0f (+ #x90 (cc-index cc))))]
    [_ (error 'encode-setcc "setcc takes a condition and an operand: ~e" operands)]))

(define (encode-cmovcc operands)
  (match operands
    [(list cc dst src)
     (define dst* (parse-reg dst))
     (define src* (parse-rm src))
     (define width (reg-width dst*))
     (unless (memq width '(16 32 64))
       (error 'encode-cmovcc "cmovcc requires a 16/32/64-bit destination: ~e" dst))
     (unless (= width (rm-width src*))
       (error 'encode-cmovcc "operand widths do not match: ~e ~e" dst src))
     (emit-rm width (list dst*) (encode-rm src* dst*)
              (list #x0f (+ #x40 (cc-index cc))))]
    [_ (error 'encode-cmovcc "cmovcc takes cc, dst, src: ~e" operands)]))

(define (encode-cqo operands)
  (unless (null? operands) (error 'encode-cqo "cqo takes no operands: ~e" operands))
  '(#x48 #x99))

(define (encode-cdq operands)
  (unless (null? operands) (error 'encode-cdq "cdq takes no operands: ~e" operands))
  '(#x99))

(define (encode-ret operands)
  (unless (null? operands) (error 'encode-ret "ret takes no operands: ~e" operands))
  '(#xc3))

(define (encode-nop operands)
  (unless (null? operands) (error 'encode-nop "nop takes no operands: ~e" operands))
  '(#x90))

(define (encode-ud2 operands)
  (unless (null? operands) (error 'encode-ud2 "ud2 takes no operands: ~e" operands))
  '(#x0f #x0b))


;; ---------------------------------------------------------------------------
;; 系统 / 整数扩展
;; ---------------------------------------------------------------------------

(define (encode-cdqe operands)
  (unless (null? operands)
    (error 'encode-cdqe "cdqe takes no operands: ~e" operands))
  '(#x48 #x98))

(define (encode-bswap operands)
  (match operands
    [(list reg)
     (define r (parse-reg reg))
     (define width (reg-width r))
     (unless (memq width '(32 64))
       (error 'encode-bswap "bswap needs a 32/64-bit register: ~e" reg))
     (define rex (make-rex (= width 64) (list r) 0 0
                           (if (>= (reg-index r) 8) 1 0)))
     (append (if rex (list rex) '())
             (list #x0f (+ #xc8 (bitwise-and (reg-index r) #b111))))]
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
        (emit-rm width regs (encode-rm a* b*) (list (if (= width 8) #x86 #x87)))]
       [(and (reg? a*) (mem? b*))
        (define width (reg-width a*))
        (unless (= width (mem-width b*))
          (error 'encode-xchg "operand widths do not match: ~e ~e" a b))
        (emit-rm width regs (encode-rm b* a*) (list (if (= width 8) #x86 #x87)))]
       [(and (mem? a*) (reg? b*))
        (define width (reg-width b*))
        (unless (= width (mem-width a*))
          (error 'encode-xchg "operand widths do not match: ~e ~e" a b))
        (emit-rm width regs (encode-rm a* b*) (list (if (= width 8) #x86 #x87)))]
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
       [(bsf) (emit-rm width (list d) (encode-rm s d) '(#x0f #xbc))]
       [(bsr) (emit-rm width (list d) (encode-rm s d) '(#x0f #xbd))]
       [(popcnt) (emit-rm-with-prefixes width (list d) (encode-rm s d)
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
       [(eq? count 'cl) (emit-rm width regs (encode-rm d s) '(#x0f #xad))]
       [(immediate-value count)
        (define v (immediate-value count))
        (check-imm8 v 'encode-shrd)
        (emit-rm width regs (encode-rm d s) '(#x0f #xac) (u8 v))]
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
     (emit-rm width (append (regs-in-op d) (list s))
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
     (emit-rm width (regs-in-op r) (encode-rm r digit) '(#x0f #xc7))]
    [_ (error name "~a takes one operand: ~e" name operands)]))

(define (encode-clflush operands)
  (match operands
    [(list m)
     (define m* (parse-rm m))
     (unless (mem? m*) (error 'encode-clflush "clflush needs a memory operand: ~e" m))
     (emit-rm 8 (regs-in-op m*) (encode-rm m* 7) '(#x0f #xae))]
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
       [(port-reg? port) (append p (list (if (= width 8) #xec #xed)))]
       [(immediate-value port)
        (define v (immediate-value port))
        (unless (<= 0 v 255) (error 'encode-in "port immediate out of range: ~e" port))
        (append p (list (if (= width 8) #xe4 #xe5)) (u8 v))]
       [else (error 'encode-in "port must be dx or imm8: ~e" port)])]
    [_ (error 'encode-in "in takes dst, port: ~e" operands)]))

(define (encode-out operands)
  (match operands
    [(list port src)
     (define s (io-register src 'encode-out))
     (define width (reg-width s))
     (define p (if (= width 16) (list #x66) '()))
     (cond
       [(port-reg? port) (append p (list (if (= width 8) #xee #xef)))]
       [(immediate-value port)
        (define v (immediate-value port))
        (unless (<= 0 v 255) (error 'encode-out "port immediate out of range: ~e" port))
        (append p (list (if (= width 8) #xe6 #xe7)) (u8 v))]
       [else (error 'encode-out "port must be dx or imm8: ~e" port)])]
    [_ (error 'encode-out "out takes port, src: ~e" operands)]))

(define (make-fixed-encoder name bytes)
  (lambda (operands)
    (unless (null? operands)
      (error name "~a takes no operands: ~e" name operands))
    bytes))


;; ---------------------------------------------------------------------------
;; 前缀 / 字符串指令
;;
;; 前缀是一个独立的 form：
;;   (prefix lock (xadd ...))
;;   (prefix rep  (movs ...))
;; 它只加一个 legacy prefix 字节，真正的编码仍由内部指令决定。
;; ---------------------------------------------------------------------------

(define (prefix-byte pname)
  (case pname
    [(lock) #xf0]
    [(rep repz) #xf3]
    [(repne repnz) #xf2]
    [else (error 'encode-prefix "unknown instruction prefix: ~e" pname)]))

(define (encode-prefix operands)
  (match operands
    [(list pname inner)
     (unless (form? inner)
       (error 'encode-prefix "prefix body must be an instruction form: ~e" inner))
     (append (list (prefix-byte pname))
             (bytes->list (encode-instruction (car inner) (cdr inner))))]
    [_ (error 'encode-prefix "prefix takes name and instruction: ~e" operands)]))

(define (string-memory-width op who)
  (define m (parse-rm op))
  (unless (mem? m) (error who "string instruction needs a memory operand: ~e" op))
  (mem-width m))

(define (encode-movs operands)
  (match operands
    [(list dst src)
     (define w (string-memory-width dst 'encode-movs))
     (unless (= w (string-memory-width src 'encode-movs))
       (error 'encode-movs "operand widths do not match: ~e ~e" dst src))
     (case w
       [(8) '(#xa4)]
       [(16) '(#x66 #xa5)]
       [(32) '(#xa5)]
       [(64) '(#x48 #xa5)]
       [else (error 'encode-movs "unsupported movs width: ~e" w)])]
    [_ (error 'encode-movs "movs takes dst, src: ~e" operands)]))

(define (encode-stos operands)
  (match operands
    [(list dst src)
     (define w (string-memory-width dst 'encode-stos))
     (define s (parse-reg src))
     (unless (= w (reg-width s))
       (error 'encode-stos "operand widths do not match: ~e ~e" dst src))
     (case w
       [(8) '(#xaa)]
       [(16) '(#x66 #xab)]
       [(32) '(#xab)]
       [(64) '(#x48 #xab)]
       [else (error 'encode-stos "unsupported stos width: ~e" w)])]
    [_ (error 'encode-stos "stos takes dst, src: ~e" operands)]))

(define (string-port? x)
  (and (symbol? x) (eq? x 'dx)))

(define (encode-ins operands)
  (match operands
    [(list dst port)
     (unless (string-port? port)
       (error 'encode-ins "ins port must be dx: ~e" port))
     (define w (string-memory-width dst 'encode-ins))
     (case w
       [(8) '(#x6c)]
       [(16) '(#x66 #x6d)]
       [(32) '(#x6d)]
       [else (error 'encode-ins "ins supports only b8/b16/b32: ~e" w)])]
    [_ (error 'encode-ins "ins takes dst, dx: ~e" operands)]))

(define (encode-outs operands)
  (match operands
    [(list port src)
     (unless (string-port? port)
       (error 'encode-outs "outs port must be dx: ~e" port))
     (define w (string-memory-width src 'encode-outs))
     (case w
       [(8) '(#x6e)]
       [(16) '(#x66 #x6f)]
       [(32) '(#x6f)]
       [else (error 'encode-outs "outs supports only b8/b16/b32: ~e" w)])]
    [_ (error 'encode-outs "outs takes dx, src: ~e" operands)]))


;; ---------------------------------------------------------------------------
;; SSE / XMM
;;
;; XMM 操作数的宽度是 128，但 128 不是 x86 的 operand-size 前缀。
;; 这些编码器自己决定 mandatory prefix（F3/66/F2）和 REX.W。
;; ---------------------------------------------------------------------------

(define (xmm-operand? x)
  (define r (cond
              [(reg? x) x]
              [(symbol? x) (lookup-register x #f)]
              [else #f]))
  (and r (xmm-register? r)))

(define (gpr-operand? x)
  (define r (cond
              [(reg? x) x]
              [(symbol? x) (lookup-register x #f)]
              [else #f]))
  (and r (gpr-register? r)))

(define (check-mem-width op width who)
  (when (and (mem? op) (not (= (mem-width op) width)))
    (error who "memory width must be b~a: ~e" width op)))

(define (emit-sse prefix width regs rm-enc opcode [imm '()])
  (emit-rm-with-prefixes width regs rm-enc opcode imm prefix))

(define (encode-movss operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (define s (parse-xmm-or-mem src))
        (check-mem-width s 32 'encode-movss)
        (emit-sse (list #xf3) 32 (list d) (encode-rm s d) '(#x0f #x10))]
       [(or (mem? dst) (mem-form? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 32 'encode-movss)
        (emit-sse (list #xf3) 32 (list s) (encode-rm d s) '(#x0f #x11))]
       [else (error 'encode-movss "unsupported movss operands: ~e" operands)])]
    [_ (error 'encode-movss "movss takes two operands: ~e" operands)]))

(define (encode-movd operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (define s (parse-rm src))
        (check-mem-width s 32 'encode-movd)
        (unless (= 32 (if (mem? s) (mem-width s) (reg-width s)))
          (error 'encode-movd "movd source must be 32 bits: ~e" src))
        (emit-sse (list #x66) 32 (list d) (encode-rm s d) '(#x0f #x6e))]
       [(or (mem? dst) (mem-form? dst) (gpr-operand? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 32 'encode-movd)
        (unless (= 32 (if (mem? d) (mem-width d) (reg-width d)))
          (error 'encode-movd "movd destination must be 32 bits: ~e" dst))
        (emit-sse (list #x66) 32 (list s) (encode-rm d s) '(#x0f #x7e))]
       [else (error 'encode-movd "unsupported movd operands: ~e" operands)])]
    [_ (error 'encode-movd "movd takes two operands: ~e" operands)]))

(define (encode-movq operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (cond
          [(or (xmm-operand? src) (mem? src) (mem-form? src))
           (define s (parse-xmm-or-mem src))
           (check-mem-width s 64 'encode-movq)
           (emit-sse (list #xf3) 32 (list d) (encode-rm s d) '(#x0f #x7e))]
          [(gpr-operand? src)
           (define s (parse-reg src))
           (unless (= 64 (reg-width s))
             (error 'encode-movq "movq GPR source must be 64 bits: ~e" src))
           (emit-sse (list #x66) 64 (list d) (encode-rm s d) '(#x0f #x6e))]
          [else (error 'encode-movq "unsupported movq source: ~e" src)])]
       [(or (mem? dst) (mem-form? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 64 'encode-movq)
        (emit-sse (list #x66) 32 (list s) (encode-rm d s) '(#x0f #xd6))]
       [(gpr-operand? dst)
        (define d (parse-reg dst))
        (unless (= 64 (reg-width d))
          (error 'encode-movq "movq GPR destination must be 64 bits: ~e" dst))
        (define s (parse-xmm src))
        (emit-sse (list #x66) 64 (list s) (encode-rm d s) '(#x0f #x7e))]
       [else (error 'encode-movq "unsupported movq operands: ~e" operands)])]
    [_ (error 'encode-movq "movq takes two operands: ~e" operands)]))

(define (encode-movdqa operands)
  (match operands
    [(list dst src)
     (cond
       [(xmm-operand? dst)
        (define d (parse-xmm dst))
        (define s (parse-xmm-or-mem src))
        (check-mem-width s 128 'encode-movdqa)
        (emit-sse (list #x66) 32 (list d) (encode-rm s d) '(#x0f #x6f))]
       [(or (mem? dst) (mem-form? dst))
        (define d (parse-rm dst))
        (define s (parse-xmm src))
        (check-mem-width d 128 'encode-movdqa)
        (emit-sse (list #x66) 32 (list s) (encode-rm d s) '(#x0f #x7f))]
       [else (error 'encode-movdqa "unsupported movdqa operands: ~e" operands)])]
    [_ (error 'encode-movdqa "movdqa takes two operands: ~e" operands)]))

(define (encode-sse-scalar name opcode prefix mem-width operands)
  (match operands
    [(list dst src)
     (define d (parse-xmm dst))
     (define s (parse-xmm-or-mem src))
     (check-mem-width s mem-width name)
     (emit-sse prefix 32 (list d) (encode-rm s d) (list #x0f opcode))]
    [_ (error name "~a takes two operands: ~e" name operands)]))

(define (encode-roundss operands)
  (match operands
    [(list dst src imm)
     (define d (parse-xmm dst))
     (define s (parse-xmm-or-mem src))
     (check-mem-width s 32 'encode-roundss)
     (define v (or (immediate-value imm)
                   (error 'encode-roundss "roundss immediate must be an integer: ~e" imm)))
     (check-imm8 v 'encode-roundss)
     (emit-sse (list #x66) 32 (list d) (encode-rm s d) '(#x0f #x3a #x0a) (u8 v))]
    [_ (error 'encode-roundss "roundss takes dst, src, imm8: ~e" operands)]))

(define (encode-cvtsi2ss operands)
  (match operands
    [(list dst src)
     (define d (parse-xmm dst))
     (define s (parse-rm src))
     (define width (if (mem? s) (mem-width s) (reg-width s)))
     (unless (memq width '(32 64))
       (error 'encode-cvtsi2ss "source must be 32/64 bits: ~e" src))
     (emit-sse (list #xf3) (if (= width 64) 64 32)
               (list d) (encode-rm s d) '(#x0f #x2a))]
    [_ (error 'encode-cvtsi2ss "cvtsi2ss takes dst, src: ~e" operands)]))

(define (encode-mxcsr name digit operands)
  (match operands
    [(list m)
     (define m* (parse-rm m))
     (unless (mem? m*) (error name "~a needs a memory operand: ~e" name m))
     (check-mem-width m* 32 name)
     (emit-sse '() 32 (regs-in-op m*) (encode-rm m* digit) '(#x0f #xae))]
    [_ (error name "~a takes one memory operand: ~e" name operands)]))


;; ---------------------------------------------------------------------------
;; PC 系统描述符 / MSR
;; ---------------------------------------------------------------------------

(define (encode-descriptor-table name opcode digit operands)
  (match operands
    [(list m)
     (define m* (parse-rm m))
     (unless (mem? m*)
       (error name "~a needs a memory operand: ~e" name m))
     (emit-rm-with-prefixes 32 (regs-in-op m*) (encode-rm m* digit)
                   (list #x0f opcode) '() '())]
    [_ (error name "~a takes one memory operand: ~e" name operands)]))

(define (encode-system-rm16 name digit operands)
  (match operands
    [(list rm)
     (define r (parse-rm rm))
     (define width (if (mem? r) (mem-width r) (reg-width r)))
     (unless (= width 16)
       (error name "~a needs a 16-bit operand: ~e" name rm))
     (emit-rm-with-prefixes 32 (regs-in-op r) (encode-rm r digit)
                   '(#x0f #x00) '() '())]
    [_ (error name "~a takes one operand: ~e" name operands)]))

;; ---------------------------------------------------------------------------
;; 表
;; ---------------------------------------------------------------------------

;; arity 是固定操作数个数；#f 表示可变元数（例如 imul 的 1/2/3 形式）。
(struct insn-def (arity encode) #:transparent)

(define instruction-table
  (hash
   'mov        (insn-def 2 encode-mov)
   'add        (insn-def 2 (lambda (ops) (encode-alu 'add ops)))
   'sub        (insn-def 2 (lambda (ops) (encode-alu 'sub ops)))
   'and        (insn-def 2 (lambda (ops) (encode-alu 'and ops)))
   'or         (insn-def 2 (lambda (ops) (encode-alu 'or ops)))
   'xor        (insn-def 2 (lambda (ops) (encode-alu 'xor ops)))
   'cmp        (insn-def 2 (lambda (ops) (encode-alu 'cmp ops)))
   'lea        (insn-def 2 encode-lea)
   'push       (insn-def 1 encode-push)
   'pop        (insn-def 1 encode-pop)
   'jmp-short  (insn-def 1 encode-jmp-short)
   'jmp-near   (insn-def 1 encode-jmp-near)
   'jcc-short  (insn-def 2 encode-jcc-short)
   'jcc-near   (insn-def 2 encode-jcc-near)
   'call-near  (insn-def 1 encode-call-near)
   'call-indirect (insn-def 1 (lambda (ops) (encode-indirect-transfer 'call-indirect 2 ops)))
   'jmp-indirect  (insn-def 1 (lambda (ops) (encode-indirect-transfer 'jmp-indirect 4 ops)))
   'test       (insn-def 2 encode-test)
   'inc        (insn-def 1 (lambda (ops) (encode-unary 'inc ops)))
   'dec        (insn-def 1 (lambda (ops) (encode-unary 'dec ops)))
   'not        (insn-def 1 (lambda (ops) (encode-unary 'not ops)))
   'neg        (insn-def 1 (lambda (ops) (encode-unary 'neg ops)))
   'shl        (insn-def 2 (lambda (ops) (encode-shift 'shl ops)))
   'shr        (insn-def 2 (lambda (ops) (encode-shift 'shr ops)))
   'sar        (insn-def 2 (lambda (ops) (encode-shift 'sar ops)))
   'rol        (insn-def 2 (lambda (ops) (encode-shift 'rol ops)))
   'ror        (insn-def 2 (lambda (ops) (encode-shift 'ror ops)))
   'rcl        (insn-def 2 (lambda (ops) (encode-shift 'rcl ops)))
   'rcr        (insn-def 2 (lambda (ops) (encode-shift 'rcr ops)))
   'imul       (insn-def #f encode-imul)
   'div        (insn-def 1 (lambda (ops) (encode-divide 'div ops)))
   'idiv       (insn-def 1 (lambda (ops) (encode-divide 'idiv ops)))
   'movzx      (insn-def 2 (lambda (ops) (encode-mov-extend #f ops)))
   'movsx      (insn-def 2 (lambda (ops) (encode-mov-extend #t ops)))
   'setcc      (insn-def 2 encode-setcc)
   'cmovcc     (insn-def 3 encode-cmovcc)
   'xchg       (insn-def 2 encode-xchg)
   'bswap      (insn-def 1 encode-bswap)
   'bsf        (insn-def 2 (lambda (ops) (encode-bit-scan 'bsf ops)))
   'bsr        (insn-def 2 (lambda (ops) (encode-bit-scan 'bsr ops)))
   'popcnt     (insn-def 2 (lambda (ops) (encode-bit-scan 'popcnt ops)))
   'shrd       (insn-def 3 encode-shrd)
   'cmpxchg    (insn-def 2 (lambda (ops)
                             (encode-binary-atomic 'cmpxchg
                                                   '(#x0f #xb0) '(#x0f #xb1) ops)))
   'xadd       (insn-def 2 (lambda (ops)
                             (encode-binary-atomic 'xadd
                                                   '(#x0f #xc0) '(#x0f #xc1) ops)))
   'rdrand     (insn-def 1 (lambda (ops) (encode-random-seed 'rdrand 6 ops)))
   'rdseed     (insn-def 1 (lambda (ops) (encode-random-seed 'rdseed 7 ops)))
   'clflush    (insn-def 1 encode-clflush)
   'in         (insn-def 2 encode-in)
   'out        (insn-def 2 encode-out)
   'prefix     (insn-def 2 encode-prefix)
   'movss      (insn-def 2 encode-movss)
   'movd       (insn-def 2 encode-movd)
   'movq       (insn-def 2 encode-movq)
   'movdqa     (insn-def 2 encode-movdqa)
   'addss      (insn-def 2 (lambda (ops) (encode-sse-scalar 'addss #x58 (list #xf3) 32 ops)))
   'subss      (insn-def 2 (lambda (ops) (encode-sse-scalar 'subss #x5c (list #xf3) 32 ops)))
   'mulss      (insn-def 2 (lambda (ops) (encode-sse-scalar 'mulss #x59 (list #xf3) 32 ops)))
   'divss      (insn-def 2 (lambda (ops) (encode-sse-scalar 'divss #x5e (list #xf3) 32 ops)))
   'minss      (insn-def 2 (lambda (ops) (encode-sse-scalar 'minss #x5d (list #xf3) 32 ops)))
   'maxss      (insn-def 2 (lambda (ops) (encode-sse-scalar 'maxss #x5f (list #xf3) 32 ops)))
   'sqrtss     (insn-def 2 (lambda (ops) (encode-sse-scalar 'sqrtss #x51 (list #xf3) 32 ops)))
   'ucomiss    (insn-def 2 (lambda (ops) (encode-sse-scalar 'ucomiss #x2e '() 32 ops)))
   'cvtss2sd   (insn-def 2 (lambda (ops) (encode-sse-scalar 'cvtss2sd #x5a (list #xf3) 32 ops)))
   'cvtsd2ss   (insn-def 2 (lambda (ops) (encode-sse-scalar 'cvtsd2ss #x5a (list #xf2) 64 ops)))
   'roundss    (insn-def 3 encode-roundss)
   'cvtsi2ss   (insn-def 2 encode-cvtsi2ss)
   'ldmxcsr    (insn-def 1 (lambda (ops) (encode-mxcsr 'ldmxcsr 2 ops)))
   'stmxcsr    (insn-def 1 (lambda (ops) (encode-mxcsr 'stmxcsr 3 ops)))
   'xorps      (insn-def 2 (lambda (ops) (encode-sse-scalar 'xorps #x57 '() 128 ops)))
   'xorpd      (insn-def 2 (lambda (ops) (encode-sse-scalar 'xorpd #x57 (list #x66) 128 ops)))
   'orps       (insn-def 2 (lambda (ops) (encode-sse-scalar 'orps #x56 '() 128 ops)))
   'lgdt       (insn-def 1 (lambda (ops) (encode-descriptor-table 'lgdt #x01 2 ops)))
   'lidt       (insn-def 1 (lambda (ops) (encode-descriptor-table 'lidt #x01 3 ops)))
   'lldt       (insn-def 1 (lambda (ops) (encode-system-rm16 'lldt 2 ops)))
   'ltr        (insn-def 1 (lambda (ops) (encode-system-rm16 'ltr 3 ops)))
   'rdmsr      (insn-def 0 (make-fixed-encoder 'rdmsr '(#x0f #x32)))
   'wrmsr      (insn-def 0 (make-fixed-encoder 'wrmsr '(#x0f #x30)))
   'swapgs     (insn-def 0 (make-fixed-encoder 'swapgs '(#x0f #x01 #xf8)))
   'sysretq    (insn-def 0 (make-fixed-encoder 'sysretq '(#x48 #x0f #x07)))
   'iretq      (insn-def 0 (make-fixed-encoder 'iretq '(#x48 #xcf)))
   'movs       (insn-def 2 encode-movs)
   'stos       (insn-def 2 encode-stos)
   'ins        (insn-def 2 encode-ins)
   'outs       (insn-def 2 encode-outs)
   'cdqe       (insn-def 0 (make-fixed-encoder 'cdqe '(#x48 #x98)))
   'cpuid      (insn-def 0 (make-fixed-encoder 'cpuid '(#x0f #xa2)))
   'rdtsc      (insn-def 0 (make-fixed-encoder 'rdtsc '(#x0f #x31)))
   'rdtscp     (insn-def 0 (make-fixed-encoder 'rdtscp '(#x0f #x01 #xf9)))
   'syscall    (insn-def 0 (make-fixed-encoder 'syscall '(#x0f #x05)))
   'clc        (insn-def 0 (make-fixed-encoder 'clc '(#xf8)))
   'stc        (insn-def 0 (make-fixed-encoder 'stc '(#xf9)))
   'cld        (insn-def 0 (make-fixed-encoder 'cld '(#xfc)))
   'cli        (insn-def 0 (make-fixed-encoder 'cli '(#xfa)))
   'sti        (insn-def 0 (make-fixed-encoder 'sti '(#xfb)))
   'hlt        (insn-def 0 (make-fixed-encoder 'hlt '(#xf4)))
   'pause      (insn-def 0 (make-fixed-encoder 'pause '(#xf3 #x90)))
   'pushfq     (insn-def 0 (make-fixed-encoder 'pushfq '(#x9c)))
   'popfq      (insn-def 0 (make-fixed-encoder 'popfq '(#x9d)))
   'mfence     (insn-def 0 (make-fixed-encoder 'mfence '(#x0f #xae #xf0)))
   'lfence     (insn-def 0 (make-fixed-encoder 'lfence '(#x0f #xae #xe8)))
   'sfence     (insn-def 0 (make-fixed-encoder 'sfence '(#x0f #xae #xf8)))
   'cqo        (insn-def 0 encode-cqo)
   'cdq        (insn-def 0 encode-cdq)
   'ret        (insn-def 0 encode-ret)
   'nop        (insn-def 0 encode-nop)
   'ud2        (insn-def 0 encode-ud2)))

(define (known-instruction? name) (hash-has-key? instruction-table name))

(define (instruction-arity name)
  (define d (hash-ref instruction-table name #f))
  (and d (insn-def-arity d)))

(define (encode-instruction name operands)
  (define d (hash-ref instruction-table name #f))
  (unless d (error 'encode-instruction "unknown amd64 instruction: ~e" name))
  (define arity (insn-def-arity d))
  (when (and arity (not (= (length operands) arity)))
    (error 'encode-instruction "~a expects ~a operand(s), got ~a: ~e"
           name arity (length operands) operands))
  (list->bytevector ((insn-def-encode d) operands)))

;; 布局阶段用的尺寸。符号 displacement 暂时拒绝: 还没有把"必须 disp32"
;; 这个选择固定到操作数里。等 layout/normalize 接上后再补。
(define (operand-for-sizing op)
  (cond
    [(mem-form? op) (operand-for-sizing (parse-mem op))]
    [(and (mem? op) (not (exact-integer? (mem-disp op))))
     (case (mem-disp-width op)
       [(32) (struct-copy mem op [disp #x1000])]
       [else
        (error 'instruction-size
               "memory displacement must be resolved before sizing: ~e" op)])]
    ;; Prepared immediate wrapper with an unresolved payload.
    [(and (immediate-form op) (symbolic-immediate? (cadr op)))
     (list (immediate-form op) #x1000)]
    [(and (address-expr? op) (not (exact-integer? op)))
     (list 'imm32 #x1000)]
    [else op]))

(define (branch-operands-for-sizing name operands)
  (case name
    [(jcc-short jcc-near)
     (list (car operands) 0)]
    [(jmp-short jmp-near call-near)
     (list 0)]
    [else operands]))

(define (instruction-size name operands)
  (cond
    [(eq? name 'prefix)
     (match operands
       [(list pname inner)
        (unless (form? inner)
          (error 'instruction-size "prefix body must be an instruction form: ~e" inner))
        (+ 1 (instruction-size (car inner) (cdr inner)))]
       [_ (error 'instruction-size "prefix takes name and instruction: ~e" operands)])]
    [else
     (define branch? (memq name '(jmp-short jmp-near
                                  jcc-short jcc-near
                                  call-near)))
     (define prepared (choose-symbolic-immediate-forms name operands))
     (define ops (if branch?
                     (branch-operands-for-sizing name prepared)
                     (map operand-for-sizing prepared)))
     (bytes-length (encode-instruction name ops))]))
