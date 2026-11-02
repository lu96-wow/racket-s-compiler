#lang racket
;;; amd64/compiler/analyze/insn.rkt
;;;
;;; amd64 指令分类（分析层视角）。只分类，不改写，不保存事实。
;;;
;;; 分类来自 amd64-asm/control-flow.rkt 里"每个 form 声明一次"的 flow 字段：
;;;
;;;   branch   jcc-short/near            目标 + 顺序
;;;   jump     jmp-short/near            只有目标
;;;   call     call-near                目标 + 顺序(调用会返回)
;;;   indirect jmp-indirect/call-indirect
;;;   stop     ret/ud2                  硬件保证不继续
;;;
;;; 曾经这里自己维护一张助记符表，把 `hlt` 也写进"不返回"，于是 CFG 认为
;;; Loko `syscall-hlt` 的队尾 (cli/swapgs/sysretq) 不可达，DCE 把它删了；
;;; hlt 被中断唤醒后顺序落进下一条 syscall 实现 → 垃圾 MSR → #GP → #DF。
;;; 现在"会不会落下"只有 amd64-asm 一处事实来源（默认 'sequential，例外
;;; 必须在 special 表里逐条声明），本层只翻译成谓词。

;;; 只提供"一条 item 是哪类控制流指令"。形状（form?/path?）在
;;; amd64-asm/shape.rkt，label 访问器在 compiler/item.rkt —— 这里不转发它们，
;;; 否则每个下游模块都会顺手拿到一堆不属于本层的东西。

;;; 只提供"一条 item 是哪类控制流指令"和"会不会顺序落下"。形状（form?/path?）
;;; 在 amd64-asm/shape.rkt, label 访问器在 compiler/item.rkt —— 这里不转发它们。
;;;
;;; 控制流事实本身在 amd64-asm/control-flow.rkt（由 special 表逐 form 声明）；
;;; 本层只把它翻译成分析用的谓词。这样"某条指令会不会落下"只有一份来源。

(require "../../amd64-asm/shape.rkt"
         "../../amd64-asm/control-flow.rkt")

(provide branch-instruction? jump-instruction? call-instruction?
         indirect-instruction? trap-instruction?
         ends-block? falls-through? non-fallthrough-reason
         unconditional-jump?
         jump-target)

(define (form-with-flow? x kind)
  (and (form? x) (eq? (control-flow-of (car x)) kind)))

(define (branch-instruction? x)   (form-with-flow? x 'branch))
(define (jump-instruction? x)     (form-with-flow? x 'jump))
(define (call-instruction? x)     (form-with-flow? x 'call))
(define (indirect-instruction? x) (or (form-with-flow? x 'jump-indirect)
                                      (form-with-flow? x 'call-indirect)))
(define (trap-instruction? x)     (form-with-flow? x 'stop))

;; 这条 item 为什么不会顺序执行到物理下一条: 'jump / 'jump-indirect / 'stop / #f。
;; 返回 #f = 会落下(默认)。能返回非 #f 的只有 control-flow.rkt 里那三种 kind。
(define (non-fallthrough-reason x)
  (and (form? x)
       (let ([kind (control-flow-of (car x))])
         (and (memq kind '(jump jump-indirect stop)) kind))))

;; 执行会不会顺序落到物理下一条
(define (falls-through? x)
  (not (non-fallthrough-reason x)))

(define (ends-block? x)
  (or (branch-instruction? x)
      (jump-instruction? x)
      (call-instruction? x)
      (indirect-instruction? x)
      (trap-instruction? x)))

;; 无条件的直接跳转（jmp-short/jmp-near）
(define (unconditional-jump? x)
  (jump-instruction? x))

;; 目标在最后: 分支/直接跳转/直接调用
(define (jump-target x)
  (and (or (branch-instruction? x)
           (jump-instruction? x)
           (call-instruction? x))
       (last x)))
