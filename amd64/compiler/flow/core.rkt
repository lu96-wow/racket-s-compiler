#lang racket
;;; amd64/compiler/flow/core.rkt
;;;
;;; 核心汇编流水线。本模块**不 require** 任何可选前端/镜像层。
;;;
;;; 一条流由三样东西组成, 装在一个 `flow` 值里:
;;;   stages   层名 -> stage
;;;   groups   组名 -> 层名列表
;;;   default  默认层列表（`compile` 不指定选择器时用它）
;;;
;;; 核心这条流叫 `core-flow`。其它前端在自己的模块里 (extend-flow core-flow …)
;;; 加自己的层和层组, 然后把 flow 绑进同一组函数里导出。
;;; 于是: 每层只认自己的 s-expression, 引擎不知道也不关心是谁的流。
;;;
;;; 层契约只有 requires/provides 两个字段: 跑之前"在途值"里必须有什么,
;;; 跑完写入什么。可选 = 不写进列表, 顺序 = 列表顺序, 平层 = 两个层
;;; requires/provides 相同（layout 和 relax 就是这样）。

(require (only-in "../expand-data/expand.rkt" expand-data)
         (only-in "../flatten/flatten.rkt" flatten-inputs)
         (only-in "../expand-pseudo/rewrite.rkt" rewrite-program pseudo-leftover?)
         (only-in "../analyze/analyze.rkt" analyze)
         (only-in "../dce/dce.rkt" eliminate-dead)
         (only-in "../layout/layout.rkt" layout-program)
         (only-in "../relax/relax.rkt" relax)
         (only-in "../bind-labels/bind.rkt" bind-labels)
         (only-in "../encode/encode.rkt" encode-layout))

(provide (struct-out stage)
         (struct-out flow)
         make-flow
         extend-flow
         core-flow
         stage-names
         providers-of
         select-stages
         group-names
         run-flow
         run-stage
         compile
         compile-image
         flow-value
         default-flow)

(struct stage (name requires provides run doc) #:transparent)

;; 一条流: 层表 + 层组表 + 默认层列表。
(struct flow (name stages groups default) #:transparent)

(define core-stage-table
  (hash
   'expand-data
   (stage 'expand-data '(rich-data) '(data-items)
          (lambda (_target in) (hash 'data-items (expand-data (hash-ref in 'rich-data))))
          "数据定义: rich 数据 -> 核心 item（宽度/值域/字符串/数组/地址字）")

   'flatten
   (stage 'flatten '(program-items data-items) '(program-items data-items names)
          (lambda (_target in)
            (define-values (outs names)
              (flatten-inputs (list (hash-ref in 'program-items)
                                    (hash-ref in 'data-items))))
            (hash 'program-items (list-ref outs 0)
                  'data-items (list-ref outs 1)
                  'names names))
          "模块展平 + 链式查表（程序和数据共享一张名字表）")

   'expand-pseudo
   (stage 'expand-pseudo '(program-items) '(program-items)
          (lambda (_target in)
            (define items
              (rewrite-program (hash-ref in 'program-items)
                               #:short-transfers? #t))
            (when (pseudo-leftover? items)
              (error 'expand-pseudo "pseudo instruction survived expansion: ~e" items))
            (hash 'program-items items))
          "伪指令 -> 真指令（短分支起步，交 relax 升级）")

   'analyze
   (stage 'analyze '(program-items data-items) '(program)
          (lambda (_target in)
            (hash 'program
                  (analyze (hash-ref in 'program-items) (hash-ref in 'data-items))))
          "控制流分析: item -> program(blocks + flows)；data 只贡献 roots")

   'dce
   (stage 'dce '(program) '(program)
          (lambda (_target in)
            (hash 'program (eliminate-dead (hash-ref in 'program))))
          "死代码消除（三个 pass 跑到不动点）")

   'layout
   (stage 'layout '(program data-items layout-spec) '(measured-layout)
          (lambda (target in)
            (hash 'measured-layout
                  (layout-program target
                                  (hash-ref in 'program)
                                  (hash-ref in 'data-items)
                                  (hash-ref in 'layout-spec))))
          "布局度量: 放置 + 尺寸 + anchors + requests/problems")

   'relax
   (stage 'relax '(program data-items layout-spec) '(measured-layout)
          (lambda (target in)
            (hash 'measured-layout
                  (relax target
                         (hash-ref in 'program)
                         (hash-ref in 'data-items)
                         (hash-ref in 'layout-spec))))
          "分支松弛: short -> near，只增不减")

   'bind-labels
   (stage 'bind-labels '(measured-layout) '(bound-layout)
          (lambda (_target in)
            (hash 'bound-layout
                  (bind-labels (hash-ref in 'measured-layout))))
          "地址绑定: anchors -> symbols + 最终宽度检查")

   'encode
   (stage 'encode '(bound-layout) '(build)
          (lambda (target in)
            (hash 'build (encode-layout target (hash-ref in 'bound-layout))))
          "编码: bound-layout -> (build …)；有 request/problem 就拒绝出产物")))

(define core-stage-groups
  (hash
   'frontend '(expand-data flatten expand-pseudo)
   'ir       '(analyze dce)
   'backend  '(relax bind-labels encode)
   'all      '(expand-data flatten expand-pseudo analyze dce relax bind-labels encode)))

(define default-flow '(expand-data flatten expand-pseudo analyze dce relax bind-labels encode))

(define (make-flow name stages groups [default default-flow])
  ;; 组名不能盖住层名; 组里每一项都必须是已有的层; 默认流也一样。
  (for ([(g members) (in-hash groups)])
    (when (hash-has-key? stages g)
      (error 'flow "stage group ~a conflicts with a stage name" g))
    (unless (and (list? members)
                 (andmap symbol? members)
                 (andmap (lambda (s) (hash-has-key? stages s)) members))
      (error 'flow "bad stage group ~a: ~e" g members)))
  (unless (and (list? default)
               (andmap (lambda (s) (hash-has-key? stages s)) default))
    (error 'flow "bad default flow ~a: ~e" name default))
  (flow name stages groups default))

;; 在自己的流上再挂一层/一个组。名字冲突就报错, 不静默覆盖。
(define (extend-flow base name more-stages [more-groups '()])
  (for ([(k _) (in-hash more-stages)])
    (when (hash-has-key? (flow-stages base) k)
      (error 'flow "stage ~a 已经存在（流 ~a）" k (flow-name base))))
  (make-flow name
             (for/fold ([h (flow-stages base)]) ([(k v) (in-hash more-stages)])
               (hash-set h k v))
             (for/fold ([h (flow-groups base)]) ([(k v) (in-hash more-groups)])
               (hash-set h k v))
             (flow-default base)))

(define core-flow (make-flow 'core core-stage-table core-stage-groups))

;; ---------------------------------------------------------------------------
;; 查询
;; ---------------------------------------------------------------------------

(define (stage-names f)
  (sort (hash-keys (flow-stages f)) symbol<?))

(define (providers-of f value)
  (sort (for/list ([st (in-list (hash-values (flow-stages f)))]
                   #:when (memq value (stage-provides st)))
          (stage-name st))
        symbol<?))

(define (group-names f)
  (sort (hash-keys (flow-groups f)) symbol<?))

(define (select-stages f selector)
  (define (walk x)
    (cond
      [(symbol? x)
       (cond
         [(hash-has-key? (flow-stages f) x) (list x)]
         [(hash-has-key? (flow-groups f) x) (hash-ref (flow-groups f) x)]
         [else
          (error 'select-stages
                 "未知的层或层组 `~a`；已知层: ~a；已知组: ~a"
                 x (stage-names f) (group-names f))])]
      [(list? x) (append* (for/list ([y (in-list x)]) (walk y)))]
      [else
       (error 'select-stages
              "选择器只能是层名/组名或它们的列表: ~e" x)]))
  (walk selector))

;; ---------------------------------------------------------------------------
;; 跑
;; ---------------------------------------------------------------------------

(define (seed-context seeds)
  (define ctx (make-hash))
  (cond
    [(hash? seeds)
     (for ([(k v) (in-hash seeds)]) (hash-set! ctx k v))]
    [(and (list? seeds) (andmap pair? seeds))
     (for ([p (in-list seeds)]) (hash-set! ctx (car p) (cdr p)))]
    [else
     (error 'run-flow
            "seeds 必须是 (名字 . 值) 列表或 context hash: ~e" seeds)])
  ctx)

(define (run-flow f target selector [seeds '()])
  (define names (select-stages f selector))
  (define ctx (seed-context seeds))
  (define timing? (and (getenv "AMD64_FLOW_TIMING") #t))
  (for ([n (in-list names)] [step (in-naturals)])
    (define st (hash-ref (flow-stages f) n))
    (for ([r (in-list (stage-requires st))])
      (unless (hash-has-key? ctx r)
        (error 'run-flow
               "第 ~a 步 `~a` 需要 `~a`，但它前面没有层产出它，seed 里也没有。~a"
               step n r
               (let ([ps (providers-of f r)])
                 (if (null? ps) "" (format "能产出它的是: ~a" ps))))))
    (define in (for/hash ([r (in-list (stage-requires st))])
                 (values r (hash-ref ctx r))))
    (define started (and timing? (current-inexact-milliseconds)))
    (define produced ((stage-run st) target in))
    (when timing?
      (eprintf "~a: ~ams\n" n
               (round (- (current-inexact-milliseconds) started))))
    (for ([(k v) (in-hash produced)]) (hash-set! ctx k v)))
  ctx)

(define (run-stage f target name [seeds '()])
  (unless (and (symbol? name) (hash-has-key? (flow-stages f) name))
    (error 'run-stage
           "~a 不是层名；已知层: ~a；已知组: ~a（层组/片段用 run-flow）"
           name (stage-names f) (group-names f)))
  (define st (hash-ref (flow-stages f) name))
  (define ctx (run-flow f target (list name) seeds))
  (for/hash ([v (in-list (stage-provides st))])
    (values v (hash-ref ctx v))))

(define (flow-value ctx name)
  (hash-ref ctx name
            (lambda ()
              (error 'flow-value "流里没有 `~a`（有的: ~a）" name (hash-keys ctx)))))

(define (compile f target seeds [selector #f])
  (flow-value (run-flow f target (or selector (flow-default f)) seeds) 'build))

(define (compile-image f target seeds [selector #f])
  (flow-value (run-flow f target (or selector (flow-default f)) seeds) 'image))
