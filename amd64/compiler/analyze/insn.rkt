#lang racket
;;; amd64/compiler/analyze/insn.rkt
;;;
;;; amd64 指令分类。只分类，不改写。
;;;
;;;   branch   jcc-short/near      目标 + 顺序
;;;   jump     jmp-short/near       只有目标
;;;   call     call-near            目标 + 顺序(调用会返回)
;;;   indirect jmp-indirect/call-indirect
;;   term     ret/ud2              不返回
;;
;;; 注意 `hlt` **不是**终止指令：它会在中断之后继续执行下一条。Loko 的
;;; `syscall-hlt` 就靠这一点:
;;;     (sti) (hlt) (cli) (xor eax eax) (swapgs) (sysretq)
;;; 把 hlt 当成"不返回"会让 CFG 认为后面的 cli/swapgs/sysretq 不可达,
;;; DCE 于是把整个队尾删掉, 结果 hlt 之后**顺序落进下一条 syscall 实现**
;;; (实测: 落进 syscall-rdmsr 里的 rdmsr, 用垃圾 MSR 号 -> #GP -> #DF)。
;;;
;;; 不认识的指令当普通指令。
;;;
;;; 关键约定(2024 review 后): **"不顺序落下" 是一份要证据的名单**。
;;; 只有两类可以有这个结论:
;;;   1. 我们自己生成的转移形式(jmp-* / jmp-indirect) —— 目标是我们摆的;
;;;   2. 硬件保证不继续的两条指令(ret / ud2)。
;;; 其余的助记符一律按"会落下去"处理。理由: 判错"不落下"的代价是 DCE 把
;;; 后面还会执行的代码删掉(见上面 hlt 的例子), 而判错"落下"只会多留几字节。

;;; 只提供"一条 item 是哪类控制流指令"。形状（form?/path?）在
;;; amd64-asm/shape.rkt，label 访问器在 compiler/item.rkt —— 这里不转发它们，
;;; 否则每个下游模块都会顺手拿到一堆不属于本层的东西。

(require "../../amd64-asm/shape.rkt")

(provide branch-instruction? jump-instruction? call-instruction?
         indirect-instruction? trap-instruction?
         ends-block? falls-through? non-fallthrough-reason
         audited-non-fallthrough-mnemonics
         unconditional-jump?
         jump-target)

(define branch-mnemonics '(jcc-short jcc-near))
(define jump-mnemonics '(jmp-short jmp-near))
(define call-mnemonics '(call-near))
(define indirect-mnemonics '(jmp-indirect call-indirect))

;; 靠助记符判定"不会继续执行到物理下一条"的指令。**名单故意这么短**：
;; 加一条之前先回答"硬件凭什么保证它不继续"。反例: hlt(中断后继续)、
;; pause、mwait、sysretq/iretq(控制权离开, 但在本产物里按顺序处理更保守)。
(define audited-non-fallthrough-mnemonics '(ret ud2))

(define trap-mnemonics audited-non-fallthrough-mnemonics)

(define (head-in? x heads)
  (and (form? x) (memq (car x) heads) #t))

(define (branch-instruction? x)   (head-in? x branch-mnemonics))
(define (jump-instruction? x)     (head-in? x jump-mnemonics))
(define (call-instruction? x)     (head-in? x call-mnemonics))
(define (indirect-instruction? x) (head-in? x indirect-mnemonics))
(define (trap-instruction? x)     (head-in? x trap-mnemonics))

;; 这条 item 为什么不会顺序执行到物理下一条: 'jump / 'indirect / 'ret / 'ud2 / #f。
;; 返回 #f = 会落下(默认)。"不落下"只能来自下面这四种, 见文件头的约定。
(define (non-fallthrough-reason x)
  (cond
    [(jump-instruction? x) 'jump]
    [(indirect-instruction? x) (and (eq? (car x) 'jmp-indirect) 'indirect)]
    [(and (form? x) (symbol? (car x))
          (memq (car x) audited-non-fallthrough-mnemonics))
     (car x)]
    [else #f]))

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
