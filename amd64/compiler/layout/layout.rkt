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
         (only-in "../item.rkt" make-pad make-reserve align-value)
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

(define (validate-segments segments problem!)
  (define names (map segment-name segments))
  (unless (= (length names) (length (remove-duplicates names)))
    (problem! (make-problem 'segment-name-duplicated names)))
  (for ([s (in-list segments)])
    ;; Empty sections are valid: start may equal end (an unused data section, a
    ;; hole with no addresses yet, ...).  RISC-V is stricter here; amd64 is not.
    (unless (<= (segment-start s) (segment-end s))
      (problem! (make-problem 'segment-bad-range (segment-name s))))
    (unless (zero? (modulo (segment-start s) (segment-align s)))
      (problem! (make-problem 'segment-misaligned
                      (segment-name s) (segment-start s) (segment-align s)))))
  (define n (length segments))
  (for* ([i (in-range n)] [j (in-range n)] #:when (< i j))
    (define a (list-ref segments i))
    (define b (list-ref segments j))
    (when (and (< (segment-start a) (segment-end b))
               (< (segment-start b) (segment-end a)))
      (problem! (make-problem 'segment-overlap (segment-name a) (segment-name b))))))

;; rules: ((链 . 段名) ...); wildcard: 段名或 #f
(define (parse-places spec segments problem!)
  (define names (map segment-name segments))
  (define rules '())
  (define wildcard #f)
  (for ([p (in-list (layout-spec-places spec))])
    (define seg (place-segment p))
    (define chains (place-chains p))
    (cond
      [(not (memq seg names))
       (problem! (make-problem 'unknown-segment seg))]
      [(null? chains)
       (problem! (make-problem 'bad-place p))]
      [else
       (for ([c (in-list chains)])
         (cond
           [(eq? c '*)
            (if wildcard
                (problem! (make-problem 'ambiguous-wildcard wildcard seg))
                (set! wildcard seg))]
           [else
            (define path (normalize-path c))
            (if path
                (set! rules (cons (cons path seg) rules))
                (problem! (make-problem 'bad-place-chain c)))]))]))
  (values (reverse rules) wildcard))

(define (align-up n align)
  (* align (quotient (+ n (sub1 align)) align)))

;; 地址求解: 段声明里的 (start …) 是"解", 缺省就由本层按声明顺序递增求解。
;;   start = 对齐后的游标        (游标从 spec 的 (origin …) 起步, 缺省 0)
;;   end   = start + 容量        ((end …) 给绝对上界, (size …) 给相对上界)
;; 过了这一步, 段的 start/end 一定是整数, 下游不再需要关心地址从哪来。
;; 页边界、权限分组这类约束就以 (align …) 的形式流进来, 分配者不再需要猜。
(define (resolve-segment-starts decls spec)
  (define cursor (or (layout-spec-origin spec) 0))
  (for/list ([d (in-list decls)])
    (define align (segment-decl-align d))
    (define start (or (segment-decl-start d) (align-up cursor align)))
    (define end (or (segment-decl-end d) (+ start (segment-decl-size d))))
    (set! cursor end)
    (make-segment (segment-decl-name d) (segment-decl-kind d) start end align)))

(define (parse-spec spec problem!)
  (define segments
    (resolve-segment-starts (map parse-segment-decl (layout-spec-segments spec)) spec))
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

;; 规则表: (链 . 段名) 的列表 -> 链 -> (段名 …)。
;; 原来这里是"每个 unit 的每个 label 扫一遍全部规则"(labels × rules), 在大镜像
;; 上就是二次的: pc-repl 的 dump 有 22 万条规则、十万级 unit。
(define (rules->table rules)
  (for/fold ([h (make-hash)]) ([r (in-list rules)])
    (hash-update! h (car r) (lambda (xs) (cons (cdr r) xs)) '())
    h))

(define (matching-segment-names rule-table labels)
  (remove-duplicates
   (append* (for/list ([chain (in-list labels)])
              (hash-ref rule-table chain '())))))

;; 先 cons 后 reverse: 原来用 (append xs (list u)), 每个段是 O(单位数²)。
(define (add-unit! table seg u)
  (hash-update! table seg (lambda (xs) (cons u xs)) '()))

(define (place-code-units units rules wildcard problem!)
  (define by-seg (make-hash))
  (define rule-table (rules->table rules))
  (define current #f)
  (for ([u (in-list units)])
    (define labels (unit-labels u))
    (define hits (matching-segment-names rule-table labels))
    (cond
      [(> (length hits) 1)
       (problem! (make-problem 'ambiguous-placement labels hits))]
      [(= 1 (length hits))
       (set! current (car hits))
       (add-unit! by-seg current u)]
      [current (add-unit! by-seg current u)]
      [wildcard
       (set! current wildcard)
       (add-unit! by-seg current u)]
      [else
       (problem! (make-problem 'unplaced-block (unit-id u) labels))]))
  (ordered-table by-seg))

(define (place-exact-units units rules wildcard problem! unplaced-kind)
  (define by-seg (make-hash))
  (define rule-table (rules->table rules))
  (for ([u (in-list units)])
    (define labels (unit-labels u))
    (cond
      [(null? labels)
       (problem! (make-problem 'unlabeled-run (unit-id u) (unit-items u)))]
      [else
       (define hits (matching-segment-names rule-table labels))
       (cond
         [(> (length hits) 1)
          (problem! (make-problem 'ambiguous-placement labels hits))]
         [(= 1 (length hits)) (add-unit! by-seg (car hits) u)]
         [wildcard (add-unit! by-seg wildcard u)]
         [else (problem! (make-problem unplaced-kind (unit-id u) labels))])]))
  (ordered-table by-seg))

;; ---------------------------------------------------------------------------
;; 度量
;; ---------------------------------------------------------------------------

(struct measured-segment (segment items size entries anchors) #:transparent)
(struct entry (segment offset item size origin) #:transparent)
(struct memory-site (mem here size) #:transparent)

(define (measure-segment target seg units problem!)
  (define name (segment-name seg))
  (define kind (segment-kind seg))
  (define start (segment-start seg))
  (define cursor 0)
  (define out '())
  (define anchors '())
  (define entries '())

  (define (anchor! chain)
    (set! anchors (cons (make-anchor chain name cursor) anchors)))

  ;; item 类别的合法性只有一张表(forms.rkt 的 item-kind-allowed-in?);
  ;; 这里只把"不合法"翻译成本层的问题名, 不在这里塞策略。
  (define (check-item-kind! it)
    (define ik (item-kind it))
    (unless (item-kind-allowed-in? ik kind)
      (problem!
       (cond
         [(eq? kind 'hole) (make-problem 'hole-materialized-item name cursor it)]
         [(eq? ik 'space)  (make-problem 'reserve-outside-hole name cursor it)]
         [else (make-problem 'segment-item-kind-mismatch name kind cursor it)]))))

  (define (emit-item! it origin)
    (cond
      [(label-form? it) (anchor! (label-chain it))]
      [(comment-form? it) (void)]
      [(align-form? it)
       (define n (align-pad (+ start cursor) (align-value it)))
       ;; 补出来的空间算不算文件字节由段 kind 定:
       ;;   code / data -> (pad n)      要材料化
       ;;   hole        -> (reserve n)  只推进位置, 文件里没有
       ;; 这一句就是本层唯一的 kind 分叉: 它让 hole 段的 items 永远只含
       ;; reserve（label 只进 anchors），encode 不用再判"洞从哪儿开始"。
       (define fact (if (eq? kind 'hole) (make-reserve n) (make-pad n)))
       (check-item-kind! fact)
       (set! out (cons (make-offset cursor fact) out))
       (set! cursor (+ cursor n))]
      [else
       (check-item-kind! it)
       (define size (item-size target it))
       (unless (and (exact-integer? size) (>= size 0))
         (error 'layout "cannot size item in segment ~a: ~e" name it))
       (set! out (cons (make-offset cursor it) out))
       (set! entries (cons (entry seg cursor it size origin) entries))
       (set! cursor (+ cursor size))]))

  (for ([u (in-list units)])
    (for ([chain (in-list (unit-labels u))]) (anchor! chain))
    (for ([it (in-list (unit-items u))] [i (in-naturals)])
      (emit-item! it (append (unit-id u) (list i)))))

  (measured-segment seg (reverse out) cursor (reverse entries) (reverse anchors)))

;; add-unit! 是 cons 累积(避免二次 append), place-* 返回前在这里反一次。
(define (ordered-table table)
  (for/hash ([(k v) (in-hash table)]) (values k (reverse v))))

(define (units-by-segment segments code-by-seg data-by-seg)
  (define (units-of table name) (hash-ref table name '()))
  (for/hash ([seg (in-list segments)])
    (define name (segment-name seg))
    (values name
            (append (units-of code-by-seg name)
                    (units-of data-by-seg name)))))

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
    (values (anchor-chain a)
            (+ (hash-ref start-of (anchor-segment a))
               (anchor-position a)))))

(define (check-control-transfer entry positions problem! request!)
  (define seg (entry-segment entry))
  (define offset (entry-offset entry))
  (define item (entry-item entry))
  (define size (entry-size entry))
  (define origin (entry-origin entry))
  (when (control-transfer-form? item)
    (define target (normalize-path (control-transfer-target item)))
    (cond
      [(not target)
       (problem! (make-problem 'undefined-target (segment-name seg) offset item))]
      [else
       (define addr (hash-ref positions target #f))
       (cond
         [(not addr)
          (problem! (make-problem 'undefined-target (segment-name seg) offset item))]
         [else
          (define here (+ (segment-start seg) offset))
          (define disp (- addr (+ here size)))
          (define range (control-transfer-range item))
          (when (and range
                     (not (<= (car range) disp (cdr range))))
            (request! (if (short-control-transfer-form? item)
                          (make-request 'needs-near origin (segment-name seg) offset item disp)
                          (make-request 'needs-far origin (segment-name seg) offset item disp))))])])))

(define (item-memory-sites item here size)
  (cond
    [(mem-form? item) (list (memory-site (parse-mem item) here size))]
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
  (define seg (entry-segment entry))
  (define offset (entry-offset entry))
  (define item (entry-item entry))
  (define size (entry-size entry))
  (define here (+ (segment-start seg) offset))
  (for ([site (in-list (item-memory-sites item here size))])
    (define m (memory-site-mem site))
    (define m-here (memory-site-here site))
    (define m-size (memory-site-size site))
    (define d (mem-disp m))
    (unless (exact-integer? d)
      (define chains (address-expr-chains d))
      (define missing?
        (for/or ([c (in-list chains)])
          (not (hash-ref positions c #f))))
      (cond
        [missing?
         (problem! (make-problem 'undefined-target (segment-name seg) offset item))]
        [else
         (define value (eval-address d (lambda (c) (hash-ref positions c)) m-here))
         (cond
           [(eq? (mem-base m) 'rip)
            (define rel (- value (+ m-here m-size)))
            (unless (fits-rel32? rel)
              (problem! (make-problem 'rip-out-of-range
                              (segment-name seg) offset item rel)))]
           [else
            (unless (fits-disp32? value)
              (problem! (make-problem 'absolute-out-of-range
                              (segment-name seg) offset item value)))])]))))

(define (check-value-chains entry positions problem!)
  (define seg (entry-segment entry))
  (define offset (entry-offset entry))
  (define item (entry-item entry))
  (when (value-form? item)
    (define v (value-payload item))
    (unless (exact-integer? v)
      (for ([c (in-list (address-expr-chains v))])
        (unless (hash-ref positions c #f)
          (problem! (make-problem 'undefined-target (segment-name seg) offset item)))))))

(define (check-segment-overflow measured problem!)
  (for ([m (in-list measured)])
    (define seg (measured-segment-segment m))
    (define capacity (- (segment-end seg) (segment-start seg)))
    (when (> (measured-segment-size m) capacity)
      (problem! (make-problem 'segment-overflow
                      (segment-name seg) (measured-segment-size m) capacity)))))

;; 逐 unit 检查"顺序落下"是否与 CFG 的 fallthrough 一致。
;; 这里原来对每个 unit 都做 (list-ref flows bi) / (list-ref units (add1 i)) /
;; (length units) —— 三个 O(段长) 的操作放在循环里, 于是整个检查是二次的
;; (pc-repl 的 text 段有十万级 unit)。改成先转 vector。
(define (check-fallthrough code-by-seg flows problem!)
  (define flows-v (list->vector flows))
  (for ([seg (in-list (hash-keys code-by-seg))])
    (define units (list->vector (hash-ref code-by-seg seg)))
    (define n (vector-length units))
    (for ([u (in-vector units)] [i (in-naturals)])
      (define id (unit-id u))
      (when (eq? (car id) 'code)
        (define bi (cadr id))
        (define ft (flow-fallthrough (vector-ref flows-v bi)))
        (when ft
          (define next (and (< (add1 i) n) (unit-id (vector-ref units (add1 i)))))
          (define next-bi (and next (eq? (car next) 'code) (cadr next)))
          (unless (eqv? next-bi ft)
            (problem! (make-problem 'broken-fallthrough seg bi ft next-bi))))))))

;; ---------------------------------------------------------------------------
;; 输出
;; ---------------------------------------------------------------------------

(define (segment->sexp m)
  (define seg (measured-segment-segment m))
  (make-layout-segment (segment-name seg)
                       (segment-kind seg)
                       (segment-start seg)
                       (segment-end seg)
                       (measured-segment-items m)
                       (measured-segment-size m)))

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
  (make-measured-layout
   (for/list ([m (in-list measured)]) (segment->sexp m))
   anchors requests (reverse problems)))

(define (layout-flat-items target items spec)
  (define problems '())
  (define (problem! p) (set! problems (cons p problems)))
  (define-values (segments rules wildcard) (parse-spec spec problem!))
  (define units (flat-items->units (as-items items) rules wildcard))
  (define by-seg (place-exact-units units rules wildcard problem! 'unplaced))
  (define units-by-seg (units-by-segment segments (make-hash) by-seg))
  (define-values (measured anchors requests)
    (build-layout target segments units-by-seg #f #f problem!))
  (make-measured-layout
   (for/list ([m (in-list measured)]) (segment->sexp m))
   anchors requests (reverse problems)))
