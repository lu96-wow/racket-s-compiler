#lang racket
;;; compiler/flow/core.rkt
;;;
;;; Core assembly pipeline only.  This module must not require
;;; loko-compatibility, amd64-elf, or any other optional frontend/image layer.
;;;
;;; Extensions provide a stage table to the generic engine:
;;;   (run-flow target selector seeds
;;;             #:stage-table table #:stage-groups groups)
;;;
;;; The lists below remain the public spelling for the default backend flow.

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
         core-stage-table
         core-stage-groups
         stage-names
         providers-of
         select-stages
         group-names
         run-flow
         run-stage
         compile
         compile-image
         context-value
         default-flow)

(struct stage (name requires provides run doc) #:transparent)

(define core-stage-table
  (hash
   'expand-data
   (stage 'expand-data '(rich-data) '(data-items)
          (lambda (_target in)
            (hash 'data-items (expand-data (hash-ref in 'rich-data))))
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

   'expand-pseudo-near
   (stage 'expand-pseudo-near '(program-items) '(program-items)
          (lambda (_target in)
            (define items
              (rewrite-program (hash-ref in 'program-items)
                               #:short-transfers? #f))
            (when (pseudo-leftover? items)
              (error 'expand-pseudo-near "pseudo instruction survived expansion: ~e" items))
            (hash 'program-items items))
          "伪指令 -> 真指令（全部 near，用于快速验证；布局一次即可）")

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

;; A group name must not shadow a stage name, and every member must exist.
(for ([(g stages) (in-hash core-stage-groups)])
  (when (hash-has-key? core-stage-table g)
    (error 'flow "stage group ~a conflicts with a stage name" g))
  (unless (and (list? stages)
               (andmap symbol? stages)
               (andmap (lambda (s) (hash-has-key? core-stage-table s)) stages))
    (error 'flow "bad stage group ~a: ~e" g stages)))

;; ---------------------------------------------------------------------------
;; generic engine over an explicit stage table
;; ---------------------------------------------------------------------------

(define (stage-names #:stage-table [table core-stage-table])
  (sort (hash-keys table) symbol<?))

(define (providers-of value #:stage-table [table core-stage-table])
  (sort (for/list ([st (in-list (hash-values table))]
                   #:when (memq value (stage-provides st)))
          (stage-name st))
        symbol<?))

(define (group-names #:stage-groups [groups core-stage-groups])
  (sort (hash-keys groups) symbol<?))

(define (select-stages selector
                       #:stage-table [table core-stage-table]
                       #:stage-groups [groups core-stage-groups])
  (define (walk x)
    (cond
      [(symbol? x)
       (cond
         [(hash-has-key? table x) (list x)]
         [(hash-has-key? groups x) (hash-ref groups x)]
         [else
          (error 'select-stages
                 "未知的层或层组 `~a`；已知层: ~a；已知组: ~a"
                 x (stage-names #:stage-table table)
                 (group-names #:stage-groups groups))])]
      [(list? x) (append* (for/list ([y (in-list x)]) (walk y)))]
      [else
       (error 'select-stages
              "选择器只能是层名/组名或它们的列表: ~e" x)]))
  (walk selector))

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

(define (run-flow target selector [seeds '()]
                  #:stage-table [table core-stage-table]
                  #:stage-groups [groups core-stage-groups])
  (define names (select-stages selector
                               #:stage-table table
                               #:stage-groups groups))
  (define ctx (seed-context seeds))
  (define timing? (and (getenv "AMD64_FLOW_TIMING") #t))
  (for ([n (in-list names)] [step (in-naturals)])
    (define st (hash-ref table n))
    (for ([r (in-list (stage-requires st))])
      (unless (hash-has-key? ctx r)
        (error 'run-flow
               "第 ~a 步 `~a` 需要 `~a`，但它前面没有层产出它，seed 里也没有。~a"
               step n r
               (let ([ps (providers-of r #:stage-table table)])
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

(define (run-stage target name [seeds '()]
                   #:stage-table [table core-stage-table]
                   #:stage-groups [groups core-stage-groups])
  (unless (and (symbol? name) (hash-has-key? table name))
    (error 'run-stage
           "~a 不是层名；已知层: ~a；已知组: ~a（层组/片段用 run-flow）"
           name (stage-names #:stage-table table)
           (group-names #:stage-groups groups)))
  (define st (hash-ref table name))
  (define ctx (run-flow target (list name) seeds
                        #:stage-table table
                        #:stage-groups groups))
  (for/hash ([v (in-list (stage-provides st))])
    (values v (hash-ref ctx v))))

(define (context-value ctx name)
  (hash-ref ctx name
            (lambda ()
              (error 'context-value "流里没有 `~a`（有的: ~a）"
                     name (hash-keys ctx)))))

(define (compile target seeds [flow default-flow]
                 #:stage-table [table core-stage-table]
                 #:stage-groups [groups core-stage-groups])
  (context-value (run-flow target flow seeds
                           #:stage-table table
                           #:stage-groups groups)
                 'build))

(define (compile-image target seeds [flow default-flow]
                       #:stage-table [table core-stage-table]
                       #:stage-groups [groups core-stage-groups])
  (context-value (run-flow target flow seeds
                           #:stage-table table
                           #:stage-groups groups)
                 'image))
