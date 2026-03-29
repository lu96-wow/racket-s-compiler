#lang racket

(require "test-assembler.rkt"
         "binary-receiver.rkt")

;; namespace
(define ns (make-base-namespace))

(parameterize ([current-namespace ns])
  (namespace-require 'racket)
  (namespace-require "../Binary_Build/riscv/instruction/rv_i.rkt")
  (namespace-require "../Binary_Build/riscv/register.rkt"))

;; 执行 + 编码
(define (assemble->bytes ir)
  (define forms (assemble ir))

  (define receiver
    (make-integer-byte-receiver 4 #f #f))

  (for ([f forms])
    (define word
      (parameterize ([current-namespace ns])
        (eval f)))

    (receiver-add! receiver word))

  (receiver-get-bytes receiver))

;; 测试程序
(define program
  '((label start)

    ;; x1 = 0x10000000 (UART)
    (instr (lui x1 #x10000000))

    ;; x2 = 'a'
    (instr (addi x2 x0 97))

    ;; *(x1) = x2
    (instr (sb 0 x1 x2))

    ;; 死循环（防止跑飞）
    (label loop)
    (jump loop)))

;; 生成 bytes
(define result (assemble->bytes program))

;; 写文件
(call-with-output-file "test-assemble"
  (lambda (out)
    (write-bytes result out))
  #:exists 'replace)
