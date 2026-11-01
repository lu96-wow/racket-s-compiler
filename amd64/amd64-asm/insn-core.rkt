#lang racket
;;; amd64/amd64-asm/insn-core.rkt
;;;
;;; Shared low-level amd64 encoding facts: ModR/M + SIB + displacement,
;;; REX/prefix assembly, integer byte helpers and immediate range checks.
;;; Both the handwritten special encoders and the generated NASM table
;;; interpreter use this module, so size and bytes cannot drift apart.

(require "sexp.rkt"
         "registers.rkt")

(provide (struct-out rm-encoding)
         reg-field-index
         reg-field-rex-r
         reg-rm-modrm
         encode-rm
         encode-mem-rm
         u8 u16 u32 u64
         bytes* list->bytevector
         check-s8 check-s32 check-u32 check-s16 check-u16
         check-imm8 check-imm16 check-imm32 check-imm32/signed
         regs-in-op
         make-rex
         prefixes
         emit-rm-with-prefixes
         emit-rm)

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
  (define rex-b (if (and base (>= (reg-index base) 8)) 1 0))
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
                  rex-b
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

