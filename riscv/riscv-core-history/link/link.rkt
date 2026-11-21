#lang racket
;;; link/link.rkt
;;;
;;; 最小 link：encoded-program + address data -> 最终 bytes。
;;;
;;; 第一版只回填已记录的 relocation：
;;;   call-pcrel / addr-pcrel / abs
;;; 不做 section 重排、GC、relaxation、object/ELF。

(require racket/list
         "../core/sexp.rkt"
         "../ir/shape.rkt"
         "../encode/encode.rkt"
         "external.rkt"
         "reloc.rkt"
         "../../riscv-help/ranges.rkt"
         "../../riscv-compiler/api.rkt")

(provide (struct-out linked-program)
         link-encoded)

(struct linked-program
  (bytes
   relocations
   addresses)
  #:transparent)

(define (link-encoded program
                      #:addresses [addresses '()]
                      #:xlen [xlen 64])
  (unless (encoded-program? program)
    (error 'link "expected an encoded-program: ~e" program))
  (unless (memq xlen '(32 64))
    (error 'link "xlen must be 32 or 64: ~e" xlen))

  (define address-table (make-hash))
  (for ([a (in-list addresses)])
    (unless (address-form? a)
      (error 'link "malformed address: ~e" a))
    (define name (address-name a))
    (define value (address-value a))
    (unless (exact-nonnegative-integer? value)
      (error 'link "address for ~a must be non-negative: ~e"
             (chain->string name) value))
    (when (hash-has-key? address-table name)
      (error 'link "address for ~a is defined twice" (chain->string name)))
    (hash-set! address-table name value))

  (define externs (extern-table (encoded-program-externs program)))
  (for ([name (in-hash-keys address-table)])
    (unless (hash-has-key? externs name)
      (error 'link "address for non-extern symbol ~a" (chain->string name))))

  (define section-bases (make-hash))
  (for ([section (in-list (encoded-program-sections program))])
    (hash-set! section-bases (encoded-section-name section)
               (encoded-section-base section)))

  (define out (bytes-copy (encoded-program-bytes program)))
  (define target (if (= xlen 64) target-rv64-base target-rv32-all))
  (define word-size (if (= xlen 64) 'rv64 'rv32))

  (define (section-base name)
    (or (hash-ref section-bases name #f)
        (error 'link "relocation refers to unknown section ~a"
               (chain->string name))))

  (define (write-word! at word)
    (for ([i (in-range 4)])
      (bytes-set! out (+ at i)
                  (bitwise-and (arithmetic-shift word (- (* 8 i))) #xFF))))

  (define (emit-instruction! at name operands)
    (define-values (word size) (encode-instruction target name operands))
    (unless (= size 4)
      (error 'link "relocation instruction ~a encoded to ~a bytes" name size))
    (write-word! at word))

  (define (write-abs! at width value)
    (define max (sub1 (arithmetic-shift 1 (* 8 width))))
    (unless (<= 0 value max)
      (error 'link "absolute relocation value ~a does not fit in ~a bytes"
             value width))
    (for ([i (in-range width)])
      (bytes-set! out (+ at i)
                  (bitwise-and (arithmetic-shift value (- (* 8 i))) #xFF))))

  (for ([reloc (in-list (encoded-program-relocations program))])
    (define symbol (relocation-symbol reloc))
    (define value (hash-ref address-table symbol #f))
    (unless value
      (error 'link "unresolved external symbol ~a" (chain->string symbol)))
    (define base (section-base (relocation-section reloc)))
    (define at (+ base (relocation-offset reloc)))
    (define here (+ (encoded-program-origin program) at))
    (case (relocation-kind reloc)
      [(call-pcrel)
       (define delta (- value here))
       (unless (fits-auipc-pair? delta word-size)
         (error 'link "external call to ~a is outside auipc+jalr range (delta ~a)"
                (chain->string symbol) delta))
       (define-values (hi lo) (split-hi-lo delta))
       (emit-instruction! at 'auipc (list 'x1 hi))
       (emit-instruction! (+ at 4) 'jalr (list 'x1 'x1 lo))]
      [(addr-pcrel)
       (define delta (- value here))
       (unless (fits-auipc-pair? delta word-size)
         (error 'link "external addr to ~a is outside auipc+addi range (delta ~a)"
                (chain->string symbol) delta))
       (define reg (relocation-reg reloc))
       (unless (physical-register? reg)
         (error 'link "addr-pcrel relocation needs a register: ~e" reloc))
       (define r (cadr reg))
       (define-values (hi lo) (split-hi-lo delta))
       (emit-instruction! at 'auipc (list r hi))
       (emit-instruction! (+ at 4) 'addi (list r r lo))]
      [(abs)
       (write-abs! at
                   (relocation-width reloc)
                   (+ value (relocation-addend reloc)))]
      [else
       (error 'link "unknown relocation kind: ~e" reloc)]))

  (linked-program out
                  (encoded-program-relocations program)
                  addresses))
