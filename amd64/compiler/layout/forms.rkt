#lang racket
;;; amd64/compiler/layout/forms.rkt
;;;
;;; item 分类、尺寸和对齐。item 形状来自 amd64/item.rkt，
;;; 真实指令尺寸来自 amd64/insn.rkt。layout 不依赖 encode。

(require "../item.rkt"
         "../../amd64-asm/insn.rkt"
         (only-in "../../amd64-help/branch.rkt"
                  control-transfer-form? short-control-transfer-form?
                  near-control-transfer-form? control-transfer-target
                  control-transfer-range))

(provide form? name? path? normalize-path

         make-segment segment? segment-name segment-kind segment-start segment-end segment-align
         make-segment-form parse-segment-form
         make-offset offset? offset-position offset-item
         make-anchor anchor? anchor-chain anchor-segment anchor-position
         make-request request? request-kind request-payload
         make-problem problem? problem-kind problem-detail

         make-layout-segment layout-segment?
         layout-segment-name layout-segment-kind layout-segment-start
         layout-segment-end layout-segment-items layout-segment-size
         make-measured-layout make-bound-layout
         layout-phase layout-segments layout-anchors layout-symbols
         layout-requests layout-problems

         make-place place? place-segment place-chains
         make-layout-spec layout-spec? layout-spec-segments layout-spec-places

         label-form? label-chain
         comment-form?
         align-form? align-value
         pad-form? pad-size
         bytes-form? bytes-content
         fill-form? fill-size fill-byte
         value-form? value-width value-payload
         reserve-form? reserve-size
         item-kind item-size item-kind-allowed-in?
         align-pad
         control-transfer-form? short-control-transfer-form? near-control-transfer-form?
         control-transfer-target control-transfer-range)


;; ---------------------------------------------------------------------------
;; Layout IR constructors/accessors
;; ---------------------------------------------------------------------------

(struct segment (name kind start end align) #:transparent)

(define (make-segment name kind start end align)
  (unless (symbol? name) (error 'make-segment "segment name must be a symbol: ~e" name))
  (unless (memq kind '(code data hole))
    (error 'make-segment "segment kind must be code/data/hole: ~e" kind))
  (unless (exact-integer? start)
    (error 'make-segment "segment start must be an integer: ~e" start))
  (unless (exact-integer? end)
    (error 'make-segment "segment end must be an integer: ~e" end))
  (unless (exact-positive-integer? align)
    (error 'make-segment "segment align must be positive: ~e" align))
  (segment name kind start end align))

(define (field-value key fields)
  (cond ((assq key fields) => cadr)
        [else #f]))

(define (make-segment-form name kind start end align)
  (make-segment name kind start end align)
  (list 'segment
        (list 'name name)
        (list 'kind kind)
        (list 'start start)
        (list 'end end)
        (list 'align align)))

(define (parse-segment-form s)
  (unless (and (form? s) (eq? (car s) 'segment))
    (error 'parse-segment-form "bad segment form: ~e" s))
  (define fields (cdr s))
  (make-segment (field-value 'name fields)
                (field-value 'kind fields)
                (field-value 'start fields)
                (field-value 'end fields)
                (field-value 'align fields)))

(define (make-offset position item)
  (unless (exact-nonnegative-integer? position)
    (error 'make-offset "offset must be a non-negative integer: ~e" position))
  (list 'offset position item))

(define (offset? x)
  (and (form? x) (eq? (car x) 'offset) (= 3 (length x)) #t))
(define (offset-position x) (cadr x))
(define (offset-item x) (caddr x))

(define (make-anchor chain segment position)
  (list 'anchor (normalize-path chain) segment position))

(define (anchor? x)
  (and (form? x) (eq? (car x) 'anchor) (= 4 (length x)) #t))
(define (anchor-chain x) (cadr x))
(define (anchor-segment x) (caddr x))
(define (anchor-position x) (cadddr x))

(define (make-request kind . payload)
  (unless (symbol? kind)
    (error 'make-request "request kind must be a symbol: ~e" kind))
  (cons kind payload))
(define (request? x)
  (and (form? x) (symbol? (car x)) #t))
(define (request-kind x) (car x))
(define (request-payload x) (cdr x))

(define (make-problem kind . detail)
  (unless (symbol? kind)
    (error 'make-problem "problem kind must be a symbol: ~e" kind))
  (cons kind detail))
(define (problem? x)
  (and (form? x) (symbol? (car x)) #t))
(define (problem-kind x) (car x))
(define (problem-detail x) (cdr x))


;; ---------------------------------------------------------------------------
;; Measured/bound layout s-expression
;; ---------------------------------------------------------------------------

(define (layout-field key x)
  (cond ((assq key (cdr x)) => cadr)
        [else #f]))

(define (make-layout-segment name kind start end items size)
  (list 'segment
        (list 'name name)
        (list 'kind kind)
        (list 'start start)
        (list 'end end)
        (cons 'items items)
        (list 'size size)))

(define (layout-segment? x)
  (and (form? x) (eq? (car x) 'segment)
       (layout-field 'name x)
       (layout-field 'kind x)
       (layout-field 'start x)
       (layout-field 'size x)
       #t))
(define (layout-segment-name x) (layout-field 'name x))
(define (layout-segment-kind x) (layout-field 'kind x))
(define (layout-segment-start x) (layout-field 'start x))
(define (layout-segment-end x) (layout-field 'end x))
(define (layout-segment-items x)
  (cond ((assq 'items (cdr x)) => cdr)
        [else '()]))
(define (layout-segment-size x) (layout-field 'size x))

(define (make-measured-layout segments anchors requests problems)
  (list (list 'phase 'measured)
        (cons 'segments segments)
        (cons 'anchors anchors)
        (cons 'requests requests)
        (cons 'problems problems)))

(define (make-bound-layout segments anchors symbols requests problems)
  (list (list 'phase 'bound)
        (cons 'segments segments)
        (cons 'anchors anchors)
        (cons 'symbols symbols)
        (cons 'requests requests)
        (cons 'problems problems)))

(define (layout-phase x) (cadr (or (assq 'phase x) '(phase #f))))
(define (layout-segments x) (cdr (or (assq 'segments x) '(segments))))
(define (layout-anchors x) (cdr (or (assq 'anchors x) '(anchors))))
(define (layout-symbols x) (cdr (or (assq 'symbols x) '(symbols))))
(define (layout-requests x) (cdr (or (assq 'requests x) '(requests))))
(define (layout-problems x) (cdr (or (assq 'problems x) '(problems))))


(define (make-place segment chains)
  (unless (symbol? segment)
    (error 'make-place "place segment must be a symbol: ~e" segment))
  (unless (and (list? chains) (andmap (lambda (c) (or (eq? c '*) (path? c))) chains))
    (error 'make-place "place chains must be chains or *: ~e" chains))
  (cons 'place (cons segment chains)))

(define (place? x)
  (and (form? x) (eq? (car x) 'place) (>= (length x) 2)))
(define (place-segment x) (cadr x))
(define (place-chains x) (cddr x))

(define (make-layout-spec segments places)
  (cons (cons 'segments segments) places))

(define (layout-spec? x)
  (and (list? x)
       (for/first ([clause (in-list x)] #:when (eq? (car clause) 'segments)) #t)
       #t))
(define (layout-spec-segments spec)
  (cdr (or (assq 'segments spec) '(segments))))
(define (layout-spec-places spec)
  (filter place? spec))

(define (item-size target x)
  (cond
    [(label-form? x) 0]
    [(comment-form? x) 0]
    [(align-form? x) #f]
    [(pad-form? x) (pad-size x)]
    [(bytes-form? x) (length (bytes-content x))]
    [(fill-form? x) (fill-size x)]
    [(reserve-form? x) (reserve-size x)]
    [(value-form? x) (value-width x)]
    [else (instruction-size target (car x) (cdr x))]))

(define (align-pad absolute-address alignment)
  (modulo (- alignment (modulo absolute-address alignment)) alignment))

;; 段 kind -> 它收哪些 item 类。
;; code 段可以放数据(ELF/multiboot header、跳转表…), 这是本后端的事实;
;; hole 段只收位置类: 洞里的地址没有字节可对应。
(define (item-kind-allowed-in? ik kind)
  (and (case kind
         [(code) (memq ik '(marker align pad materialized code))]
         [(data) (memq ik '(marker align pad materialized))]
         [(hole) (memq ik '(marker align space))]
         [else #f])
       #t))
