#lang racket
;;; amd64/compiler/layout/layout.rkt
;;;
;;; 布局: program blocks + data runs + layout-spec -> measured-layout.
;;;
;;; 本层只做“放置 + 度量 + 问题”:
;;;   - 按 place 把代码块/数据 run 放进段
;;;   - 按块内/run 内顺序累加尺寸
;;;   - align 换成 pad / reserve 事实（看段 kind）
;;;   - 记录 anchors、requests、problems
;;;
;;; 不改程序、不选远形式、不填 scratch、不生成绝对符号。
;;; 绝对地址由 bind-labels 统一产生。

(require "../../amd64-asm/sexp.rkt"
         "../../amd64-asm/target.rkt"
         "../../amd64-help/ranges.rkt"
         "forms.rkt"
         (only-in "../analyze/analyze.rkt"
                  program? program-blocks program-flows
                  block-head block-items flow-fallthrough))

(provide layout-flat-items
         layout-program)

;; ---------------------------------------------------------------------------
;; 段 / 放置规则
;; ---------------------------------------------------------------------------

(struct segment (name kind start end align) #:transparent)

(define (field-value key fields)
  (cond ((assq key fields) => cadr)
        [else #f]))

(define (parse-segment-form s)
  (unless (and (form? s) (eq? (car s) 'segment))
    (error 'layout "bad segment form: ~e" s))
  (define fields (cdr s))
  (define name (field-value 'name fields))
  (define kind (field-value 'kind fields))
  (define start (field-value 'start fields))
  (define end (field-value 'end fields))
  (define align (field-value 'align fields))
  (unless (symbol? name) (error 'layout "segment needs name: ~e" s))
  (unless (memq kind '(code data hole)) (error 'layout "bad segment kind: ~e" s))
  (unless (exact-integer? start) (error 'layout "segment needs start: ~e" s))
  (unless (exact-integer? end) (error 'layout "segment needs end: ~e" s))
  (unless (exact-positive-integer? align) (error 'layout "segment needs align: ~e" s))
  (segment name kind start end align))

(define (validate-segments segments problem!)
  (define names (map segment-name segments))
  (unless (= (length names) (length (remove-duplicates names)))
    (problem! (list 'segment-name-duplicated names)))
  (for ([s (in-list segments)])
    ;; Empty sections are valid: start may equal end (an unused data section, a
    ;; hole with no addresses yet, ...).  RISC-V is stricter here; amd64 is not.
    (unless (<= (segment-start s) (segment-end s))
      (problem! (list 'segment-bad-range (segment-name s))))
    (unless (zero? (modulo (segment-start s) (segment-align s)))
      (problem! (list 'segment-misaligned
                      (segment-name s) (segment-start s) (segment-align s)))))
  (define n (length segments))
  (for* ([i (in-range n)] [j (in-range n)] #:when (< i j))
    (define a (list-ref segments i))
    (define b (list-ref segments j))
    (when (and (< (segment-start a) (segment-end b))
               (< (segment-start b) (segment-end a)))
      (problem! (list 'segment-overlap (segment-name a) (segment-name b))))))

;; rules: ((链 . 段名) ...); wildcard: 段名或 #f
(define (parse-places spec segments problem!)
  (define names (map segment-name segments))
  (define rules '())
  (define wildcard #f)
  (for ([p (in-list spec)]
        #:when (and (form? p) (eq? (car p) 'place)))
    (match (cdr p)
      [(cons seg chains)
       (cond
         [(not (memq seg names))
          (problem! (list 'unknown-segment seg))]
         [(null? chains)
          (problem! (list 'bad-place p))]
         [else
          (for ([c (in-list chains)])
            (cond
              [(eq? c '*)
               (if wildcard
                   (problem! (list 'ambiguous-wildcard wildcard seg))
                   (set! wildcard seg))]
              [else
               (define path (normalize-path c))
               (if path
                   (set! rules (cons (cons path seg) rules))
                   (problem! (list 'bad-place-chain c)))]))])]
      [_ (problem! (list 'bad-place p))]))
  (values (reverse rules) wildcard))

(define (parse-spec spec problem!)
  (define segments
    (map parse-segment-form
         (cdr (or (assq 'segments spec) '(segments)))))
  (validate-segments segments problem!)
  (define-values (rules wildcard) (parse-places spec segments problem!))
  (values segments rules wildcard))

;; ---------------------------------------------------------------------------
;; 放置单位
;;
;;   code: analyze 的 block
;;   data: 从一条 label 到下一条 label 的 run
;;   flat: layout-flat-items 的兼容输入，按 place 标签切分
;; ---------------------------------------------------------------------------

(struct unit (id labels items) #:transparent)

(define (program->units prog)
  (for/list ([b (in-list (program-blocks prog))] [i (in-naturals)])
    (unit (list 'code i) (block-head b) (block-items b))))

(define (data-items->units items)
  (define out '())
  (define labels '())
  (define body '())
  (define (flush!)
    (when (or (pair? labels) (pair? body))
      (set! out (cons (cons (reverse labels) (reverse body)) out))
      (set! labels '())
      (set! body '())))
  (for ([it (in-list items)])
    (cond
      [(label-form? it)
       (when (pair? body) (flush!))
       (set! labels (cons (label-chain it) labels))]
      [else (set! body (cons it body))]))
  (flush!)
  (for/list ([r (in-list (reverse out))] [i (in-naturals)])
    (unit (list 'data i) (car r) (cdr r))))

(define (placed-chain? rules wildcard chain)
  (or wildcard
      (for/or ([r (in-list rules)]) (equal? chain (car r)))))

(define (flat-items->units items rules wildcard)
  (define out '())
  (define labels '())
  (define body '())
  (define (flush!)
    (when (or (pair? labels) (pair? body))
      (set! out (cons (cons (reverse labels) (reverse body)) out))
      (set! labels '())
      (set! body '())))
  (for ([it (in-list items)])
    (cond
      [(label-form? it)
       (define chain (label-chain it))
       (cond
         [(placed-chain? rules wildcard chain)
          (if (and (pair? labels) (null? body))
              ;; consecutive labels at the same position stay aliases
              (set! labels (cons chain labels))
              (begin
                (flush!)
                (set! labels (list chain))))]
         [(null? body)
          (set! labels (cons chain labels))]
         [else
          ;; non-place label inside an item sequence: keep it as a marker
          (set! body (cons it body))])]
      [else (set! body (cons it body))]))
  (flush!)
  (for/list ([r (in-list (reverse out))] [i (in-naturals)])
    (unit (list 'flat i) (car r) (cdr r))))

;; ---------------------------------------------------------------------------
;; 放置
;; ---------------------------------------------------------------------------

(define (matching-segment-names rules labels)
  (remove-duplicates
   (for*/list ([chain (in-list labels)]
               [r (in-list rules)]
               #:when (equal? chain (car r)))
     (cdr r))))

(define (add-unit! table seg u)
  (hash-update! table seg (lambda (xs) (append xs (list u))) '()))

(define (place-code-units units rules wildcard problem!)
  (define by-seg (make-hash))
  (define current #f)
  (for ([u (in-list units)])
    (define labels (unit-labels u))
    (define hits (matching-segment-names rules labels))
    (cond
      [(> (length hits) 1)
       (problem! (list 'ambiguous-placement labels hits))]
      [(= 1 (length hits))
       (set! current (car hits))
       (add-unit! by-seg current u)]
      [current (add-unit! by-seg current u)]
      [wildcard
       (set! current wildcard)
       (add-unit! by-seg current u)]
      [else
       (problem! (list 'unplaced-block (unit-id u) labels))]))
  by-seg)

(define (place-exact-units units rules wildcard problem! unplaced-kind)
  (define by-seg (make-hash))
  (for ([u (in-list units)])
    (define labels (unit-labels u))
    (cond
      [(null? labels)
       (problem! (list 'unlabeled-run (unit-id u) (unit-items u)))]
      [else
       (define hits (matching-segment-names rules labels))
       (cond
         [(> (length hits) 1)
          (problem! (list 'ambiguous-placement labels hits))]
         [(= 1 (length hits)) (add-unit! by-seg (car hits) u)]
         [wildcard (add-unit! by-seg wildcard u)]
         [else (problem! (list unplaced-kind (unit-id u) labels))])]))
  by-seg)

;; ---------------------------------------------------------------------------
;; 度量
;; ---------------------------------------------------------------------------

(struct measured-segment (segment items size entries anchors) #:transparent)
;; entries: (list segment 段内偏移 item 尺寸 origin)

(define (measure-segment target seg units problem!)
  (define name (segment-name seg))
  (define kind (segment-kind seg))
  (define start (segment-start seg))
  (define cursor 0)
  (define out '())
  (define anchors '())
  (define entries '())

  (define (anchor! chain)
    (set! anchors (cons (list 'anchor chain name cursor) anchors)))

  ;; item 类别的合法性只有一张表(forms.rkt 的 item-kind-allowed-in?);
  ;; 这里只把"不合法"翻译成本层的问题名, 不在这里塞策略。
  (define (check-item-kind! it)
    (define ik (item-kind it))
    (unless (item-kind-allowed-in? ik kind)
      (problem!
       (cond
         [(eq? kind 'hole) (list 'hole-materialized-item name cursor it)]
         [(eq? ik 'space)  (list 'reserve-outside-hole name cursor it)]
         [else (list 'segment-item-kind-mismatch name kind cursor it)]))))

  (define (emit-item! it origin)
    (cond
      [(label-form? it) (anchor! (label-chain it))]
      [(comment-form? it) (void)]
      [(align-form? it)
       (define n (align-pad (+ start cursor) (cadr it)))
       ;; 补出来的空间算不算文件字节由段 kind 定:
       ;;   code / data -> (pad n)      要材料化
       ;;   hole        -> (reserve n)  只推进位置, 文件里没有
       ;; 这一句就是本层唯一的 kind 分叉: 它让 hole 段的 items 永远只含
       ;; reserve（label 只进 anchors），encode 不用再判"洞从哪儿开始"。
       (define fact (if (eq? kind 'hole) (list 'reserve n) (list 'pad n)))
       (check-item-kind! fact)
       (set! out (cons (list 'offset cursor fact) out))
       (set! cursor (+ cursor n))]
      [else
       (check-item-kind! it)
       (define size (item-size it))
       (unless (and (exact-integer? size) (>= size 0))
         (error 'layout "cannot size item in segment ~a: ~e" name it))
       (set! out (cons (list 'offset cursor it) out))
       (set! entries (cons (list seg cursor it size origin) entries))
       (set! cursor (+ cursor size))]))

  (for ([u (in-list units)])
    (for ([chain (in-list (unit-labels u))]) (anchor! chain))
    (for ([it (in-list (unit-items u))] [i (in-naturals)])
      (emit-item! it (append (unit-id u) (list i)))))

  (measured-segment seg (reverse out) cursor (reverse entries) (reverse anchors)))

(define (units-by-segment segments code-by-seg data-by-seg)
  (for/hash ([seg (in-list segments)])
    (define name (segment-name seg))
    (values name
            (append (hash-ref code-by-seg name '())
                    (hash-ref data-by-seg name '())))))

;; ---------------------------------------------------------------------------
;; 校验
;; ---------------------------------------------------------------------------

;; The measured layout carries segment starts in its own segment forms.
(define (anchor-positions anchors measured-segments)
  (define start-of
    (for/hash ([m (in-list measured-segments)])
      (values (segment-name (measured-segment-segment m))
              (segment-start (measured-segment-segment m)))))
  (for/hash ([a (in-list anchors)])
    (define chain (cadr a))
    (define seg (caddr a))
    (define off (cadddr a))
    (values chain (+ (hash-ref start-of seg) off))))

(define (check-control-transfer entry positions problem! request!)
  (define seg (car entry))
  (define offset (cadr entry))
  (define item (caddr entry))
  (define size (cadddr entry))
  (define origin (list-ref entry 4))
  (when (control-transfer-form? item)
    (define target (normalize-path (control-transfer-target item)))
    (cond
      [(not target)
       (problem! (list 'undefined-target (segment-name seg) offset item))]
      [else
       (define addr (hash-ref positions target #f))
       (cond
         [(not addr)
          (problem! (list 'undefined-target (segment-name seg) offset item))]
         [else
          (define here (+ (segment-start seg) offset))
          (define disp (- addr (+ here size)))
          (define range (control-transfer-range item))
          (when (and range
                     (not (<= (car range) disp (cdr range))))
            (request! (if (short-control-transfer-form? item)
                          (list 'needs-near origin (segment-name seg) offset item disp)
                          (list 'needs-far origin (segment-name seg) offset item disp))))])])))

(define (item-memory-sites item here size)
  (cond
    [(mem-form? item) (list (list (parse-mem item) here size))]
    [(and (form? item)
          (eq? (car item) 'prefix)
          (= 3 (length item))
          (form? (caddr item)))
     (item-memory-sites (caddr item) (+ here 1) (- size 1))]
    [(form? item)
     (append* (for/list ([op (in-list (cdr item))])
                (item-memory-sites op here size)))]
    [else '()]))

(define (check-memory-range entry positions problem!)
  (define seg (car entry))
  (define offset (cadr entry))
  (define item (caddr entry))
  (define size (cadddr entry))
  (define here (+ (segment-start seg) offset))
  (for ([site (in-list (item-memory-sites item here size))])
    (define m (car site))
    (define m-here (cadr site))
    (define m-size (caddr site))
    (define d (mem-disp m))
    (unless (exact-integer? d)
      (define chains (address-expr-chains d))
      (define missing?
        (for/or ([c (in-list chains)])
          (not (hash-ref positions c #f))))
      (cond
        [missing?
         (problem! (list 'undefined-target (segment-name seg) offset item))]
        [else
         (define value (eval-address d (lambda (c) (hash-ref positions c)) m-here))
         (cond
           [(eq? (mem-base m) 'rip)
            (define rel (- value (+ m-here m-size)))
            (unless (fits-rel32? rel)
              (problem! (list 'rip-out-of-range
                              (segment-name seg) offset item rel)))]
           [else
            (unless (fits-disp32? value)
              (problem! (list 'absolute-out-of-range
                              (segment-name seg) offset item value)))])]))))

(define (check-value-chains entry positions problem!)
  (define seg (car entry))
  (define offset (cadr entry))
  (define item (caddr entry))
  (when (value-form? item)
    (define v (value-payload item))
    (unless (exact-integer? v)
      (for ([c (in-list (address-expr-chains v))])
        (unless (hash-ref positions c #f)
          (problem! (list 'undefined-target (segment-name seg) offset item)))))))

(define (check-segment-overflow measured problem!)
  (for ([m (in-list measured)])
    (define seg (measured-segment-segment m))
    (define capacity (- (segment-end seg) (segment-start seg)))
    (when (> (measured-segment-size m) capacity)
      (problem! (list 'segment-overflow
                      (segment-name seg) (measured-segment-size m) capacity)))))

(define (check-fallthrough code-by-seg flows problem!)
  (for ([seg (in-list (hash-keys code-by-seg))])
    (define units (hash-ref code-by-seg seg))
    (for ([u (in-list units)] [i (in-naturals)])
      (define id (unit-id u))
      (when (eq? (car id) 'code)
        (define bi (cadr id))
        (define ft (flow-fallthrough (list-ref flows bi)))
        (when ft
          (define next (and (< (add1 i) (length units))
                            (unit-id (list-ref units (add1 i)))))
          (define next-bi (and next (eq? (car next) 'code) (cadr next)))
          (unless (eqv? next-bi ft)
            (problem! (list 'broken-fallthrough seg bi ft next-bi))))))))

;; ---------------------------------------------------------------------------
;; 输出
;; ---------------------------------------------------------------------------

(define (segment->sexp m)
  (define seg (measured-segment-segment m))
  (list 'segment
        (list 'name (segment-name seg))
        (list 'kind (segment-kind seg))
        (list 'start (segment-start seg))
        (list 'end (segment-end seg))
        (cons 'items (measured-segment-items m))
        (list 'size (measured-segment-size m))))

(define (build-layout target segments units-by-seg code-by-seg flows problem!)
  (define measured
    (for/list ([seg (in-list segments)])
      (measure-segment target seg
                       (hash-ref units-by-seg (segment-name seg) '())
                       problem!)))
  (define anchors (append* (map measured-segment-anchors measured)))
  (define entries (append* (map measured-segment-entries measured)))
  (define positions (anchor-positions anchors measured))
  (define requests '())
  (define (request! r) (set! requests (cons r requests)))
  (for ([e (in-list entries)])
    (check-control-transfer e positions problem! request!)
    (check-memory-range e positions problem!)
    (check-value-chains e positions problem!))
  (check-segment-overflow measured problem!)
  (when (and code-by-seg flows)
    (check-fallthrough code-by-seg flows problem!))
  (values measured anchors (reverse requests)))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (layout-program target prog data-items spec)
  (unless (program? prog)
    (error 'layout-program "expected analyze/dce program: ~e" prog))
  (define problems '())
  (define (problem! p) (set! problems (cons p problems)))
  (define-values (segments rules wildcard) (parse-spec spec problem!))
  (define code-by-seg (place-code-units (program->units prog) rules wildcard problem!))
  (define data-by-seg
    (place-exact-units (data-items->units (as-items data-items))
                       rules wildcard problem! 'unplaced-data))
  (define units-by-seg (units-by-segment segments code-by-seg data-by-seg))
  (define-values (measured anchors requests)
    (build-layout target segments units-by-seg code-by-seg (program-flows prog) problem!))
  (list (list 'phase 'measured)
        (cons 'segments (for/list ([m (in-list measured)]) (segment->sexp m)))
        (cons 'anchors anchors)
        (cons 'requests requests)
        (cons 'problems (reverse problems))))

(define (layout-flat-items target items spec)
  (define problems '())
  (define (problem! p) (set! problems (cons p problems)))
  (define-values (segments rules wildcard) (parse-spec spec problem!))
  (define units (flat-items->units (as-items items) rules wildcard))
  (define by-seg (place-exact-units units rules wildcard problem! 'unplaced))
  (define units-by-seg (units-by-segment segments (make-hash) by-seg))
  (define-values (measured anchors requests)
    (build-layout target segments units-by-seg #f #f problem!))
  (list (list 'phase 'measured)
        (cons 'segments (for/list ([m (in-list measured)]) (segment->sexp m)))
        (cons 'anchors anchors)
        (cons 'requests requests)
        (cons 'problems (reverse problems))))
