#lang racket
;;; encode/encode.rkt
;;;
;;; layout-result / program-layout -> 字节。
;;;
;;; 第一版：
;;;   - 只编码 32-bit native 指令；
;;;   - little-endian；
;;;   - label 解析成相对偏移；
;;;   - 单函数 layout-result 里的 call-target 仍然报错；
;;;   - program-layout 里的 call-jal 已经解析成偏移，可以直接编码；
;;;   - 指令编码走 riscv-compiler/api.rkt（对外的唯一面），不直接碰它的内部模块。

(require racket/list
         "../core/sexp.rkt"
         "../ir/shape.rkt"
         "../layout/relax.rkt"
         "../layout/program.rkt"
         "../asm/code.rkt"
         "../data/data.rkt"
         "../link/reloc.rkt"
         "../../riscv-compiler/api.rkt")

(provide (struct-out encoded)
         (struct-out encoded-section)
         (struct-out encoded-program)
         encoded-size
         encoded-program-size
         encode-layout
         encode-program)

(struct encoded (bytes labels) #:transparent)

;; 每个段：code 的 labels 是相对本段起点的偏移；data 的 labels 为空。
(struct encoded-section (kind name base size labels) #:transparent)

(struct encoded-program
  (bytes sections origin relocations externs)
  #:transparent)

(define (encoded-size enc)
  (bytes-length (encoded-bytes enc)))

(define (encoded-program-size enc)
  (bytes-length (encoded-program-bytes enc)))

(define (encode-layout result #:xlen [xlen 64])
  (unless (layout-result? result)
    (error 'encode "expected a layout-result: ~e" result))
  (define-values (bytes labels relocations)
    (encode-items (layout-result-items result) #f xlen))
  (unless (null? relocations)
    (error 'encode "single layout-result cannot carry external relocations"))
  (encoded bytes labels))

(define (encode-program program #:xlen [xlen 64])
  (unless (program-layout? program)
    (error 'encode "expected a program-layout: ~e" program))
  (define chunks '())
  (define sections '())
  (define relocations '())
  (define offset 0)
  (for ([section (in-list (program-layout-sections program))])
    (define base
      (cond
        [(function-section? section) (function-section-base section)]
        [(raw-section? section) (raw-section-base section)]
        [(data-section? section) (data-section-base section)]
        [else (error 'encode "unknown program section: ~e" section)]))
    (when (> base offset)
      (set! chunks (cons (make-bytes (- base offset) 0) chunks))
      (set! offset base))
    (when (< base offset)
      (error 'encode "section ~a overlaps previous bytes" base))

    (cond
      [(function-section? section)
       (define-values (bytes labels section-relocs)
         (encode-items (function-section-items section)
                       (function-section-name section) xlen))
       (set! relocations (append relocations section-relocs))
       (unless (= (bytes-length bytes) (function-section-size section))
         (error 'encode
                "layout section ~a assumed ~a bytes, encoded ~a"
                (chain->string (function-section-name section))
                (function-section-size section)
                (bytes-length bytes)))
       (set! chunks (cons bytes chunks))
       (set! sections
             (cons (encoded-section 'code
                                    (function-section-name section)
                                    base
                                    (function-section-size section)
                                    labels)
                   sections))
       (set! offset (+ base (function-section-size section)))]

      [(raw-section? section)
       (define-values (bytes labels section-relocs)
         (encode-items (raw-section-items section)
                       (raw-section-name section) xlen))
       (set! relocations (append relocations section-relocs))
       (unless (= (bytes-length bytes) (raw-section-size section))
         (error 'encode
                "raw section ~a assumed ~a bytes, encoded ~a"
                (chain->string (raw-section-name section))
                (raw-section-size section)
                (bytes-length bytes)))
       (set! chunks (cons bytes chunks))
       (set! sections
             (cons (encoded-section 'raw
                                    (raw-section-name section)
                                    base
                                    (raw-section-size section)
                                    labels)
                   sections))
       (set! offset (+ base (raw-section-size section)))]

      [(data-section? section)
       (define bytes (list->bytes (data-section-bytes section)))
       (for ([reloc (in-list (data-section-external-relocations section))])
         (set! relocations
               (append relocations
                       (list (relocation (data-section-name section)
                                         (data-relocation-offset reloc)
                                         'abs
                                         (data-relocation-target reloc)
                                         (data-relocation-addend reloc)
                                         (data-relocation-width reloc)
                                         #f)))))
       (unless (= (bytes-length bytes) (data-section-size section))
         (error 'encode
                "data section ~a assumed ~a bytes, encoded ~a"
                (chain->string (data-section-name section))
                (data-section-size section)
                (bytes-length bytes)))
       (set! chunks (cons bytes chunks))
       (set! sections
             (cons (encoded-section 'data
                                    (data-section-name section)
                                    base
                                    (data-section-size section)
                                    (hash))
                   sections))
       (set! offset (+ base (data-section-size section)))]

      [else
       (error 'encode "unknown program section: ~e" section)]))

  (unless (= offset (program-layout-size program))
    (error 'encode "program size mismatch: expected ~a, wrote ~a"
           (program-layout-size program) offset))
  (encoded-program (apply bytes-append (reverse chunks))
                   (reverse sections)
                   (program-layout-origin program)
                   relocations
                   (program-layout-externs program)))

;; ---------------------------------------------------------------------------
;; 公共编码循环
;; ---------------------------------------------------------------------------

(define (encode-items items section-name xlen)
  (unless (memq xlen '(32 64))
    (error 'encode "xlen must be 32 or 64: ~e" xlen))
  (define target (if (= xlen 64) target-rv64-base target-rv32-all))

  (define labels (compute-label-offsets items))
  (define offset 0)
  (define chunks '())
  (define relocations '())

  (define (emit-word name operands)
    (define-values (word size) (encode-instruction target name operands))
    (unless (= size 4)
      (error 'encode "instruction ~a encoded to ~a bytes" name size))
    (set! chunks (cons (integer->bytes size word) chunks))
    (set! offset (+ offset size)))

  (for ([item (in-list items)])
    (case (car item)
      [(label) (void)]
      [(call-target)
       (error 'encode
              "call-target requires program layout / relocation: ~e"
              item)]
      [(addr-global)
       (error 'encode
              "addr-global requires program layout / relocation: ~e"
              item)]
      [(reloc-call)
       (define symbol (cadr (cadr item)))
       (set! relocations
             (append relocations
                     (list (relocation section-name offset 'call-pcrel
                                       symbol 0 8 '(native x1)))))
       (emit-word 'auipc '(x1 0))
       (emit-word 'jalr '(x1 x1 0))]
      [(reloc-addr)
       (define dst (cadr item))
       (define symbol (cadr (caddr item)))
       (set! relocations
             (append relocations
                     (list (relocation section-name offset 'addr-pcrel
                                       symbol 0 8 dst))))
       (emit-word 'auipc (list (machine->operand dst) 0))
       (emit-word 'addi (list (machine->operand dst) (machine->operand dst) 0))]
      [(asm-code)
       (define code (cadr item))
       (define-values (bytes _labels code-relocs)
         (encode-items code section-name xlen))
       (unless (null? code-relocs)
         (error 'encode "asm-code cannot contain external relocations"))
       (unless (= (bytes-length bytes) (asm-code-size code))
         (error 'encode
                "asm-code assumed ~a bytes, encoded ~a: ~e"
                (asm-code-size code) (bytes-length bytes) item))
       (set! chunks (cons (bytes->list bytes) chunks))
       (set! offset (+ offset (bytes-length bytes)))]
      [else
       (define-values (name operands)
         (instruction-name+operands item labels offset))
       (emit-word name operands)]))

  (values (list->bytes (append* (reverse chunks))) labels relocations))

;; ---------------------------------------------------------------------------
;; label offsets
;; ---------------------------------------------------------------------------

(define (compute-label-offsets items)
  (define table (make-hash))
  (define offset 0)
  (for ([item (in-list items)])
    (case (car item)
      [(label)
       (define name (cadr item))
       (when (hash-has-key? table name)
         (error 'encode "label ~a is defined twice" name))
       (hash-set! table name offset)]
      [(call-target) (set! offset (+ offset 8))]
      [(addr-global) (set! offset (+ offset 8))]
      [(reloc-call) (set! offset (+ offset 8))]
      [(reloc-addr) (set! offset (+ offset 8))]
      [(asm-code) (set! offset (+ offset (asm-code-size (cadr item))))]
      [(call-jal) (set! offset (+ offset 4))]
      [else (set! offset (+ offset 4))]))
  table)

;; ---------------------------------------------------------------------------
;; item -> native mnemonic + operands
;; ---------------------------------------------------------------------------

(define (instruction-name+operands item labels here)
  (define head (car item))
  (case head
    [(beq bne blt bge bltu bgeu)
     (define target (cadr item))
     (define rs1 (caddr item))
     (define rs2 (cadddr item))
     (values head
             (list (label-offset labels target here)
                   (machine->operand rs1)
                   (machine->operand rs2)))]

    [(jal)
     (define link (cadr item))
     (define target (caddr item))
     (values 'jal
             (list (machine->operand link)
                   (label-offset labels target here)))]

    [(call-jal)
     ;; program-layout 已经把 call-target 解析成相对当前指令的偏移。
     (values 'jal
             (list (machine->operand '(native x1))
                   (cadr item)))]

    [else
     (values head
             (for/list ([operand (in-list (cdr item))])
               (machine->operand operand)))]))

(define (label-offset labels target here)
  (define at (hash-ref labels target #f))
  (unless at
    (error 'encode "undefined label: ~a" target))
  (- at here))

(define (machine->operand operand)
  (cond
    [(exact-integer? operand) operand]
    [(physical-register? operand) (cadr operand)]
    [(global-ref? operand)
     (error 'encode "global operand needs relocation: ~e" operand)]
    [else
     (error 'encode "unsupported operand: ~e" operand)]))
