#lang racket
;;; amd64/bind-labels/bind.rkt
;;;
;;; measured layout -> bound layout。只把 anchor 变成最终符号地址。

(require "../sexp.rkt")

(provide bind-labels)

(define (field key row)
  (cond ((assq key (cdr row)) => cadr)
        [else #f]))

(define (bind-labels measured)
  (define segments (cdr (assq 'segments measured)))
  (define anchors (cdr (assq 'anchors measured)))
  (define segment-info
    (for/hash ([s (in-list segments)])
      (values (field 'name s) s)))
  (define symbols
    (for/list ([a (in-list anchors)])
      (match a
        [(list 'anchor chain seg offset)
         (define s (hash-ref segment-info seg #f))
         (unless s (error 'bind-labels "unknown segment in anchor: ~e" a))
         (list 'symbol chain seg offset (+ (field 'start s) offset))]
        [_ (error 'bind-labels "bad anchor: ~e" a)])))
  (list (list 'phase 'bound)
        (cons 'segments segments)
        (cons 'anchors anchors)
        (cons 'symbols symbols)
        (cons 'requests (cdr (assq 'requests measured)))
        (cons 'problems (cdr (assq 'problems measured)))))
