#lang racket
;;; amd64/tools/run-test.rkt
;;;
;;; 跑一个测试文件，只要有一个 `check-*` 失败就以非零退出。
;;;
;;; 为什么需要它：rackunit 的 `check-*` 失败只打印 FAILURE，**不影响退出码**。
;;; 所以 `racket test.rkt` 永远返回 0 —— 假绿（踩过好几次）。
;;;
;;; 做法：把 `current-check-handler` 换成一个计数包装，仍然调用原来的 handler
;;; （保留 rackunit 的 FAILURE 输出），跑完后按计数决定退出码。这样测试文件
;;; 本身不用改，也可以单独 `racket test.rkt` 交互式跑。
;;;
;;; 用法:
;;;   racket tools/run-test.rkt <test-file.rkt>

(require rackunit
         racket/cmdline)

(define failure-count 0)
(define inner-handler (current-check-handler))

(current-check-handler
 (lambda (info)
   (set! failure-count (add1 failure-count))
   (inner-handler info)))

(command-line
 #:program "run-test"
 #:args (path)
 (dynamic-require (string->path path) #f)
 (when (> failure-count 0)
   (eprintf "run-test: ~a check(s) failed in ~a\n" failure-count path)
   (exit 1)))
