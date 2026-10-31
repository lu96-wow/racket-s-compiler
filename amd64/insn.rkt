#lang racket
;;; amd64/insn.rkt
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
         known-instruction?)

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
  (when (and index (memq (reg-name index) '(rsp r12)))
    (error 'encode-mem-rm "rsp/r12 cannot be used as an index register: ~e" index-name))
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
  (define rex-b-index (if (and index (>= (reg-index index) 8)) 1 0))
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
                  rex-b-index
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
                  (bitwise-ior rex-b-base rex-b-index)
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

(define (emit-rm width regs rm-enc opcode [imm '()])
  (append
   (if (rm-encoding-seg rm-enc) (list (rm-encoding-seg rm-enc)) '())
   (prefixes width regs
             (rm-encoding-rex-r rm-enc)
             (rm-encoding-rex-x rm-enc)
             (rm-encoding-rex-b rm-enc))
   opcode
   (list (rm-encoding-modrm rm-enc))
   (if (rm-encoding-sib rm-enc) (list (rm-encoding-sib rm-enc)) '())
   (rm-encoding-disp rm-enc)
   imm))

(define (rm-width op)
  (cond
    [(reg? op) (reg-width op)]
    [(mem? op) (mem-width op)]
    [else (error 'rm-width "expected register or memory operand: ~e" op)]))

(define (rm-operand? op)
  (or (symbol? op) (reg? op) (mem-form? op) (mem? op)))

(define (parse-rm op)
  (cond
    [(reg? op) op]
    [(mem? op) op]
    [(symbol? op) (lookup-register op)]
    [(mem-form? op) (parse-mem op)]
    [else (error 'parse-rm "expected register or memory operand: ~e" op)]))

(define (parse-reg op)
  (define r (and (symbol? op) (lookup-register op #f)))
  (cond
    [(reg? op) op]
    [r r]
    [else (error 'parse-reg "expected register operand: ~e" op)]))

(define (imm-value op)
  (cond
    [(exact-integer? op) op]
    [(and (form? op) (memq (car op) '(imm8 imm16 imm32 imm64)) (= 2 (length op)))
     (cadr op)]
    [else #f]))

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

(define (encode-mov operands)
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
        (emit-rm (reg-width dst*) (list dst*) (encode-rm src* dst*) '(#x8b))]

       [(and (mem? dst*) (reg? src*))
        (unless (= (mem-width dst*) (reg-width src*))
          (error 'encode-mov "memory/register widths do not match: ~e ~e" dst src))
        (emit-rm (mem-width dst*) (list src*) (encode-rm dst* src*) '(#x89))]

       [(and (reg? dst*) (imm-value src))
        (let* ([value (imm-value src)]
               [width (reg-width dst*)]
               [regs (list dst*)])
          (case width
            [(8)
             (check-imm8 value 'encode-mov)
             (let ([rex (make-rex #f regs 0 0 (if (>= (reg-index dst*) 8) 1 0))])
               (append (if rex (list rex) '())
                       (u8 (+ #xb0 (bitwise-and (reg-index dst*) #b111)))
                       (u8 value)))]
            [(16)
             (check-imm16 value 'encode-mov)
             (append (prefixes 16 regs 0 0 (if (>= (reg-index dst*) 8) 1 0))
                     (u8 (+ #xb8 (bitwise-and (reg-index dst*) #b111)))
                     (u16 value))]
            [(32)
             (check-imm32 value 'encode-mov)
             (append (prefixes 32 regs 0 0 (if (>= (reg-index dst*) 8) 1 0))
                     (u8 (+ #xb8 (bitwise-and (reg-index dst*) #b111)))
                     (u32 value))]
            [(64)
             (cond
               [(<= (- (expt 2 31)) value (sub1 (expt 2 31)))
                (check-imm32/signed value 'encode-mov)
                (let ([rm (encode-rm dst* 0)])
                  (emit-rm 64 regs rm '(#xc7) (u32 value)))]
               [(<= 0 value (sub1 (expt 2 32)))
                ;; mov r32, imm32 zero-extends to r64
                (append (prefixes 32 regs 0 0 (if (>= (reg-index dst*) 8) 1 0))
                        (u8 (+ #xb8 (bitwise-and (reg-index dst*) #b111)))
                        (u32 value))]
               [else
                (let ([rex (make-rex #t regs 0 0 (if (>= (reg-index dst*) 8) 1 0))])
                  (append (if rex (list rex) '())
                          (u8 (+ #xb8 (bitwise-and (reg-index dst*) #b111)))
                          (u64 value)))])]))]
       [(and (mem? dst*) (imm-value src))
        (let* ([value (imm-value src)]
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
       [(imm-value src)
        (define value (imm-value src))
        (define width (rm-width dst*))
        (define regs (regs-in-op dst*))
        (define (small? x) (<= -128 x 127))
        (cond
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
     (define r (parse-reg src))
     (define width (reg-width r))
     (unless (memq width '(16 64))
       (error 'encode-push "push register must be 16 or 64 bits: ~e" src))
     (define rex (make-rex #f (list r) 0 0 (if (>= (reg-index r) 8) 1 0)))
     (append (if (= width 16) (list #x66) '())
             (if rex (list rex) '())
             (u8 (+ #x50 (bitwise-and (reg-index r) #b111))))]
    [_ (error 'encode-push "push takes one register: ~e" operands)]))

(define (encode-pop operands)
  (match operands
    [(list dst)
     (define r (parse-reg dst))
     (define width (reg-width r))
     (unless (memq width '(16 64))
       (error 'encode-pop "pop register must be 16 or 64 bits: ~e" dst))
     (define rex (make-rex #f (list r) 0 0 (if (>= (reg-index r) 8) 1 0)))
     (append (if (= width 16) (list #x66) '())
             (if rex (list rex) '())
             (u8 (+ #x58 (bitwise-and (reg-index r) #b111))))]
    [_ (error 'encode-pop "pop takes one register: ~e" operands)]))

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

(define (encode-indirect opcode operands name)
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
       [(imm-value src)
        (define value (imm-value src))
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
     (define value (or (imm-value count)
                       (error 'encode-shift "shift count must be an immediate: ~e" count)))
     (check-imm8 value 'encode-shift)
     (define digit (case name [(shl) 4] [(shr) 5] [(sar) 7]
                          [else (error 'encode-shift "unknown shift: ~e" name)]))
     (emit-rm width (regs-in-op rm*)
              (encode-rm rm* digit)
              (list (if (= width 8) #xc0 #xc1))
              (u8 value))]
    [_ (error 'encode-shift "~a takes two operands: ~e" name operands)]))

(define (encode-imul operands)
  (match operands
    [(list dst src)
     (define dst* (parse-reg dst))
     (define src* (parse-rm src))
     (define width (reg-width dst*))
     (unless (= width (rm-width src*))
       (error 'encode-imul "operand widths do not match: ~e ~e" dst src))
     (emit-rm width (list dst*) (encode-rm src* dst*) '(#x0f #xaf))]
    [_ (error 'encode-imul "imul takes two operands: ~e" operands)]))

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

(define (encode-movx signed? operands)
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
         [else (error 'encode-movx "unsupported width combination: ~e -> ~e" sw dw)]))
     (emit-rm dw (list dst*) (encode-rm src* dst*) opcode)]
    [_ (error 'encode-movx "~a takes two operands: ~e"
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
;; 表
;; ---------------------------------------------------------------------------

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
   'call-indirect (insn-def 1 (lambda (ops) (encode-indirect 2 ops 'call-indirect)))
   'jmp-indirect  (insn-def 1 (lambda (ops) (encode-indirect 4 ops 'jmp-indirect)))
   'test       (insn-def 2 encode-test)
   'inc        (insn-def 1 (lambda (ops) (encode-unary 'inc ops)))
   'dec        (insn-def 1 (lambda (ops) (encode-unary 'dec ops)))
   'not        (insn-def 1 (lambda (ops) (encode-unary 'not ops)))
   'neg        (insn-def 1 (lambda (ops) (encode-unary 'neg ops)))
   'shl        (insn-def 2 (lambda (ops) (encode-shift 'shl ops)))
   'shr        (insn-def 2 (lambda (ops) (encode-shift 'shr ops)))
   'sar        (insn-def 2 (lambda (ops) (encode-shift 'sar ops)))
   'imul       (insn-def 2 encode-imul)
   'div        (insn-def 1 (lambda (ops) (encode-divide 'div ops)))
   'idiv       (insn-def 1 (lambda (ops) (encode-divide 'idiv ops)))
   'movzx      (insn-def 2 (lambda (ops) (encode-movx #f ops)))
   'movsx      (insn-def 2 (lambda (ops) (encode-movx #t ops)))
   'setcc      (insn-def 2 encode-setcc)
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
  (unless (= (length operands) (insn-def-arity d))
    (error 'encode-instruction "~a expects ~a operand(s), got ~a: ~e"
           name (insn-def-arity d) (length operands) operands))
  (list->bytevector ((insn-def-encode d) operands)))

;; 布局阶段用的尺寸。符号 displacement 暂时拒绝: 还没有把"必须 disp32"
;; 这个选择固定到操作数里。等 layout/normalize 接上后再补。
(define (size-safe-operand op)
  (cond
    [(mem-form? op) (size-safe-operand (parse-mem op))]
    [(and (mem? op) (not (exact-integer? (mem-disp op))))
     (case (mem-disp-width op)
       [(32) (struct-copy mem op [disp #x1000])]
       [else
        (error 'instruction-size
               "memory displacement must be resolved before sizing: ~e" op)])]
    [else op]))

(define (size-branch-operands name operands)
  (case name
    [(jcc-short jcc-near)
     (list (car operands) 0)]
    [(jmp-short jmp-near call-near)
     (list 0)]
    [else operands]))

(define (instruction-size name operands)
  (define branch? (memq name '(jmp-short jmp-near
                               jcc-short jcc-near
                               call-near)))
  (define ops (if branch?
                  (size-branch-operands name operands)
                  (map size-safe-operand operands)))
  (bytes-length (encode-instruction name ops)))
