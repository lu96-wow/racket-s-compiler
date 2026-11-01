#lang racket
;;; amd64/compiler/bind-labels/bind.rkt
;;;
;;; measured layout -> bound layout。
;;;
;;; 本层只做两件事:
;;;   1. anchor -> symbol（段 start + 偏移 = 绝对地址）
;;;   2. 用最终地址检查数据 value 是否放得进宽度
;;;
;;; 不改 item、不改 offset/size、不做松弛、不填 scratch。

(require "../../amd64-asm/sexp.rkt"
         "../../amd64-help/ranges.rkt"
         (only-in "../item.rkt" value-form? value-width value-payload)
         (only-in "../layout/forms.rkt"
                  anchor? anchor-chain anchor-segment anchor-position
                  offset? offset-position offset-item
                  layout-phase layout-segments layout-anchors
                  layout-requests layout-problems
                  layout-segment? layout-segment-name layout-segment-start
                  layout-segment-items
                  make-bound-layout make-problem)
         "forms.rkt")

(provide bind-labels)

(define (symbols->addresses symbols)
  (for/hash ([s (in-list symbols)])
    (values (symbol-chain s) (symbol-address s))))

(define (all-chains-known? expr symbols)
  (andmap (lambda (c) (hash-has-key? symbols c))
          (address-expr-chains expr)))

(define (check-value-widths segments symbols)
  (define problems '())
  (define (problem! p) (set! problems (cons p problems)))
  (for ([seg (in-list segments)])
    (unless (layout-segment? seg)
      (error 'bind-labels "bad layout segment: ~e" seg))
    (define seg-name (layout-segment-name seg))
    (for ([entry (in-list (layout-segment-items seg))])
      (unless (offset? entry)
        (error 'bind-labels "bad layout offset entry: ~e" entry))
      (define offset (offset-position entry))
      (define item (offset-item entry))
      (when (value-form? item)
        (define width (value-width item))
        (define payload (value-payload item))
        (define n
          (cond
            [(exact-integer? payload) payload]
            [(all-chains-known? payload symbols)
             (eval-address payload
                           (lambda (c) (hash-ref symbols c))
                           (+ (layout-segment-start seg) offset))]
            [else #f]))
        (when (and n (not (fits-width? n width)))
          (problem! (make-problem 'value-out-of-range seg-name offset item n))))))
  (reverse problems))

(define (bind-labels measured)
  (define phase (layout-phase measured))
  (unless (eq? phase 'measured)
    (error 'bind-labels "expected measured-layout, got phase ~e" phase))
  (define segments (layout-segments measured))
  (define anchors (layout-anchors measured))
  (define start-of
    (for/hash ([s (in-list segments)])
      (values (layout-segment-name s) (layout-segment-start s))))
  (define symbols
    (for/list ([a (in-list anchors)])
      (unless (anchor? a)
        (error 'bind-labels "bad anchor: ~e" a))
      (define chain (anchor-chain a))
      (define seg (anchor-segment a))
      (define offset (anchor-position a))
      (define start (hash-ref start-of seg #f))
      (unless start (error 'bind-labels "unknown segment in anchor: ~e" a))
      (make-symbol chain seg offset (+ start offset))))
  (define table (symbols->addresses symbols))
  (define extra (check-value-widths segments table))
  (make-bound-layout segments anchors symbols
                     (layout-requests measured)
                     (append (layout-problems measured) extra)))
