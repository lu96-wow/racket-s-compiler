#lang racket
;;; amd64/compiler/relax/relax.rkt
;;;
;;; 分支松弛: short -> near，只增不减。
;;;
;;; 本层只消费 layout 的 needs-near request，并按 request 里的
;;; (code 块下标 项下标) 精确替换 program 里的那一条 item。
;;; 不造 label、不改 CFG、不处理 far/trampoline/scratch。

(require "../../amd64-asm/sexp.rkt"
         "../layout/layout.rkt"
         (only-in "../layout/forms.rkt"
                  layout-requests request? request-kind
                  request-origin request-origin-kind request-origin-block
                  request-origin-index request-item)
         (only-in "../analyze/analyze.rkt"
                  program program-blocks program-flows
                  block-head block-items make-block))

(provide relax
         promote-short-control-transfer
         needs-near?)

(define max-rounds 64)

;; 只有"代码段里的 short 形式放不下"才需要松弛; 别的 request 是本层之外的事。
(define (needs-near? request)
  (and (request? request)
       (eq? (request-kind request) 'needs-near)
       (eq? (request-origin-kind request) 'code)))

(define (promote-short-control-transfer item)
  (case (car item)
    [(jmp-short) (cons 'jmp-near (cdr item))]
    [(jcc-short) (cons 'jcc-near (cdr item))]
    [else item]))

(define (collect-edits requests)
  (for/list ([r (in-list requests)] #:when (needs-near? r))
    (cons (list (request-origin-block r) (request-origin-index r))
          (promote-short-control-transfer (request-item r)))))

(define (apply-edits prog edits)
  (define table (make-hash))
  (for ([e (in-list edits)]) (hash-set! table (car e) (cdr e)))
  (program
   (for/list ([b (in-list (program-blocks prog))] [bi (in-naturals)])
     (make-block
      (block-head b)
      (for/list ([it (in-list (block-items b))] [ii (in-naturals)])
        (hash-ref table (list bi ii) it))))
   (program-flows prog)))

(define (relax target program data-items spec)
  (let loop ([prog program] [round 0])
    (define measured (layout-program target prog data-items spec))
    (define requests (layout-requests measured))
    (define edits (collect-edits requests))
    (cond
      [(or (null? edits) (>= round max-rounds)) measured]
      [else (loop (apply-edits prog edits) (add1 round))])))
