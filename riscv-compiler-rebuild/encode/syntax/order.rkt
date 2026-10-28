#lang racket
;;; encode/syntax/order.rkt
;;;
;;; 普通指令的 s-exp 操作数顺序表。
;;;
;;; 信息来自 riscv-asm 的 instruction-info:
;;;   operands 是 rebuilt 函数的参数顺序, 不是源码顺序。
;;; 这里只声明"第几个 s-exp 操作数放到第几个函数参数"。
;;;
;;;   "bimm12" "rs1" "rs2"  -> (2 0 1)   ; (beq rs1 rs2 L)
;;;   "simm12" "rs1" "rs2"  -> (2 1 0)   ; (sw 值 基址 偏移)
;;;   "rd" "rs1" "rs2"      -> (0 1 2)
;;;
;;; 表里没登记的形状不是"猜一个默认值", 而是明确报 missing syntax;
;;; 这样 coverage 能列出还缺哪些扩展的哪些形状。

(require "../../../riscv-asm/generated/lib/info/struct.rkt"
         "operand-kind.rkt")

(provide order-plan-of
         order-plan-keys
         order-plan-arity
         order-plan-has-flags?
         order-plan->args)

(define (plan-key names) (string-join names " "))

(define operand-plans
  (hash
   ;; --- 32 位 ---
   ""                            '()          ; 无操作数 (nop ret ebreak/pause)
   "rd"                          '(0)
   "rs1"                         '(0)          ; jr
   "jimm20"                      '(0)          ; j
   "rd rs1"                      '(0 1)
   "rd rs2"                      '(0 1)        ; neg snez sgtz
   "rd imm20"                    '(0 1)
   "rd jimm20"                   '(0 1)
   "rd rs1 rs2"                  '(0 1 2)
   "rd rs1 imm12"                '(0 1 2)      ; I 型 / 载入
   "rd rs1 shamtd"               '(0 1 2)
   "rd rs1 shamtw"               '(0 1 2)
   "rd_rs1_p rs2_p"              '(0 1)
   "simm12 rs1 rs2"              '(2 1 0)      ; 存储: (sw 值 基址 偏移)
   "bimm12 rs1"                  '(1 0)
   "bimm12 rs2"                  '(1 0)        ; blez bgtz
   "bimm12 rs1 rs2"              '(2 0 1)      ; 分支: (beq rs1 rs2 L)
   "bimm12 rs2 rs1"              '(2 1 0)      ; ble bgt bleu bgtu
   ;; CSR: 源码按标准汇编写法 (rd, csr, rs1) / (rd, csr, imm)
   "rd rs1 csr"                  '(0 2 (csr 1))
   "rd csr zimm5"                '(0 (csr 1) (zimm5 2))
   "rs1 csr"                     '(1 (csr 0))
   "rd csr"                      '(0 (csr 1))
   "csr zimm5"                   '((csr 0) (zimm5 1))
   ;; 原子: gas 写法 (amoadd.d rd rs2 (rs1)); aq/rl 来自助记符后缀
   "rd rs1 aq rl"                '(0 1 aq rl)
   "rd rs1 rs2 aq rl"            '(0 2 1 aq rl)
   ;; --- 16 位 ---
   "c_imm12"                     '(0)          ; c.j
   "c_nzimm6"                    '(0)          ; c.nop (riscv-opcodes 里带一个立即数)
   "c_nzimm10"                   '(0)          ; c.addi16sp
   "c_rs1_n0"                    '(0)          ; c.jalr
   "rs1_n0"                      '(0)          ; c.jr
   "c_rs2 c_uimm8sp_s"           '(0 1)        ; c.swsp
   "c_rs2 c_uimm9sp_s"           '(0 1)        ; c.sdsp
   "rd_n0 c_imm6"                '(0 1)        ; c.lui
   "rd_n0 c_rs2_n0"              '(0 1)        ; c.mv
   "rd_n0 c_uimm8sp"             '(0 1)        ; c.lwsp
   "rd_n0 c_uimm9sp"             '(0 1)        ; c.ldsp
   "rd_n2 c_nzimm18"             '(0 1)        ; c.lui
   "rd_p c_nzuimm10"             '(0 1)        ; c.addi4spn
   "rd_p rs1_p c_uimm7"          '(0 1 2)      ; c.lw
   "rd_p rs1_p c_uimm8"          '(0 1 2)      ; c.ld
   "rd_rs1_n0 c_imm6"            '(0 1)        ; c.slli
   "rd_rs1_n0 c_nzimm6"          '(0 1)        ; c.addi
   "rd_rs1_n0 c_nzuimm6"         '(0 1)        ; c.andi
   "rd_rs1_n0 c_rs2_n0"          '(0 1)        ; c.add
   "rd_rs1_p c_imm6"             '(0 1)        ; c.srli c.srai
   "rd_rs1_p c_nzuimm6"          '(0 1)        ; c.andi
   "rd_rs1_p rs2_p"              '(0 1)        ; c.sub c.xor c.or c.and c.subw c.addw
   "rs1_p c_bimm9"               '(0 1)        ; c.beqz c.bnez
   "rs1_p rs2_p c_uimm7"         '(1 0 2)      ; c.sw: (c.sw 值 基址 偏移)
   "rs1_p rs2_p c_uimm8"         '(1 0 2)))     ; c.sd

(define (order-plan-of info)
  (hash-ref operand-plans (plan-key (instruction-info-operands info)) #f))

(define (order-plan-keys)
  (sort (hash-keys operand-plans) string<?))

;; s-exp 该有几个操作数 = 表里用到的最大下标 + 1 (aq/rl 不算)
(define (plan-position p)
  (cond
    [(exact-integer? p) p]
    [(and (pair? p) (exact-integer? (cadr p))) (cadr p)]
    [else #f]))

(define (order-plan-arity plan)
  (define xs (filter values (map plan-position plan)))
  (if (null? xs) 0 (add1 (apply max xs))))

(define (order-plan-has-flags? plan)
  (and (ormap (lambda (p) (memq p '(aq rl))) plan) #t))

(define (order-plan->args plan target operands aq rl)
  (for/list ([p (in-list plan)])
    (cond
      [(eq? p 'aq) aq]
      [(eq? p 'rl) rl]
      [(exact-integer? p) (operand-kind-value target 'plain (list-ref operands p))]
      [(pair? p) (operand-kind-value target (car p) (list-ref operands (cadr p)))]
      [else (error 'encode-instruction "bad order-plan entry: ~e" p)])))
