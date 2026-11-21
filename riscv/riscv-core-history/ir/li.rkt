#lang racket
;;; ir/li.rkt
;;;
;;; 把 riscv-help 的 li 展开适配成 core machine IR：
;;; 寄存器继续写 (native xN)。

(require "../../riscv-help/li.rkt"
         "../../riscv-help/registers.rkt"
         "shape.rkt")

(provide emit-li)

(define (emit-li dst value xlen)
  (unless (physical-register? dst)
    (error 'emit-li "li destination must be a physical register: ~e" dst))
  (unless (memq xlen '(32 64))
    (error 'emit-li "xlen must be 32 or 64: ~e" xlen))
  (define rd (cadr dst))
  (define word-size (if (= xlen 64) 'rv64 'rv32))
  (for/list ([inst (in-list (expand-li rd value #:word-size word-size))])
    (wrap-native-instruction inst)))

(define (wrap-native-instruction inst)
  (unless (and (list? inst) (symbol? (car inst)))
    (error 'emit-li "malformed native instruction from li: ~e" inst))
  (cons (car inst)
        (for/list ([arg (in-list (cdr inst))])
          (if (and (symbol? arg) (register? arg))
              (list 'native arg)
              arg))))
