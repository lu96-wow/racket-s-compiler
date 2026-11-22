#lang racket/base
;;; riscv-help/size.rkt
;;;
;;; 指令长度计算的唯一入口。
;;;
;;; 输入是一个 s-exp 指令（native 或本项目的显式展开形式），输出字节数。
;;; 不生成指令、不检查范围、不编码；只回答“这条形式占多少字节”。
;;;
;;; 支持的显式形式:
;;;   (li rd value)                     ; 由 li-size 精确决定
;;;   (la-pcrel rd expr)                ; auipc + addi, 8
;;;   (la-pcrel-li-add rd tmp expr)     ; 固定上界: rv32 16 / rv64 40
;;;   (branch-jal cond rs1 rs2 target)  ; 8
;;;   (branch-auipc-jalr tmp cond rs1 rs2 target) ; 12
;;;   (jump-auipc-jalr link base target)           ; 8
;;;
;;; 其它:
;;;   c.* 2 字节；其余 native 4 字节。
;;;   不认识的 form 也按 4 字节处理（和 encode 的不透明代码兜底一致）。

(require racket/string
         "li.rkt")

(provide instruction-size
         instructions-size
         la-pcrel-li-add-size)

;; la-pcrel-li-add 的固定上界:
;;   auipc (4) + li 最坏 (rv32 8 / rv64 32) + add (4)
(define (la-pcrel-li-add-size #:word-size [word-size 'rv64])
  (+ 8 (case word-size
         [(rv32) 8]
         [(rv64) 32]
         [else
          (error 'la-pcrel-li-add-size
                 "unknown word size: ~a" word-size)])))

(define (compressed-name? name)
  (and (symbol? name)
       (string-prefix? (symbol->string name) "c.")))

(define (instruction-size insn #:word-size [word-size 'rv64])
  (unless (and (pair? insn) (list? insn) (symbol? (car insn)))
    (error 'instruction-size "expected an instruction list: ~e" insn))
  (define head (car insn))
  (cond
    [(compressed-name? head) 2]
    [(eq? head 'li)
     (unless (= 3 (length insn))
       (error 'instruction-size "li needs (li rd value): ~e" insn))
     (li-size (cadr insn) (caddr insn) #:word-size word-size)]
    [(eq? head 'la-pcrel) 8]
    [(eq? head 'la-pcrel-li-add)
     (la-pcrel-li-add-size #:word-size word-size)]
    [(eq? head 'branch-jal) 8]
    [(eq? head 'branch-auipc-jalr) 12]
    [(eq? head 'jump-auipc-jalr) 8]
    [else 4]))

(define (instructions-size insns #:word-size [word-size 'rv64])
  (for/sum ([i (in-list insns)])
    (instruction-size i #:word-size word-size)))
