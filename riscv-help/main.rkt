#lang racket/base

;; ============================================================
;; riscv-help 对外入口
;;
;; 只导出稳定的公共 API。
;; 叶子展开函数、占位形式、scratch 内部工具和寄存器表留在各模块内部。
;; 详细说明见 DESIGN.md。
;; ============================================================

(require "ranges.rkt"
         "registers.rkt"
         "li.rkt"
         "la.rkt"
         "jump.rkt"
         "branch.rkt")

(provide
 ;; 常量 / 绝对地址
 li
 li-size

 ;; PC 相对地址
 load-pcrel
 load-pcrel-size

 ;; gp / 栈帧相对地址
 la-gp
 la-frame

 ;; 跳转
 jump-cj
 jump-cjal
 jump-jal
 jump-auipc-jalr
 jump-jalr
 jump-pcrel-far
 jump-abs

 ;; 条件分支
 branch-c
 branch-b
 branch-long

 ;; 分支 / 跳转 / gp 选择需要的范围判断
 fits-s12?
 fits-cjump?
 fits-branch?
 fits-cbranch?
 fits-jal?
 fits-jalr12?
 fits-auipc-pair?

 ;; scratch / 压缩寄存器选择需要的寄存器判断
 register?
 register->number
 same-register?
 zero-register?
 compressed-branch-register?)
