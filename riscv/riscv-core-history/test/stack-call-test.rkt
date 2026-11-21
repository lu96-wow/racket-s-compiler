#lang racket
;;; test/stack-call-test.rkt
;;;
;;; stack-first call 的完整链路：
;;; allocate -> materialize -> call-plan -> frame-layout -> lower-ops
;;; -> call-lower -> program-layout -> encode-program。
;;;
;;; 重点：slot 参数先由 materialize load 到 scratch，call-lower 不能再用
;;; 同一个 scratch 覆盖它；slot 返回值在 call 后 store。

(require rackunit
         racket/list
         "../core/sexp.rkt"
         "../ir/allocate.rkt"
         "../ir/materialize.rkt"
         "../ir/call-plan.rkt"
         "../ir/frame.rkt"
         "../ir/lower.rkt"
         "../ir/call-lower.rkt"
         "../ir/verify-machine.rkt"
         "../layout/program.rkt"
         "../encode/encode.rkt")

(define runtime-forbidden
  '((native x1) (native x2) (native x8) (native x10) (native x11)))

(define stack-call-virtual
  '(func (main)
     (vregs
       (($ x) (b64) (address-taken))
       (($ r) (b64) (address-taken)))
     (entry b0)
     (block b0
       (const ($ x) 7)
       (call ($ r) (global (f)) ($ x))
       (term (return 0)))))

(define (block-forms func block-name)
  (define block
    (findf (lambda (x)
             (and (form? x) (eq? (car x) 'block) (eq? (cadr x) block-name)))
           (cddr func)))
  (unless block (error 'test "missing block ~a" block-name))
  (cddr block))

(define callee
  '(func (f)
     (frame (size 16) (header 16) (outgoing 0) (align 16) (slots))
     (entry b0)
     (block b0
       (term (return)))))

(test-case "stack-first call goes through the whole pipeline"
  (define-values (allocation scratch)
    (allocate-func stack-call-virtual
                   #:scratch-budget 2
                   #:forbidden runtime-forbidden))

  (check-equal? allocation
                '(allocation
                   (($ x) (slot 0))
                   (($ r) (slot 1))))
  (check-equal? scratch '(scratch (native x3) (native x4)))

  (define machine
    (materialize-func stack-call-virtual allocation #:scratch scratch))
  ;; 参数和返回值都经过 scratch，且 slot 结果在 call 后 store。
  (define machine-ops (block-forms machine 'b0))
  (check-not-false (member '(load (native x3) (frame-slot 0) 0 (b64))
                           machine-ops))
  (check-not-false (member '(call (native x3) (global (f)) (native x3))
                           machine-ops))
  (check-not-false (member '(store (frame-slot 1) 0 (native x3) (b64))
                           machine-ops))

  (define plan (plan-calls machine))
  (define frame
    (frame-layout stack-call-virtual allocation
                  #:outgoing-size (call-plan-outgoing-size plan)))
  (check-equal? (frame-outgoing frame) 16)
  (check-equal? (frame-size frame) 48)

  (define lowered (lower-func machine frame #:scratch scratch))
  (define called (lower-calls lowered frame #:scratch scratch))
  (verify-machine (list called))

  ;; 参数写到 outgoing area；call 的结果回到 x3 后再写 r 的 slot。
  (define ops (block-forms called 'b0))
  (check-not-false (member '(sd 0 (native x2) (native x3)) ops))
  (check-not-false (member '(call-target (global (f))) ops))
  (check-not-false (member '(addi (native x3) (native x10) 0) ops))
  (check-not-false (member '(sd -32 (native x8) (native x3)) ops))

  ;; 程序级布局把 call-target 解析成近调用；callee 紧跟 main。
  (define program (layout-program (list called callee)))
  (define main-section (car (program-layout-sections program)))
  (define main-items (function-section-items main-section))
  (check-equal? (program-layout-size program) 76)
  (check-equal? (function-section-size main-section) 72)
  (check-true (and (member '(call-jal 36) main-items) #t))
  (check-false (ormap (lambda (item) (eq? (car item) 'call-target)) main-items))

  (define enc (encode-program program))
  (check-equal? (encoded-program-size enc) 76)
  (check-equal? (map encoded-section-base (encoded-program-sections enc))
                '(0 72)))
