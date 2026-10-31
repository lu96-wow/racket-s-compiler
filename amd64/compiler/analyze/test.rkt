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

(displayln "amd64 analyze/dce tests: ok")
