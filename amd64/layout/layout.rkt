#lang racket
;;; amd64/layout/layout.rkt
;;;
;;; 第一版扁平 item 布局：显式 place 锚点切段，按 item-size 累加偏移，
;;; align 变成 pad，记录 anchors。没有 CFG/blocks，也不做 relax。

(require "../sexp.rkt"
         "../analyze/analyze.rkt"
         "forms.rkt")

(provide layout-items
         layout-program
         program->layout-items)

(define (field field-name fields)
  (cond ((assq field-name fields) => cadr)
        [else #f]))

(define (parse-segment-form s)
  (unless (and (form? s) (eq? (car s) 'segment))
    (error 'layout "bad segment form: ~e" s))
  (define fields (cdr s))
  (define name (field 'name fields))
  (define kind (field 'kind fields))
  (define start (field 'start fields))
  (define end (field 'end fields))
  (define align (field 'align fields))
  (unless (symbol? name) (error 'layout "segment needs name: ~e" s))
  (unless (memq kind '(code data)) (error 'layout "bad segment kind: ~e" s))
  (unless (exact-integer? start) (error 'layout "segment needs start: ~e" s))
  (unless (or (not end) (exact-integer? end)) (error 'layout "bad segment end: ~e" s))
  (unless (or (not align) (exact-positive-integer? align))
    (error 'layout "bad segment align: ~e" s))
  (list (cons 'name name)
        (cons 'kind kind)
        (cons 'start start)
        (cons 'end end)
        (cons 'align align)))

(define (parse-spec spec)
  (define segments
    (map parse-segment-form
         (cdr (or (assq 'segments spec) '(segments)))))
  (define places
    (for/list ([p (in-list spec)]
               #:when (and (form? p) (eq? (car p) 'place)))
      (match p
        [(list 'place seg chain) (cons chain seg)]
        [_ (error 'layout "bad place line: ~e" p)])))
  (values segments places))

(define (segment-name seg) (cdr (assq 'name seg)))

(define (find-place places chain)
  (cond ((assoc chain places) => cdr)
        [else #f]))

(define (partition-items indexed-items places segment-names)
  ;; 先按 place 锚点把 item 分到段。每个 label 命中 place chain 时切段。
  ;; entry = (index . item)
  (define table (make-hash))
  (for ([name (in-list segment-names)]) (hash-set! table name '()))
  (define current #f)
  (for ([entry (in-list indexed-items)])
    (define item (cdr entry))
    (when (and (label-form? item)
               (find-place places (label-chain item)))
      (set! current (find-place places (label-chain item))))
    (cond
      [current (hash-update! table current (lambda (xs) (cons entry xs)) '())]
      [else (void)]))
  (for/hash ([(name xs) (in-hash table)])
    (values name (reverse xs))))

(define (layout-segment target seg items)
  (define name (cdr (assq 'name seg)))
  (define kind (cdr (assq 'kind seg)))
  (define start (cdr (assq 'start seg)))
  (define end (cdr (assq 'end seg)))
  (define cursor 0)
  (define out '())
  (define anchors '())
  (define entries '())
  (define requests '())
  (define problems '())
  (for ([entry (in-list items)])
    (define idx (car entry))
    (define item (cdr entry))
    (cond
      [(label-form? item)
       (set! anchors (cons (list 'anchor (label-chain item) name cursor) anchors))]
      [(comment-form? item) (void)]
      [(align-form? item)
       (define n (align-pad (+ start cursor) (cadr item)))
       (set! out (cons (list 'offset cursor (list 'pad n)) out))
       (set! cursor (+ cursor n))]
      [else
       (define kind* (item-kind item))
       (when (and (not (memq kind* '(marker both)))
                  (not (eq? kind* kind)))
         (set! problems (cons (list 'code-data-mixed name kind kind*) problems)))
       (define size (item-size item))
       (unless (exact-nonnegative-integer? size)
         (error 'layout "cannot size item in segment ~a: ~e" name item))
       (set! out (cons (list 'offset cursor item) out))
       (set! entries (cons (list idx cursor item size) entries))
       (set! cursor (+ cursor size))]))
  (define anchor-map
    (for/list ([a (in-list anchors)])
      (cons (cadr a) (cadddr a))))
  (for ([e (in-list (reverse entries))])
    (define idx (car e))
    (define offset (cadr e))
    (define item (caddr e))
    (define size (cadddr e))
    (when (branch-form? item)
      (define chain (normalize-path (branch-target item)))
      (define target-offset (and chain (cdr (assoc chain anchor-map))))
      (cond
        [(not target-offset)
         (set! problems (cons (list 'undefined-target idx chain) problems))]
        [else
         (define disp (- target-offset (+ offset size)))
         (define range (branch-range item))
         (unless (<= (car range) disp (cdr range))
           (if (short-branch-form? item)
               (set! requests (cons (list 'needs-near idx name offset item disp) requests))
               (set! problems (cons (list 'needs-far idx name offset item disp) problems))))])))
  (when (and end (> cursor (- end start)))
    (set! problems (cons (list 'segment-overflow name cursor (- end start)) problems)))
  (list (cons 'name name)
        (cons 'kind kind)
        (cons 'start start)
        (cons 'end end)
        (cons 'items (reverse out))
        (cons 'size cursor)
        (cons 'problems (reverse problems))
        (cons 'requests (reverse requests))
        (cons 'anchors (reverse anchors))))

(define (block->layout-items b)
  (define labels
    (for/list ([chain (in-list (block-head b))])
      (cons 'label chain)))
  (append labels (block-items b)))

(define (program->layout-items prog)
  (append* (for/list ([b (in-list (program-blocks prog))])
             (block->layout-items b))))

(define (layout-program target prog data-items spec)
  (layout-items target (append (program->layout-items prog) (as-items data-items)) spec))

(define (layout-items target items spec)
  (define-values (segments places) (parse-spec spec))
  (define names (map segment-name segments))
  (define indexed
    (for/list ([item (in-list (as-items items))] [i (in-naturals)])
      (cons i item)))
  (define by-segment (partition-items indexed places names))
  (define built
    (for/list ([seg (in-list segments)])
      (layout-segment target seg (hash-ref by-segment (segment-name seg) '()))))
  (define all-anchors (append* (map (lambda (s) (cdr (assq 'anchors s))) built)))
  (define all-problems (append* (map (lambda (s) (cdr (assq 'problems s))) built)))
  (define all-requests (append* (map (lambda (s) (cdr (assq 'requests s))) built)))
  (list (cons 'segments
              (for/list ([s (in-list built)])
                (list 'segment
                      (list 'name (cdr (assq 'name s)))
                      (list 'kind (cdr (assq 'kind s)))
                      (list 'start (cdr (assq 'start s)))
                      (list 'end (cdr (assq 'end s)))
                      (cons 'items (cdr (assq 'items s)))
                      (list 'size (cdr (assq 'size s))))))
        (cons 'anchors all-anchors)
        (cons 'requests all-requests)
        (cons 'problems all-problems)))
