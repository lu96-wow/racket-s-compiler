#lang racket
;;; L6/demo.rkt -- 分支松弛
;;;
;; 输入: L4 的 program + 数据 + layout 输入
;;; 输出: L5 的 layout, 但里面已经没有够不着的控制转移
;;;
;;; 空槽(scratch)本层**不填** —— 那是"动态内存布局 / 寄存器使用"那一层的事(未实现),
;;; 所以升到 branch-indirect / (jump-far x0 …) 之后, scratch-hole 会留在 problems 里。
;;;
;;; 这个 demo 故意让目标在 +2MB 外, 好看完整阶梯:
;;   条件分支: beq             4B, [-4096, 4094]   不够
;;;             branch-far      8B, ±1MB           还是不够
;;;             branch-indirect 12B, 不设限        够, 但留下一个空槽
;;;   跳转:     jal x0          4B, ±1MB            不够
;;;             jump-far x0     8B, 不设限         够, 但留下一个空槽
;;;
;;; 每一步都重跑 L5, 地址全部重算。

(require "relax.rkt"
         (only-in "../L3/analyze.rkt" sexp->program)
         (only-in "../L5/layout.rkt" layout-program layout-problems))

(define prog
  (sexp->program
   '((blocks
      (block ((prog1 main)) (beq t0 t1 (prog1cold cold)))
      (block () (jal x0 (prog1cold cold)))          ; 也是 2MB 外, 一起松弛
      (block ((prog1cold cold)) (addi a1 a1 1) (jalr x0 ra 0)))
     (flows
      (flow (succ 2 1) (fallthrough 1) (root? #t))
      (flow (succ 2) (fallthrough #f) (root? #f))
      (flow (succ) (fallthrough #f) (root? #f))))))

(define layout-input
  '((segments (segment prog1     code #x1000   #x1FFF   4)
              (segment prog1cold code #x200000 #x200FFF 4))
    (place prog1     (prog1 main))
    (place prog1cold (prog1cold cold))))

(define (show label out)
  (displayln (format ";; ~a" label))
  (for ([seg (in-list (cdr (assoc 'segments out)))])
    (define name (cadr (assoc 'name (cdr seg))))
    (for ([entry (in-list (cdr (assoc 'items (cdr seg))))])
      (displayln (format "  ~a ~s" name entry))))
  (displayln (format "  problems: ~s" (layout-problems out)))
  (newline))

(define out (relax prog '() layout-input))
(show "relax" out)

(displayln ";;;; 最终布局(地址都按新尺寸重算过)")
(for ([s (in-list (cdr (assoc 'symbols out)))])
  (displayln (format "  ~s -> ~a+~x (#x~x)" (car s) (cadr s) (caddr s) (cadddr s))))
