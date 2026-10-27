#lang racket
;;; L7/insn.rkt
;;;
;;; 一条真指令 -> 指令字。编码本身交给 riscv-asm 生成的 rebuilt 模块:
;;; 那里已经含全部位域检查(立即数范围、压缩寄存器约束、aq/rl 值域)。
;;;
;;; 本层只补两件 riscv-asm 不负责的事:
;;;
;;; 1. **操作数顺序**。riscv-opcodes 的声明顺序(也就是 rebuilt 函数的参数顺序)
;;;    不是汇编写法: 分支 / 存储 / 原子把合并后的立即数放在第一位。
;;;        (beq bimm12 rs1 rs2)   <- 函数
;;;        (beq rs1 rs2 L)        <- 我们写
;;;    所以有一张"调用位置 <- s-exp 位置"的表。键是操作数名列表(用空格连接),
;;;    32 位只要 22 类、16 位只要 25 类 (见下面的 operand-plans)。
;;;
;;; 2. **aq / rl**。riscv-opcodes 里它们是两个 0/1 操作数; gas 里是助记符后缀。
;;;    我们只认规范写法: .aq / .rl / .aqrl (不认 .rlaq —— 那是拼错, 报未知助记符)。
;;;    所以 (amoadd.d.aqrl rd rs2 rs1) 的 s-exp 操作数是 3 个, 调用参数是 5 个。
;;;
;;; 这里**不做**范围检查: 越界由 riscv-asm 抛错(它就是"变二进制"那一步)。

(require "../../riscv-asm/generated/lib/instruction_paths.rkt"
         "../../riscv-asm/generated/lib/info/struct.rkt"
         "../../riscv-asm/generated/lib/info/query.rkt"
         "../../riscv-asm/generated/lib/info/lookup.rkt"
         "../../riscv-help/registers.rkt"
         "target.rkt")

(provide encode-instruction
         instruction-arity
         known-instruction?
         split-aqrl)

;; ---------------------------------------------------------------------------
;; aq / rl 后缀
;; ---------------------------------------------------------------------------

(define (string-suffix? s suffix)
  (and (>= (string-length s) (string-length suffix))
       (string=? (substring s (- (string-length s) (string-length suffix))) suffix)))

;; (amoadd.d.aqrl rd rs2 rs1) -> (values 'amoadd.d 1 1)
;; 只认三种规范后缀; .rlaq 之类落到"未知助记符"。
(define (split-aqrl name)
  (define s (symbol->string name))
  (cond
    [(string-suffix? s ".aqrl") (values (string->symbol (substring s 0 (- (string-length s) 5))) 1 1)]
    [(string-suffix? s ".aq")   (values (string->symbol (substring s 0 (- (string-length s) 3))) 1 0)]
    [(string-suffix? s ".rl")   (values (string->symbol (substring s 0 (- (string-length s) 3))) 0 1)]
    [else (values name 0 0)]))

;; ---------------------------------------------------------------------------
;; 查表 (缓存)
;; ---------------------------------------------------------------------------

(define info-cache (make-hash))

(define (instruction-info* name)
  (hash-ref! info-cache name
             (lambda ()
               (and (pair? (instruction-info-candidates target-extensions name))
                    (resolve-instruction-info target-extensions name)))))

(define (known-instruction? name) (and (instruction-info* name) #t))

(define proc-cache (make-hash))

(define (instruction-proc info)
  (define ext (instruction-info-extension info))
  (define name (instruction-info-name info))
  (hash-ref! proc-cache (cons ext name)
             (lambda ()
               (dynamic-require `(file ,(rebuilt-instruction-path ext)) name))))

;; ---------------------------------------------------------------------------
;; 操作数顺序表
;;   键: riscv-opcodes 的操作数名(空格连接, 即 rebuilt 函数的参数顺序)
;;   值: 每个调用参数取自哪里
;;        整数 = s-exp 的第几项
;;        'aq / 'rl = 助记符后缀带来的常量
;;   没有登记的形状 = 我们还没给语法(目前是 fence / fence.tso)。
;; ---------------------------------------------------------------------------

(define (plan-key names) (string-join names " "))

(define operand-plans
  (hash
   ;; --- 32 位 ---
   ""                            '()          ; 无操作数 (nop ret ebreak fence)
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

(define (plan-of info)
  (hash-ref operand-plans (plan-key (instruction-info-operands info)) #f))

;; s-exp 该有几个操作数 = 表里用到的最大下标 + 1 (aq/rl 不算)
(define (operand-arity plan)
  (define xs (filter exact-integer? plan))
  (if (null? xs) 0 (add1 (apply max xs))))

(define (instruction-arity name)
  (define-values (base _aq _rl) (split-aqrl name))
  (define info (instruction-info* base))
  (and info
       (let ([plan (plan-of info)])
         (and plan (operand-arity plan)))))

;; ---------------------------------------------------------------------------
;; 编码
;;   operands 里可以是寄存器名(x0/zero/a0…)或已经解析好的整数。
;;   立即数/偏移一律是整数。
;; ---------------------------------------------------------------------------

(define (operand-value v)
  (cond
    [(exact-integer? v) v]
    [(register->number v) => values]
    [else (error 'encode-instruction "not a register or integer: ~e" v)]))

(define (encode-instruction name operands)
  (define-values (base aq rl) (split-aqrl name))
  (define info (or (instruction-info* base)
                   (error 'encode-instruction "unknown instruction: ~a" name)))
  (define plan (or (plan-of info)
                   (error 'encode-instruction
                          "no operand syntax for ~a (operands ~s)"
                          base (instruction-info-operands info))))
  (define has-flags? (ormap (lambda (p) (memq p '(aq rl))) plan))
  (when (and (positive? (+ aq rl)) (not has-flags?))
    (error 'encode-instruction "~a does not take .aq/.rl" name))
  (define arity (operand-arity plan))
  (unless (= arity (length operands))
    (error 'encode-instruction
           "~a takes ~a operand(s), got ~a: ~e" base arity (length operands) operands))
  (define args
    (for/list ([p (in-list plan)])
      (case p
        [(aq) aq]
        [(rl) rl]
        [else (operand-value (list-ref operands p))])))
  (values (apply (instruction-proc info) args)
          (quotient (instruction-info-width info) 8)))
