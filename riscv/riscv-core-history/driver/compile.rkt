#lang racket
;;; driver/compile.rkt
;;;
;;; 统一驱动：resolved program / source forms -> encoded bytes。
;;;
;;; scratch budget 采用固定点重试：
;;;   budget = 0
;;;   失败于 scratch-exhausted -> budget + 1，重跑整条程序
;;;   成功或超过 max-scratch -> 结束
;;;
;;; 这是策略 B 的第一版驱动；各阶段仍然只报“scratch 不足”，
;;; 由 driver 统一增大 budget 后重跑。

(require racket/list
         "../core/sexp.rkt"
         "../frontend/main.rkt"
         "../ir/shape.rkt"
         "../ir/scratch.rkt"
         "../ir/allocate.rkt"
         "../ir/materialize.rkt"
         "../ir/call-plan.rkt"
         "../ir/frame.rkt"
         "../ir/lower.rkt"
         "../ir/call-lower.rkt"
         "../ir/verify-machine.rkt"
         "../layout/policy.rkt"
         "../layout/program.rkt"
         "../encode/encode.rkt")

(provide (struct-out compiled-program)
         runtime-forbidden
         compile-resolved-program
         compile-source
         compile-files)

;; call-lower / runtime contract 固定使用的物理寄存器，普通分配不能占用。
(define runtime-forbidden
  '((native x1) (native x2) (native x8) (native x10) (native x11)))

(struct compiled-program
  (bytes          ; bytevector
   layout         ; program-layout
   encoded        ; encoded-program
   exports        ; frontend exports；resolved 输入时为 '()
   scratch-budget)
  #:transparent)

(define (compile-resolved-program program
                                  #:policy [policy default-layout-policy]
                                  #:xlen [xlen 64]
                                  #:origin [origin 0]
                                  #:externs [externs '()]
                                  #:forbidden [forbidden runtime-forbidden]
                                  #:max-scratch [max-scratch 31])
  (unless (list? program)
    (error 'compile "expected a resolved program list: ~e" program))
  (unless (and (exact-nonnegative-integer? max-scratch))
    (error 'compile "max-scratch must be a non-negative integer: ~e" max-scratch))

  (define funcs
    (for/list ([item (in-list program)] #:when (tagged? item 'func)) item))
  (define others
    (for/list ([item (in-list program)] #:unless (tagged? item 'func)) item))

  (define (try budget)
    (define machine-funcs
      (for/list ([func (in-list funcs)])
        (compile-one-func func budget forbidden xlen)))
    (define layout
      (layout-program (append machine-funcs others)
                      #:policy policy
                      #:xlen xlen
                      #:origin origin
                      #:externs externs))
    (define encoded (encode-program layout #:xlen xlen))
    (compiled-program (encoded-program-bytes encoded)
                      layout
                      encoded
                      '()
                      budget))

  (let loop ([budget 0])
    (with-handlers ([scratch-exhausted?
                     (lambda (e)
                       (if (< budget max-scratch)
                           (loop (add1 budget))
                           (raise e)))])
      (try budget))))

(define (compile-source forms
                        #:policy [policy default-layout-policy]
                        #:xlen [xlen 64]
                        #:origin [origin 0]
                        #:forbidden [forbidden runtime-forbidden]
                        #:max-scratch [max-scratch 31])
  (define-values (resolved exports) (resolve-program forms))
  (define result
    (compile-resolved-program resolved
                              #:policy policy
                              #:xlen xlen
                              #:origin origin
                              #:forbidden forbidden
                              #:max-scratch max-scratch))
  (compiled-program (compiled-program-bytes result)
                    (compiled-program-layout result)
                    (compiled-program-encoded result)
                    exports
                    (compiled-program-scratch-budget result)))

(define (compile-files files
                       #:interface-files [interface-files '()]
                       #:policy [policy default-layout-policy]
                       #:xlen [xlen 64]
                       #:origin [origin 0]
                       #:forbidden [forbidden runtime-forbidden]
                       #:max-scratch [max-scratch 31])
  (define-values (resolved exports externs)
    (resolve-files-with-interfaces files interface-files))
  (define result
    (compile-resolved-program resolved
                              #:policy policy
                              #:xlen xlen
                              #:origin origin
                              #:externs externs
                              #:forbidden forbidden
                              #:max-scratch max-scratch))
  (compiled-program (compiled-program-bytes result)
                    (compiled-program-layout result)
                    (compiled-program-encoded result)
                    exports
                    (compiled-program-scratch-budget result)))

;; ---------------------------------------------------------------------------
;; 单个函数
;; ---------------------------------------------------------------------------

(define (compile-one-func func budget forbidden xlen)
  ;; allocate-func 自己会 verify-virtual。
  (define-values (allocation scratch)
    (allocate-func func #:scratch-budget budget #:forbidden forbidden))
  (define machine
    (materialize-func func allocation #:scratch scratch))
  (define plan (plan-calls machine #:xlen xlen))
  (define frame
    (frame-layout func allocation
                  #:xlen xlen
                  #:outgoing-size (call-plan-outgoing-size plan)))
  (define lowered
    (lower-func machine frame #:xlen xlen #:scratch scratch))
  (define called
    (lower-calls lowered frame #:xlen xlen #:scratch scratch))
  (verify-machine-func called)
  called)
