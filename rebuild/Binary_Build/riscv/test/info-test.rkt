#lang racket/base

(require rackunit
         racket/list
         "../instruction_info/struct.rkt"
         "../instruction_info/query.rkt"
         "../instruction_info/all.rkt"
         (prefix-in rv-i: "../instruction_info/rv_i.rkt")
         (prefix-in rv-c: "../instruction_info/rv_c.rkt")
         (prefix-in rv-d: "../instruction_info/rv_d.rkt")
         (prefix-in rv-zbkc: "../instruction_info/rv_zbkc.rkt"))

(define addi
  (find-instruction-info rv-i:rv_i-instructions "addi"))

(check-true (instruction-info? addi))
(check-equal? (info-width addi) 32)
(check-equal? (info-operands addi) '("rd" "rs1" "imm12"))
(check-equal? (info-raw-operands addi) '("rd" "rs1" "imm12"))
(check-equal? (info-asm-format addi) "addi rd, rs1, imm12")
(check-equal? (info-param-count addi) 3)

(define c-lw
  (find-instruction-info rv-c:rv_c-instructions "c.lw"))

(check-equal? (info-width c-lw) 16)
(check-equal? (info-operands c-lw) '("rd_p" "rs1_p" "c_uimm7"))
(check-equal? (info-raw-operands c-lw)
              '("rd_p" "rs1_p" "c_uimm7lo" "c_uimm7hi"))

(define fmv-d
  (find-instruction-info rv-d:rv_d-instructions "fmv.d"))

(check-equal? (info-operands fmv-d) '("rd" "rs1"))
(check-equal? (info-aliases fmv-d) '(("rs2" "rs1")))
(check-equal? (info-asm-format fmv-d) "fmv.d rd, rs1")

;; import 后的指令也出现在当前扩展的元数据里
(check-true
 (and (find-instruction-info rv-zbkc:rv_zbkc-instructions "clmul")
      #t))

;; 全局扩展映射
(check-not-false (member "rv_i" (get-extensions "addi")))
(check-not-false (member "rv_zbkc" (get-extensions "clmul")))

;; 所有扩展的元数据总数
(check-equal? (length all-instruction-info) 1232)

(displayln "instruction info tests passed")
