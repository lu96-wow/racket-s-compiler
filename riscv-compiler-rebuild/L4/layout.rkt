#lang racket
;;; L4/layout.rkt
;;;
;;; 布局计算: (program, data, layout) -> (layout ...)
;;; 只算, 不选择: 不升级远形式、不造 label、不填 scratch、不重排。
;;;
;;; 三个输入都是普通 list:
;;;
;;;   program : (label ...) (insn ...) ...
;;;   data    : (label ...) (bytes ...) (align n) ...
;;;   layout  : ((segments (segment 名 kind start end align) ...)
;;;              (place 段名 链 ...) ...)
;;;
;;; 代码里**没有 section**: 段归属全部写在 layout 的 place 行里。
;;;
;;; 放置单位 = 游程(run) = 从一条 label 到下一条 label 之间的 item。
;;;   - 游程的身份 = 它的 label 链(可以有多条, 同一位置多个名字)
;;;   - place 行只做**精确匹配**: 链必须与游程的某条 label 链 equal?
;;;   - 不做前缀匹配、不做默认落位: 没匹配上就是 problem
;;;   - 段内顺序 = 源顺序(程序先, 数据后; 各自按出现顺序)
;;;
;;; 段: (segment 名 kind start end align), [start, end) 是物理区间。
;;;
;;; 校验全部走 problems, 不抛异常(除了输入语法错误)。

(require "forms.rkt")

(provide layout-program
         items-of
         layout-problems
         (struct-out run))

;; ---------------------------------------------------------------------------
;; 输入整形
;; ---------------------------------------------------------------------------

(define (items-of input)
  (define body
    (cond
      [(and (form? input) (eq? (car input) 'quote) (= 2 (length input)) (list? (cadr input)))
       (cadr input)]
      [(list? input) input]
      [else (list input)]))
  (define items
    (cond
      [(null? body) '()]
      [(pair? (car body)) body]
      [else (list body)]))
  (if (and (= 1 (length items)) (form? (car items)) (eq? (caar items) 'begin))
      (cdar items)
      items))

(define (clauses input key)
  (for/list ([x (in-list (items-of input))]
             #:when (and (form? x) (eq? (car x) key)))
    x))

(define (clause input key)
  (findf (lambda (x) (and (form? x) (eq? (car x) key))) (items-of input)))

;; ---------------------------------------------------------------------------
;; 段表
;; ---------------------------------------------------------------------------

(struct segment (name kind start end align) #:transparent)

(define (parse-segments input)
  (append*
   (for/list ([cl (in-list (clauses input 'segments))])
     (for/list ([s (in-list (cdr cl))])
       (define ok?
         (and (segment-form? s)
              (= 6 (length s))
              (symbol? (cadr s))
              (segment-kind? (caddr s))
              (exact-nonnegative-integer? (cadddr s))
              (exact-nonnegative-integer? (list-ref s 4))
              (exact-positive-integer? (list-ref s 5))))
       (unless ok? (error 'layout "bad segment: ~e" s))
       (segment (cadr s) (caddr s) (cadddr s) (list-ref s 4) (list-ref s 5))))))

;; place 行: (place 段名 链 ...)
(define (parse-places input)
  (for/list ([cl (in-list (clauses input 'place))])
    (unless (and (>= (length cl) 3) (symbol? (cadr cl)))
      (error 'layout "bad place: ~e" cl))
    (define chains (for/list ([c (in-list (cddr cl))])
                     (or (normalize-path c) (error 'layout "bad chain in place: ~e" c))))
    (cons (cadr cl) chains)))

;; ---------------------------------------------------------------------------
;; 段表自检
;; ---------------------------------------------------------------------------

(define (validate-segments segs problem!)
  (define names (map segment-name segs))
  (unless (= (length names) (length (remove-duplicates names)))
    (problem! `(segment-name-duplicated ,names)))
  (for ([s (in-list segs)])
    (unless (< (segment-start s) (segment-end s))
      (problem! `(segment-bad-range ,(segment-name s))))
    (unless (zero? (modulo (segment-start s) (segment-align s)))
      (problem! `(segment-misaligned ,(segment-name s) ,(segment-start s) ,(segment-align s)))))
  (define n (length segs))
  (for* ([i (in-range n)] [j (in-range n)] #:when (< i j))
    (define a (list-ref segs i))
    (define b (list-ref segs j))
    (when (and (< (segment-start a) (segment-end b))
               (< (segment-start b) (segment-end a)))
      (problem! `(segment-overlap ,(segment-name a) ,(segment-name b))))))

;; ---------------------------------------------------------------------------
;; 游程: 从一条 label 到下一条 label 之间的 item
;; ---------------------------------------------------------------------------

(struct run (labels items) #:transparent)

(define (split-runs items)
  (define runs '())
  (define cur-labels '())
  (define cur-items '())
  (define (flush!)
    (when (or (pair? cur-labels) (pair? cur-items))
      (set! runs (cons (run (reverse cur-labels) (reverse cur-items)) runs))
      (set! cur-labels '())
      (set! cur-items '())))
  (for ([it (in-list items)])
    (cond
      [(label-form? it)
       (when (pair? cur-items) (flush!))          ; 上一条游程到此为止
       (set! cur-labels (cons (cdr it) cur-labels))]
      [else (set! cur-items (cons it cur-items))]))
  (flush!)
  (reverse runs))

(define (run->items r)
  (append (for/list ([chain (in-list (run-labels r))]) (cons 'label chain))
          (run-items r)))

;; ---------------------------------------------------------------------------
;; 放置: 每个游程按"精确匹配的 label 链"落到一个段
;; ---------------------------------------------------------------------------

(define (place segs places program data problem!)
  (define by-name (for/hash ([s (in-list segs)]) (values (segment-name s) s)))
  ;; place 行指向不存在的段: 报一次, 该行不生效(相关游程会变成 unplaced)
  (for ([p (in-list places)])
    (unless (hash-ref by-name (car p) #f)
      (problem! `(unknown-segment ,(car p)))))
  (define rules                                ; (链 . 段名)
    (append* (for/list ([p (in-list places)]
                        #:when (hash-ref by-name (car p) #f))
               (for/list ([c (in-list (cdr p))]) (cons c (car p))))))
  (define placed (make-hash))                  ; 段名 -> item 列表(正序)

  (define (add! seg-name items)
    (hash-update! placed seg-name (lambda (l) (append l items)) '()))

  (for ([src (in-list (list program data))])
    (for ([r (in-list (split-runs src))])
      (define labels (run-labels r))
      (cond
        [(null? labels)
         (problem! `(unlabeled-run ,(run-items r)))]
        [else
         (define hits
           (remove-duplicates
            (for*/list ([chain (in-list labels)]
                        [rule (in-list rules)]
                        #:when (equal? chain (car rule)))
              (cdr rule))))
         (cond
           [(null? hits)  (problem! `(unplaced ,(car labels)))]
           [(> (length hits) 1) (problem! `(ambiguous-placement ,(car labels) ,@hits))]
           [else (add! (car hits) (run->items r))])])))

  ;; 段输出顺序 = 段表声明顺序
  (for ([s (in-list segs)])
    (unless (hash-has-key? placed (segment-name s))
      (hash-set! placed (segment-name s) '())))

  placed)

;; ---------------------------------------------------------------------------
;; 度量: 段内单游标, align 补齐, 逐条累加
;; ---------------------------------------------------------------------------

(struct measured (segment items size) #:transparent)
;; items : (listof (list '@ 偏移 item))

(define (measure segs placed problem!)
  (for/list ([seg (in-list segs)])
    (define items (hash-ref placed (segment-name seg) '()))
    (define capacity (- (segment-end seg) (segment-start seg)))
    (define seg-kind (segment-kind seg))
    (define cursor 0)
    (define out '())

    (for ([it (in-list items)])
      (define kind (item-kind it))
      (cond
        [(and (eq? kind 'data) (eq? seg-kind 'code))
         (problem! `(code-data-mixed ,(segment-name seg) ,cursor ,it))]
        [(and (eq? kind 'code) (not (eq? seg-kind 'code)))
         (problem! `(data-code-mixed ,(segment-name seg) ,cursor ,it))])

      (cond
        [(label-form? it)
         (set! out (cons (list '@ cursor it) out))]
        [(align-form? it)
         (define n (cadr it))
         (when (and (eq? seg-kind 'code) (not (zero? (modulo n 4))))
           (problem! `(code-align-not-4 ,(segment-name seg) ,cursor ,n)))
         (define pad (modulo (- n (modulo cursor n)) n))
         (set! out (cons (list '@ cursor it) out))
         (set! cursor (+ cursor pad))]
        [else
         (define sz (item-size it))
         (set! out (cons (list '@ cursor it) out))
         (set! cursor (+ cursor sz))]))

    (when (and (>= capacity 0) (> cursor capacity))
      (problem! `(segment-overflow ,(segment-name seg) ,cursor ,capacity)))

    (measured seg (reverse out) cursor)))

;; ---------------------------------------------------------------------------
;; 符号表: 链 -> (段名 段内偏移 绝对地址)
;; ---------------------------------------------------------------------------

(define (collect-symbols measured-segs)
  (for*/list ([m (in-list measured-segs)]
              [entry (in-list (measured-items m))]
              #:when (label-form? (caddr entry)))
    (define off (cadr entry))
    (define path (cdr (caddr entry)))
    (define seg (measured-segment m))
    (list path (segment-name seg) off (+ (segment-start seg) off))))

(define (symbol-row symbols path)
  (and path (assoc path symbols)))

;; ---------------------------------------------------------------------------
;; 校验: 目标存在 / 距离够 / scratch 空槽
;; ---------------------------------------------------------------------------

(define (verify measured-segs symbols problem!)
  (for ([m (in-list measured-segs)])
    (define seg (measured-segment m))
    (for ([entry (in-list (measured-items m))])
      (define off (cadr entry))
      (define it (caddr entry))
      (define here (+ (segment-start seg) off))

      (when (control-form? it)
        (define target (normalize-path (control-target it)))
        (define row (symbol-row symbols target))
        (cond
          [(not row)
           (problem! `(undefined-target ,(segment-name seg) ,off ,it))]
          [else
           (define d (- (cadddr row) here))
           (define range (form-range it))
           (when (and range (> (abs d) range))
             (problem! `(needs-far ,(segment-name seg) ,off ,it ,d)))]))

      (when (scratch-hole? it)
        (problem! `(scratch-hole ,(segment-name seg) ,off ,it))))))

;; ---------------------------------------------------------------------------
;; 输出
;; ---------------------------------------------------------------------------

(define (layout->sexp measured-segs symbols problems)
  (append
   (list 'layout)
   (for/list ([m (in-list measured-segs)])
     (define seg (measured-segment m))
     (list 'segment
           (list 'name (segment-name seg))
           (list 'kind (segment-kind seg))
           (list 'start (segment-start seg))
           (list 'end (segment-end seg))
           (list 'align (segment-align seg))
           (cons 'items (measured-items m))
           (list 'size (measured-size m))))
   (list (cons 'symbols symbols)
         (cons 'problems problems))))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (layout-program program data layout-input)
  (define segs (parse-segments layout-input))
  (define places (parse-places layout-input))
  (define problems '())
  (define (problem! p) (set! problems (cons p problems)))

  (validate-segments segs problem!)
  (define placed (place segs places (items-of program) (items-of data) problem!))
  (define measured-segs (measure segs placed problem!))
  (define symbols (collect-symbols measured-segs))
  (verify measured-segs symbols problem!)

  (layout->sexp measured-segs symbols (reverse problems)))

;; 只看 problems 的便捷函数(测试/上层用)
(define (layout-problems layout)
  (define hit (assoc 'problems (cdr layout)))
  (and hit (cdr hit)))
