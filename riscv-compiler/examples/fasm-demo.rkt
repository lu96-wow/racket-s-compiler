#lang racket/base

;; ============================================================
;; F-asm 原型 demo
;;
;;   racket examples/fasm-demo.rkt
;; ============================================================

(require racket/pretty
         "../scheme-core.rkt"
         "../fasm-interp.rkt")

(define (run label expr)
  (define fasm (compile-scheme expr))
  (displayln (format "~a => ~a" label (run-fasm fasm)))
  (when (eq? label 'factorial)
    (displayln "compiled F-asm:")
    (pretty-print fasm)
    (newline)))

(run 'arithmetic '(+ 1 2))
(run 'if '(if #f 1 2))
(run 'closure '(((lambda (x) (lambda (y) (+ x y))) 2) 40))
(run 'factorial
     '(letrec ((fact (lambda (n)
                       (if (= n 0)
                           1
                           (* n (fact (- n 1)))))))
        (fact 5)))
(run 'tail-loop
     '(letrec ((loop (lambda (n acc)
                       (if (= n 0)
                           acc
                           (loop (- n 1) (+ acc n))))))
        (loop 10000 0)))
(run 'call/cc
     '(+ 1 (call/cc (lambda (k) (k 41)))))
(run 'quoted-list
     '(car (cdr (quote (1 2 3)))))
(run 'set!
     '(let ((make-counter
            (lambda ()
              (let ((n 0))
                (lambda ()
                  (begin (set! n (+ n 1)) n))))))
        (let ((c (make-counter)))
          (begin (c) (c) (c)))))
