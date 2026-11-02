#lang racket
;;; encode/native-help.rkt
;;;
;;; riscv-help 生成的分支序列目前是 GAS 顺序：
;;;   (bne rs1 rs2 skip)
;;;
;;; 编码层现在只认 native 顺序：
;;;   (bne skip rs1 rs2)
;;;
;;; 这里只做这一处转换。jump-jal / jump-auipc-jalr / li / load-pcrel
;;; 的输出本来就是 native 顺序，不需要包装。

(require (only-in "../../riscv-help/main.rkt" branch-long))

(provide native-branch-long)

(define (native-branch-long mnemonic rs1 rs2 offset jump-expander)
  (define insns
    (branch-long mnemonic rs1 rs2 offset jump-expander))
  (define first (car insns))
  ;; first = (inverse rs1 rs2 skip)
  (cons (list (car first) (cadddr first) (cadr first) (caddr first))
        (cdr insns)))
