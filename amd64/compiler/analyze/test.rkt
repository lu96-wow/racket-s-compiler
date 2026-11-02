#lang racket
;;; amd64/compiler/analyze/test.rkt

(require rackunit
         "analyze.rkt"
         "insn.rkt"
         "../dce/dce.rkt")

(define (analyze* items) (analyze items '()))

(check-true (branch-instruction? '(jcc-near e (x))))
(check-true (jump-instruction? '(jmp-short (x))))
(check-true (call-instruction? '(call-near (x))))
(check-true (indirect-instruction? '(jmp-indirect rax)))
(check-true (trap-instruction? '(ret)))
(check-false (ends-block? '(mov rax rbx)))
(check-true (ends-block? '(call-near (f))))
(check-true (falls-through? '(call-near (f))))
(check-false (falls-through? '(jmp-near (f))))

(define prog
  (analyze*
   '((label text)
     (mov rax rbx)
     (jcc-near e (done))
     (add rax 1)
     (label done)
     (ret))))

(check-equal? (map block-head (program-blocks prog))
              '(((text)) () ((done))))
(check-equal? (map flow-succ (program-flows prog))
              '((2 1) (2) ()))
(check-equal? (map flow-fallthrough (program-flows prog))
              '(1 2 #f))
(check-equal? (map flow-root? (program-flows prog))
              '(#t #f #f))

(define dead
  (analyze*
   '((label text)
     (jmp-near (done))
     (label dead)
     (mov rax rbx)
     (label done)
     (ret))))

(check-equal? (map block-head (program-blocks dead))
              '(((text)) ((dead)) ((done))))

(define optimized (eliminate-dead dead))
(check-equal? (map block-head (program-blocks optimized))
              '(((text) (done))))

;; ---------------------------------------------------------------------------
;; 回归: "会顺序落下"的指令后面不能因为 CFG 少一条边而被 DCE 删掉
;;
;; 曾经的 bug: `hlt` 被归进 trap-mnemonics（和 ret/ud2 一组），CFG 认为
;; `hlt` 之后不可达，DCE 把 Loko 的 syscall-hlt 队尾 (cli/swapgs/sysretq)
;; 删了；hlt 被中断唤醒后顺序落进下一条 syscall 实现 -> 垃圾 MSR -> #GP -> #DF。
;; 这里用运行库里的真实序列当判据，而不是断言"表里有没有 hlt"。
;; ---------------------------------------------------------------------------

(define (items-of prog)
  (append* (for/list ([b (in-list (program-blocks prog))])
             (append (for/list ([chain (in-list (block-head b))])
                       (cons 'label chain))
                     (block-items b)))))

(define syscall-hlt-sequence
  '((label text)
    (label syscall-hlt)
    (sti)
    (hlt)
    (cli)
    (xor eax eax)
    (swapgs)
    (sysretq)
    (label syscall-rdmsr)
    (rdmsr)))

(check-equal? (items-of (eliminate-dead (analyze* syscall-hlt-sequence)))
              syscall-hlt-sequence
              "hlt 之后是顺序执行, 后面的代码必须活下来")

;; 这类"暂停/让出 CPU 之后还会继续"的指令一律算顺序落下。
;; 只有硬件上真的不落下的 (ret/ud2) 才算不落下 —— 名单越短越安全。
(for ([mn (in-list '((hlt) (pause) (nop) (syscall) (sysretq) (iretq)
                     (rdmsr) (wrmsr) (cpuid) (mov rax rbx)))])
  (check-true (falls-through? mn) (format "~a 必须顺序落下" mn)))
(check-false (falls-through? '(ret)))
(check-false (falls-through? '(ud2)))

(displayln "amd64 analyze/dce tests: ok")
