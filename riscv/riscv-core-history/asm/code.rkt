#lang racket
;;; asm/code.rkt
;;;
;;; inline asm 的封闭 machine code 块。
;;;
;;; code item：
;;;   (label name ...)                 ; local symbol，只在 code 内可见
;;;   (j name)                         ; -> jal x0, name
;;;   (beq|bne|blt|bge|bltu|bgeu name a b)
;;;   (jal (native xN) name)
;;;   (mnemonic operand ...)           ; operand 是整数或 (native xN)
;;;
;;; 第一版固定 4 字节；不做 code 内远跳 relaxation。

(require racket/list
         "../core/sexp.rkt"
         "../ir/shape.rkt"
         "insn.rkt")

(provide (struct-out asm-code-layout)
         normalize-asm-code
         asm-code-size)

(struct asm-code-layout
  (items
   size
   labels) ; hash symbol -> 段内偏移
  #:transparent)

(define (label-item? x)
  (and (form? x)
       (eq? (car x) 'label)
       (pair? (cdr x))
       (andmap symbol? (cdr x))))

;; 输入是 (code ...) 里的 body，不含 code 头。
(define (normalize-asm-code items)
  (define labels (make-hash))
  (define targets '())
  (define size 0)
  (define out '())

  (define (add-label! name)
    (when (hash-has-key? labels name)
      (error 'asm-code "asm label ~a is defined twice" name))
    (hash-set! labels name size)
    (set! out (append out (list (list 'label name)))))

  (for ([item (in-list items)])
    (cond
      [(label-item? item)
       (for ([name (in-list (cdr item))])
         (add-label! name))]

      [(and (form? item) (eq? (car item) 'j))
       (unless (and (= 2 (length item)) (symbol? (cadr item)))
         (error 'asm-code "malformed j: ~e" item))
       (set! targets (cons (cadr item) targets))
       (set! out (append out (list (list 'jal '(native x0) (cadr item)))))
       (set! size (+ size 4))]

      [(and (form? item) (memq (car item) branch-mnemonics))
       (unless (and (= 4 (length item))
                    (symbol? (cadr item))
                    (machine-operand? (caddr item))
                    (machine-operand? (cadddr item)))
         (error 'asm-code "malformed branch: ~e" item))
       (set! targets (cons (cadr item) targets))
       (set! out (append out (list item)))
       (set! size (+ size 4))]

      [(and (form? item) (eq? (car item) 'jal))
       (unless (and (= 3 (length item))
                    (physical-register? (cadr item))
                    (symbol? (caddr item)))
         (error 'asm-code "malformed jal: ~e" item))
       (set! targets (cons (caddr item) targets))
       (set! out (append out (list item)))
       (set! size (+ size 4))]

      [else
       (unless (and (form? item) (symbol? (car item)))
         (error 'asm-code "asm item must be a non-empty proper list: ~e" item))
       (when (memq (car item) '(label call-target term frame scratch allocation
                                global native frame-slot slot vregs func data raw))
         (error 'asm-code "asm item uses a forbidden head: ~e" item))
       (unless (andmap machine-operand? (cdr item))
         (error 'asm-code
                "asm native operands must be integers or (native xN): ~e"
                item))
       (set! out (append out (list item)))
       (set! size (+ size 4))]))

  (for ([target (in-list targets)])
    (unless (hash-has-key? labels target)
      (error 'asm-code "asm branch target ~a is not defined in code" target)))

  (asm-code-layout out size labels))

;; 输入是已经 normalize 过的 items。
(define (asm-code-size items)
  (for/fold ([n 0]) ([item (in-list items)])
    (if (eq? (car item) 'label)
        n
        (+ n 4))))
