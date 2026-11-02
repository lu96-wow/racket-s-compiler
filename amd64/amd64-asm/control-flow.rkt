#lang racket
;;; amd64/amd64-asm/control-flow.rkt
;;;
;;; 指令 form 的控制流事实：执行完这条 form，控制会不会落到物理下一条？
;;;
;;; 这是**编码层的事实**，因为它回答的是"这条 form 是什么意思"，而 form 由
;;; special 表定义（`special/table.rkt` 里每个 form 带一个 flow 字段）。这里
;;; 只是把那张表包成一个面向"名字"的接口，给 analyze/dce/help 消费。
;;;
;;; 判据只有一条：
;;;   * form 的 flow 是 'jump / 'jump-indirect / 'stop → 不落下；
;;;   * 其余一律落下 —— 包括 NASM 生成表里的全部真实指令，以及 hlt / pause /
;;;     mwait / syscall / sysretq / iretq 这些"会暂停或离开本产物"的指令。
;;;
;;; 判错方向的代价不对称：判错"不落下"会让 DCE 删掉还在执行的代码（hlt 那次
;;; 就是：`syscall-hlt` 的队尾被当成不可达删掉，醒来落进下一条 syscall 实现，
;;; 垃圾 MSR → #GP → #DF）；判错"落下"只多留几字节。
;;;
;;; Σ 所以"不落下"是一份要证据的短名单，而且名单和编码行为放在同一张表里，
;;; 没有第二份手抄的助记符表。

(require "special.rkt")

(provide control-flow-kinds
         control-flow-of
         falls-through?
         control-flow-names-of-kind)

;; flow 的取值集合（文档 + 测试用）。
(define control-flow-kinds
  '(sequential jump branch call call-indirect jump-indirect stop))

(define (control-flow-of name)
  (or (and (symbol? name) (special-flow name)) 'sequential))

;; 会顺序落到物理下一条吗？
(define (falls-through? name)
  (not (memq (control-flow-of name) '(jump jump-indirect stop))))

;; 某个 kind 下的 form 名（排序后）。测试用它把 'stop 的名单钉死。
(define (control-flow-names-of-kind kind)
  (sort (for/list ([name (in-list (special-names))]
                   #:when (eq? (special-flow name) kind))
          name)
        symbol<?))
