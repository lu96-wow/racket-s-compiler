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
         (only-in "../item.rkt" value-form? value-width value-payload))

(provide bind-labels)

(define (field-value key row)
  (cond ((assq key (cdr row)) => cadr)
        [else #f]))

(define (symbols->addresses symbols)
  (for/hash ([s (in-list symbols)])
    (values (cadr s) (cadddr (cdr s)))))

(define (all-chains-known? expr symbols)
  (andmap (lambda (c) (hash-has-key? symbols c))
          (address-expr-chains expr)))

(define (check-value-widths segments symbols)
  (define problems '())
  (define (problem! p) (set! problems (cons p problems)))
  (for ([seg (in-list segments)])
    (define seg-name (field-value 'name seg))
    (define items-hit (assq 'items (cdr seg)))
    (for ([entry (in-list (if items-hit (cdr items-hit) '()))])
      (define offset (cadr entry))
      (define item (caddr entry))
      (when (value-form? item)
        (define width (value-width item))
        (define payload (value-payload item))
        (define n
          (cond
            [(exact-integer? payload) payload]
            [(all-chains-known? payload symbols)
             (eval-address payload (lambda (c) (hash-ref symbols c)))]
            [else #f]))
        (when (and n (not (fits-width? n width)))
          (problem! (list 'value-out-of-range seg-name offset item n))))))
  (reverse problems))

(define (bind-labels measured)
  (define phase (and (assq 'phase measured) (cadr (assq 'phase measured))))
  (unless (eq? phase 'measured)
    (error 'bind-labels "expected measured-layout, got phase ~e" phase))
  (define segments (cdr (assq 'segments measured)))
  (define anchors (cdr (assq 'anchors measured)))
  (define segment-info
    (for/hash ([s (in-list segments)])
      (values (field-value 'name s) s)))
  (define symbols
    (for/list ([a (in-list anchors)])
      (match a
        [(list 'anchor chain seg offset)
         (define s (hash-ref segment-info seg #f))
         (unless s (error 'bind-labels "unknown segment in anchor: ~e" a))
         (list 'symbol chain seg offset (+ (field-value 'start s) offset))]
        [_ (error 'bind-labels "bad anchor: ~e" a)])))
  (define table (symbols->addresses symbols))
  (define extra (check-value-widths segments table))
  (list (list 'phase 'bound)
        (cons 'segments segments)
        (cons 'anchors anchors)
        (cons 'symbols symbols)
        (cons 'requests (cdr (assq 'requests measured)))
        (cons 'problems (append (cdr (assq 'problems measured)) extra))))
