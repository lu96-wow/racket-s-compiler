#lang racket

(require "test-assemble.rkt"
         "binary-receiver.rkt")

(define ns (make-base-namespace))

(parameterize ([current-namespace ns])
  (namespace-require 'racket)
  (namespace-require "../Binary_Build/riscv/instruction/rv_i.rkt")
  (namespace-require "../Binary_Build/riscv/register.rkt"))

;; =========================
;; 编译
;; =========================

(define (assemble->bytes+symbols ir #:base [base 0])
  (define result
    (assemble ir
              #:base base
              #:gen-abs-symbols? #t
              #:gen-rel-symbols? #t))

  (define forms (AssembleResult-forms result))
  (define abs-symbols (AssembleResult-abs-symbols result))
  (define rel-symbols (AssembleResult-rel-symbols result))

  (define receiver (make-integer-byte-receiver 4 #f #f))

  (for ([f forms])
    (define word
      (parameterize ([current-namespace ns])
        (eval f)))
    (receiver-add! receiver word))

  (values
   (receiver-get-bytes receiver)
   abs-symbols
   rel-symbols))

;; =========================
;; 程序
;; =========================

(define program
  '((label start)
    (load-immediate32 x1 #x10000000)
    (instruction (addi x2 x0 65))
    (instruction (sb 0 x1 x2))
    (label loop)
    (load-address32 x3 start)
    (label start)
    (load-address32 x4 loop)
    (jump32 loop)))

;; =========================
;; 执行
;; =========================

(define-values (bytes abs-symbols rel-symbols)
  (assemble->bytes+symbols program #:base #x8000000))

;; 二进制
(call-with-output-file "test-assemble"
  (lambda (out) (write-bytes bytes out))
  #:exists 'replace)

;; 符号
(when abs-symbols
  (call-with-output-file "symbols-abs.scm"
    (lambda (out) (write abs-symbols out))
    #:exists 'replace))

(when rel-symbols
  (call-with-output-file "symbols-rel.scm"
    (lambda (out) (write rel-symbols out))
    #:exists 'replace))