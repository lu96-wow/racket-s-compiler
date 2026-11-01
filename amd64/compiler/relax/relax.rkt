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
                  request? request-kind request-payload)
         (only-in "../analyze/analyze.rkt"
                  program program-blocks program-flows
                  block-head block-items make-block))

(provide relax
         promote-short-control-transfer
         needs-near?)

(define max-rounds 64)

(define (needs-near? request)
  (and (request? request)
       (eq? (request-kind request) 'needs-near)
       (let ([origin (car (request-payload request))])
         (and (form? origin) (eq? (car origin) 'code)))))

(define (promote-short-control-transfer item)
  (case (car item)
    [(jmp-short) (cons 'jmp-near (cdr item))]
    [(jcc-short) (cons 'jcc-near (cdr item))]
    [else item]))

(define (collect-edits requests)
  (for/list ([r (in-list requests)] #:when (needs-near? r))
    (define origin (car (request-payload r)))
    (define item (list-ref (request-payload r) 3))
    (cons (list (cadr origin) (caddr origin))
          (promote-short-control-transfer item))))

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
    (define requests (cdr (or (assq 'requests measured) '(requests))))
    (define edits (collect-edits requests))
    (cond
      [(or (null? edits) (>= round max-rounds)) measured]
      [else (loop (apply-edits prog edits) (add1 round))])))
