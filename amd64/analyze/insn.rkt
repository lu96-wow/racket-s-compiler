#lang racket
;;; amd64/analyze/insn.rkt
;;;
;;; amd64 指令分类。只分类，不改写。
;;;
;;;   branch   jcc-short/near      目标 + 顺序
;;;   jump     jmp-short/near       只有目标
;;;   call     call-near            目标 + 顺序(调用会返回)
;;;   indirect jmp-indirect/call-indirect
;;;   term     ret/ud2/hlt          不返回
;;;
;;; 不认识的指令当普通指令。

(require "../sexp.rkt")

(provide form? name? path? normalize-path
         label-form? label-path
         branch-instruction? jump-instruction? call-instruction?
         indirect-instruction? trap-instruction?
         ends-block? falls-through? unconditional-jump?
         jump-target)

(define branch-mnemonics '(jcc-short jcc-near))
(define jump-mnemonics '(jmp-short jmp-near))
(define call-mnemonics '(call-near))
(define indirect-mnemonics '(jmp-indirect call-indirect))
(define trap-mnemonics '(ret ud2 hlt))

(define (head-in? x heads)
  (and (form? x) (memq (car x) heads) #t))

(define (label-form? x)
  (and (form? x) (eq? (car x) 'label) (path? (cdr x))))

(define (label-path x) (cdr x))

(define (branch-instruction? x)   (head-in? x branch-mnemonics))
(define (jump-instruction? x)     (head-in? x jump-mnemonics))
(define (call-instruction? x)     (head-in? x call-mnemonics))
(define (indirect-instruction? x) (head-in? x indirect-mnemonics))
(define (trap-instruction? x)     (head-in? x trap-mnemonics))

;; 执行会不会顺序落到物理下一条
(define (falls-through? x)
  (cond
    [(branch-instruction? x) #t]
    [(jump-instruction? x) #f]
    [(call-instruction? x) #t]
    [(indirect-instruction? x) (eq? (car x) 'call-indirect)]
    [(trap-instruction? x) #f]
    [else #t]))

(define (ends-block? x)
  (or (branch-instruction? x)
      (jump-instruction? x)
      (call-instruction? x)
      (indirect-instruction? x)
      (trap-instruction? x)))

(define (unconditional-jump? x)
  (jump-instruction? x))

;; 目标在最后: 分支/直接跳转/直接调用
(define (jump-target x)
  (and (or (branch-instruction? x)
           (jump-instruction? x)
           (call-instruction? x))
       (last x)))
