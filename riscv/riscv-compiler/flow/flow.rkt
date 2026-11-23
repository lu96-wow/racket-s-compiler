#lang racket
;;; flow/flow.rkt
;;;
;;; 构建流: 用一张 stage 表 + 一个名字列表把各层串起来。
;;;
;;;   (run-flow target
;;;             (list 'expand-struct 'expand-data 'flatten 'lower-code 'validate
;;;                   'emit-unit 'layout 'check 'bind-labels 'encode 'emit-program)
;;;             '((rich-data . …) (program-items . …) (layout-spec . …)))
;;;
;;;   输入是 canonical native；没有可选别名层。
;;;
;;; 每个 stage 声明两件事:
;;;   requires : 跑之前"在途值"里必须有哪些名字
;;;   provides : 跑完写入哪些名字（可以多个 = 多向传递）
;;;
;;; 于是:
;;;   * 可选   = 不写进列表
;;;   * 顺序   = 列表顺序
;;;   * 平层   = 两个 stage 的 provides 相同（例如 layout 与 check 都产 measured-layout），
;;;              写哪个、写几次都由列表决定
;;;   * 依赖   = 运行到某步时按 requires 检查，缺了就报错并给出"谁能提供"
;;;   * target = run-flow 的显式参数，stage run 接收 (target in)
;;;
;;; stage 名字是契约；目录名现在也叫这个，但**流只认名字**，不认目录结构。

(require (only-in "../struct/struct.rkt" expand-struct-inputs layout-extern-struct-decls)
         (only-in "../program.rkt" make-program)
         (only-in "../unit.rkt" make-unit parse-units unit-target unit->struct-decls unit->label-provides unit->struct-provides)
         (only-in "../expand-data/expand.rkt" expand-data)
         (only-in "../flatten/flatten.rkt" flatten-inputs)
         (only-in "../externs.rkt" extern-names extern-rows)
         (only-in "../target.rkt" target-xlen)
         (only-in "../frontend/blockify.rkt" blockify)
         (only-in "../code/validate.rkt" validate-code)
         (only-in "../layout/layout.rkt" layout-program)
         (only-in "../check/check.rkt" check-layout)
         (only-in "../bind-labels/bind.rkt" bind-labels)
         (only-in "../encode/encode.rkt" encode-layout))

(provide (struct-out stage)
         stage-table
         stage-names
         providers-of
         stage-groups
         group-names
         select-stages
         run-flow
         run-stage
         compile
         flow-value
         default-flow)

;; ---------------------------------------------------------------------------
;; 在途值（名字就是契约）
;;
;;   rich-data      人写的 rich 数据（expand-struct / expand-data 的输入）
;;   structs        结构体定义 + 布局信息（expand-struct 的输出）
;;   extern-structs 上一份 build 的 structs 元数据（跨编译单元的输入）
;;   extern-units   上一份 build 的 unit（布局前接口，跨编译单元 require/provide）
;;   struct-provides struct 的 provide 表（模块 -> 外部名/绝对名）
;;   unit            布局前接口（名字 / 可见性 / 类型 / struct 声明，无地址）
;;   extern-struct-provides 上一份 build 的 struct-provides（跨单元 require 用）
;;   label-provides label 的 provide 表（模块 -> 外部名/绝对名）
;;   extern-label-provides 上一份 build 的 label-provides（跨单元 require 用）
;;   data-items     核心数据 item（label / bytes / fill / value / align / pad）
;;   program-items  扁平的程序 item（可以是 (module …) 嵌套）
;;   names          flatten 建的名字表（链 -> 位置）
;;   exports        flatten 记下的导出集合（绝对链列表，或 'all）
;;   code           前端产出的 (code (blocks ...) (falls ...))
;;   measured-layout 度量/检查产物（segments + anchors + problems）
;;   bound-layout    绑定产物（segments + anchors + symbols + problems）
;;   build           最终产物 (build (link …) (provides …) (structs …) (segment …) …)
;;
;;   外部输入（seed）：code / rich-data / program-items / data-items / layout-spec
;; ---------------------------------------------------------------------------

(struct stage (name requires provides run doc) #:transparent)

;; requires 里的一项: 名字, 或 (optional 名字)。
;;   (optional x) = 在途值里有 x 就作为输入传进去, 没有也不报错。
;;   层的 run 必须能处理"缺这个输入"的情况(给缺省)。
(define (optional-requirement? r) (and (pair? r) (eq? (car r) 'optional)))
(define (requirement-name r) (if (optional-requirement? r) (cadr r) r))

(define stage-table
  (hash
   'load-units
   (stage 'load-units
          '((optional extern-units)
            (optional extern-structs)
            (optional extern-struct-provides)
            (optional extern-label-provides))
          '(extern-structs extern-struct-provides extern-label-provides)
          (lambda (target in)
            (define units (parse-units (hash-ref in 'extern-units '())))
            (for ([u (in-list units)])
              (unless (eq? (unit-target u) (target-xlen target))
                (error 'load-units "unit target ~a 和当前 target ~a 不一致"
                       (unit-target u) (target-xlen target))))
            (hash 'extern-structs
                  (append (hash-ref in 'extern-structs '())
                          (layout-extern-struct-decls target (unit->struct-decls units)))
                  'extern-struct-provides
                  (append (hash-ref in 'extern-struct-provides '())
                          (unit->struct-provides units))
                  'extern-label-provides
                  (append (hash-ref in 'extern-label-provides '())
                          (unit->label-provides units))))
          "加载 extern-units：struct 声明按当前 target 重新布局；provide 表转成现有输入")

   'expand-struct
   (stage 'expand-struct
          '(program-items rich-data
                          (optional extern-structs)
                          (optional extern-struct-provides))
          '(program-items rich-data structs struct-provides)
          (lambda (target in)
            (define-values (program rich structs struct-provides)
              (expand-struct-inputs target
                                    (hash-ref in 'program-items)
                                    (hash-ref in 'rich-data)
                                    (hash-ref in 'extern-structs '())
                                    (hash-ref in 'extern-struct-provides '())))
            (hash 'program-items program
                  'rich-data rich
                  'structs structs
                  'struct-provides struct-provides))
          "结构体: 布局 + 静态数据 + 字段访问展开（前端层，不依赖 layout）")

   'expand-data
   (stage 'expand-data '(rich-data) '(data-items)
          (lambda (_target in) (hash 'data-items (expand-data (hash-ref in 'rich-data))))
          "数据定义: rich 数据 -> 核心 item（宽度/值域/字符串/数组/地址字）")

   'flatten
   (stage 'flatten
          '(program-items data-items
                          (optional externs)
                          (optional struct-provides)
                          (optional extern-label-provides))
          '(program-items data-items names exports label-provides module-requires)
          (lambda (_target in)
            (define-values (outs names exports label-provides module-requires)
              (flatten-inputs (list (hash-ref in 'program-items)
                                    (hash-ref in 'data-items))
                              #:externs (let ([e (hash-ref in 'externs '())])
                                          (if (null? e) '() (extern-names e)))
                              #:extern-provides (hash-ref in 'extern-label-provides '())
                              #:struct-provides (hash-ref in 'struct-provides '())))
            (hash 'program-items (list-ref outs 0)
                  'data-items (list-ref outs 1)
                  'names names
                  'exports exports
                  'label-provides label-provides
                  'module-requires module-requires))
          "模块展平 + 链式查表（程序和数据共享一张名字表）；顺带记下导出集合")

   'lower-code
   (stage 'lower-code '((optional program-items) (optional code)) '(code)
          (lambda (_target in)
            (hash 'code
                  (or (hash-ref in 'code #f)
                      (and (hash-ref in 'program-items #f)
                           (blockify (hash-ref in 'program-items)))
                      (error 'flow "lower-code 需要 code 或 program-items"))))
          "前端结构: 扁平 item -> code(blocks + falls)；不建 succ/root，不做 DCE")

   'validate
   (stage 'validate '(code) '(code)
          (lambda (_target in)
            (hash 'code (validate-code (hash-ref in 'code))))
          "校验 code 的显式控制转移 arity/形状；不改代码")

   'emit-unit
   (stage 'emit-unit
          '(code data-items
                 (optional structs)
                    (optional label-provides)
                    (optional struct-provides)
                    (optional module-requires))
          '(unit)
          (lambda (target in)
            (hash 'unit
                  (make-unit target
                             (hash-ref in 'code)
                             (hash-ref in 'data-items)
                             (hash-ref in 'structs '())
                             (hash-ref in 'label-provides '())
                             (hash-ref in 'struct-provides '())
                             (hash-ref in 'module-requires '()))))
          "布局前接口: 名字 / 模块可见性 / label kind / struct 声明；不含地址/offset")

   'layout
   (stage 'layout '(code data-items layout-spec (optional externs))
          '(measured-layout)
          (lambda (target in)
            (hash 'measured-layout
                  (layout-program target
                                  (hash-ref in 'code)
                                  (hash-ref in 'data-items)
                                  (hash-ref in 'layout-spec)
                                  (extern-rows (hash-ref in 'externs '())))))
          "布局度量: 放置 + 尺寸 + anchors/problems（无绝对地址，不选形式）")

   'check
   (stage 'check '(measured-layout) '(measured-layout)
          (lambda (target in)
            (hash 'measured-layout
                  (check-layout target (hash-ref in 'measured-layout))))
          "显式形式检查: 目标/范围/scratch/近 la；只报 problems，不改尺寸")

   'bind-labels
   (stage 'bind-labels '(measured-layout (optional exports)) '(bound-layout)
          (lambda (_target in)
            ;; exports 可选: 没跑 flatten 时按“全导出”算(手搓 measured-layout 的场景)
            (hash 'bound-layout
                  (bind-labels (hash-ref in 'measured-layout)
                               (hash-ref in 'exports 'all))))
          "地址绑定: anchors -> symbols（偏移 -> 绝对地址）+ link/provides + 宽度/容量检查")

   'encode
   (stage 'encode
          '(bound-layout
            (optional structs)
            (optional label-provides)
            (optional struct-provides)
            (optional unit))
          '(build)
          (lambda (target in)
            (hash 'build
                  (encode-layout target
                                 (hash-ref in 'bound-layout)
                                 #:structs (hash-ref in 'structs '())
                                 #:label-provides (hash-ref in 'label-provides '())
                                 #:struct-provides (hash-ref in 'struct-provides '())
                                 #:unit (hash-ref in 'unit '()))))
          "编码: bound-layout -> (build …)；有 problem 就拒绝出产物")

   'emit-program
   (stage 'emit-program
          '(build (optional unit) code data-items
                  (optional extern-units)
                  (optional externs))
          '(program)
          (lambda (_target in)
            (hash 'program
                  (make-program (hash-ref in 'unit '())
                                (hash-ref in 'code)
                                (hash-ref in 'data-items)
                                (hash-ref in 'build)
                                (hash-ref in 'extern-units '())
                                (hash-ref in 'externs '()))))
          "最终 s-exp: (program (internal ...) (external ...))")))

;; ---------------------------------------------------------------------------
;; 查询
;; ---------------------------------------------------------------------------

(define (stage-names) (sort (hash-keys stage-table) symbol<?))

(define (providers-of value)
  (sort (for/list ([st (in-list (hash-values stage-table))]
                   #:when (memq value (stage-provides st)))
          (stage-name st))
        symbol<?))

;; 默认流: canonical native。
(define default-flow
  '(load-units expand-struct expand-data flatten lower-code validate emit-unit layout check bind-labels encode emit-program))

;; ---------------------------------------------------------------------------
;; 选择器: 层名 / 层组 / 任意片段
;; ---------------------------------------------------------------------------

;; 层组 = 常用片段的预定义列表。组名不能和层名重名。
;; 组里只写层名; 想临时组合就直接写列表, 不必先定义组。
(define stage-groups
  (hash
   'frontend '(load-units expand-struct expand-data flatten lower-code)
   'backend  '(validate emit-unit layout check bind-labels encode emit-program)
   'all      default-flow))

(define (group-names)
  (sort (hash-keys stage-groups) symbol<?))

;; 启动时自检: 组名不占层名, 组里只有已知层。
(for ([(g stages) (in-hash stage-groups)])
  (when (hash-has-key? stage-table g)
    (error 'flow "stage group ~a conflicts with a stage name" g))
  (unless (and (list? stages)
               (andmap symbol? stages)
               (andmap (lambda (s) (hash-has-key? stage-table s)) stages))
    (error 'flow "bad stage group ~a: ~e" g stages)))

;; selector -> 扁平层名列表
;;
;;   'validate               单层
;;   'frontend               层组
;;   '(frontend backend)     多个层/组, 按顺序展开
;;   '((expand-data flatten)) 任意片段; 嵌套列表也按顺序展开
;;
;; 返回的列表仍然由 run-flow 按顺序执行, 所以"层组"只是写法, 没有额外语义。
(define (select-stages selector)
  (define (walk x)
    (cond
      [(symbol? x)
       (cond
         [(hash-has-key? stage-table x) (list x)]
         [(hash-has-key? stage-groups x) (hash-ref stage-groups x)]
         [else
          (error 'select-stages
                 "未知的层或层组 `~a`；已知层: ~a；已知组: ~a"
                 x (stage-names) (group-names))])]
      [(list? x) (append* (for/list ([y (in-list x)]) (walk y)))]
      [else
       (error 'select-stages
              "选择器只能是层名/组名或它们的列表: ~e" x)]))
  (walk selector))

;; ---------------------------------------------------------------------------
;; 跑
;; ---------------------------------------------------------------------------

;; seed 既可以是 (名字 . 值) 列表, 也可以直接是上一趟 run-flow 的 context。
;; 后者用来做"片段测试": 跑完前面, 把 context 喂给下一段。
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

(define (run-flow target selector [seeds '()])
  (define names (select-stages selector))
  (define ctx (seed-context seeds))
  (for ([n (in-list names)] [step (in-naturals)])
    (define st (hash-ref stage-table n))
    (for ([r (in-list (stage-requires st))]
          #:unless (optional-requirement? r))
      (unless (hash-has-key? ctx (requirement-name r))
        (error 'run-flow
               "第 ~a 步 `~a` 需要 `~a`，但它前面没有层产出它，seed 里也没有。~a"
               step n (requirement-name r)
               (let ([ps (providers-of (requirement-name r))])
                 (if (null? ps) "" (format "能产出它的是: ~a" ps))))))
    ;; 可选输入: 在途值里有才传进去(层自己给缺省)
    (define in (for/hash ([r (in-list (stage-requires st))]
                          #:when (hash-has-key? ctx (requirement-name r)))
                 (values (requirement-name r) (hash-ref ctx (requirement-name r)))))
    (for ([(k v) (in-hash ((stage-run st) target in))]) (hash-set! ctx k v)))
  ctx)

;; 单层: 只返回这层 provides 的值, 不带 seed 和其它上下文。
;; 要跑片段/层组用 run-flow。
(define (run-stage target name [seeds '()])
  (unless (and (symbol? name) (hash-has-key? stage-table name))
    (error 'run-stage
           "~a 不是层名；已知层: ~a；已知组: ~a（层组/片段用 run-flow）"
           name (stage-names) (group-names)))
  (define st (hash-ref stage-table name))
  (define ctx (run-flow target (list name) seeds))
  (for/hash ([v (in-list (stage-provides st))])
    (values v (hash-ref ctx v))))

(define (flow-value ctx name)
  (hash-ref ctx name
            (lambda () (error 'flow-value "流里没有 `~a`（有的: ~a）" name (hash-keys ctx)))))

;; 统一编译入口: target + seed (+ 可选 flow) -> build。
;; 只做组合, 不增加任何层语义。
(define (compile target seeds [flow default-flow])
  (flow-value (run-flow target flow seeds) 'build))
