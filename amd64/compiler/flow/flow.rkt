#lang racket
;;; flow/flow.rkt
;;;
;;; 构建流: 用一张 stage 表 + 一个名字列表把各层串起来。
;;;
;;;   (run-flow target
;;;             (list 'expand-data 'flatten 'expand-pseudo 'analyze 'dce 'layout 'bind-labels 'encode)
;;;             '((rich-data . …) (program-items . …) (layout-spec . …)))
;;;
;;; 每个 stage 声明两件事:
;;;   requires : 跑之前"在途值"里必须有哪些名字
;;;   provides : 跑完写入哪些名字（可以多个 = 多向传递）
;;;
;;; 于是:
;;;   * 可选   = 不写进列表
;;;   * 顺序   = 列表顺序
;;;   * 平层   = 两个 stage 的 requires/provides 相同，
;;;              写哪个、写几次都由列表决定
;;;   * 依赖   = 运行到某步时按 requires 检查，缺了就报错并给出"谁能提供"
;;;   * target = run-flow 的显式参数，stage run 接收 (target in)
;;;
;;; stage 名字是契约；目录名现在也叫这个，但**流只认名字**，不认目录结构。

(require (only-in "../../loko-compatibility/translate.rkt" translate-loko-source)
         (only-in "../../loko-compatibility/ir.rkt" make-loko-ir ir-list)
         (only-in "../../loko-compatibility/lower/ir.rkt" lower-loko-ir)
         (only-in "../../loko-compatibility/image/layout-spec.rkt" build-layout-spec)
         (only-in "../../amd64-elf/writer.rkt" write-elf)
         (only-in "../expand-data/expand.rkt" expand-data)
         (only-in "../flatten/flatten.rkt" flatten-inputs)
         (only-in "../expand-pseudo/rewrite.rkt" rewrite-program pseudo-leftover?)
         (only-in "../analyze/analyze.rkt" analyze)
         (only-in "../dce/dce.rkt" eliminate-dead)
         (only-in "../layout/layout.rkt" layout-program)
         (only-in "../relax/relax.rkt" relax)
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
         compile-image
         context-value
         default-flow)

;; ---------------------------------------------------------------------------
;; 在途值（名字就是契约）
;;
;;   loko-source    Loko 汇编写法 (loko-source (text ...) (data ...))
;;   loko-aliases   %equiv 解析后的 (alias 名字 值) 列表
;;   loko-ir        sections / origin / modes / symbols / comms
;;   rich-data      人写的 rich 数据（expand-data 的输入）
;;   data-items     核心数据 item（label / bytes / fill / value / align / pad）
;;   program-items  扁平的程序 item（可以是 (module …) 嵌套）
;;   names          flatten 建的名字表（链 -> 位置）
;;   program        (struct program blocks flows)
;;   measured-layout 度量产物（segments + anchors + requests + problems）
;;   bound-layout    绑定产物（segments + anchors + symbols + requests + problems）
;;   build           最终产物 (build (segment …) …)
;;
;;   外部输入（seed）：rich-data / program-items / data-items / layout-spec
;; ---------------------------------------------------------------------------

(struct stage (name requires provides run doc) #:transparent)

(define stage-table
  (hash
   'loko-compat
   (stage 'loko-compat '(loko-source) '(program-items data-items loko-aliases loko-ir)
          (lambda (_target in)
            (define out (translate-loko-source (hash-ref in 'loko-source)))
            (define fields (cdr out))
            (define problems (cdr (assq 'problems fields)))
            (when (pair? problems)
              (error 'loko-compat "~e" problems))
            (hash 'program-items (cdr (assq 'program-items fields))
                  'data-items (cdr (assq 'data-items fields))
                  'loko-aliases (cdr (assq 'aliases fields))
                  'loko-ir (make-loko-ir (cadr (assq 'origin fields))
                                         (cdr (assq 'symbols fields))
                                         (cdr (assq 'comms fields))
                                         (cdr (assq 'sections fields))
                                         (cdr (assq 'image-plan fields)))))
          "Loko 汇编写法 -> 核心 item + loko-ir（sections/origin/mode/symbols/comms）")

   'loko-lower
   (stage 'loko-lower '(loko-ir) '(loko-ir)
          (lambda (_target in)
            (define-values (ir problems)
              (lower-loko-ir (hash-ref in 'loko-ir)))
            (when (pair? problems)
              (error 'loko-lower "~e" problems))
            (hash 'loko-ir ir))
          "loko-ir: code section 的 (reg N) -> 物理寄存器")

   'loko-image
   (stage 'loko-image '(loko-ir)
          '(program-items data-items layout-spec)
          (lambda (_target in)
            (define-values (spec program-items data-items problems)
              (build-layout-spec (hash-ref in 'loko-ir)))
            (when (pair? problems)
              (error 'loko-image "~e" problems))
            (hash 'program-items program-items
                  'data-items data-items
                  'layout-spec spec))
          "loko-ir -> layout-spec + 扁平 items")

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
          (lambda (_target in) (hash 'program (eliminate-dead (hash-ref in 'program))))
          "死代码消除（三个 pass 跑到不动点）")

   'layout
   (stage 'layout '(program data-items layout-spec) '(measured-layout)
          (lambda (target in)
            (hash 'measured-layout
                  (layout-program target
                                  (hash-ref in 'program)
                                  (hash-ref in 'data-items)
                                  (hash-ref in 'layout-spec))))
          "布局度量: 放置 + 尺寸 + anchors + requests/problems（第一版扁平 item/块桥接）")

   'relax
   (stage 'relax '(program data-items layout-spec) '(measured-layout)
          (lambda (target in)
            (hash 'measured-layout
                  (relax target
                         (hash-ref in 'program)
                         (hash-ref in 'data-items)
                         (hash-ref in 'layout-spec))))
          "分支松弛: jmp-short/jcc-short -> near，只增不减")

   'bind-labels
   (stage 'bind-labels '(measured-layout) '(bound-layout)
          (lambda (_target in)
            (hash 'bound-layout
                  (bind-labels (hash-ref in 'measured-layout))))
          "地址绑定: anchors -> symbols（偏移 -> 绝对地址）+ 最终宽度/容量检查")

   'encode
   (stage 'encode '(bound-layout) '(build)
          (lambda (target in) (hash 'build (encode-layout target (hash-ref in 'bound-layout))))
          "编码: bound-layout -> (build …)；有 request/problem 就拒绝出产物")

   'loko-elf
   (stage 'loko-elf '(build bound-layout loko-ir) '(image)
          (lambda (_target in)
            (define symbols
              (cdr (assq 'symbols (hash-ref in 'bound-layout))))
            (define plan (ir-list (hash-ref in 'loko-ir) 'image-plan))
            (hash 'image (write-elf (hash-ref in 'build) symbols #:plan plan)))
          "build + symbols + image-plan -> ELF64 image")))

;; ---------------------------------------------------------------------------
;; 查询
;; ---------------------------------------------------------------------------

(define (stage-names) (sort (hash-keys stage-table) symbol<?))

(define (providers-of value)
  (sort (for/list ([st (in-list (hash-values stage-table))]
                   #:when (memq value (stage-provides st)))
          (stage-name st))
        symbol<?))

;; 默认流: 从 rich 数据走到字节。
(define default-flow
  '(expand-data flatten expand-pseudo analyze dce relax bind-labels encode))

;; ---------------------------------------------------------------------------
;; 选择器: 层名 / 层组 / 任意片段
;; ---------------------------------------------------------------------------

;; 层组 = 常用片段的预定义列表。组名不能和层名重名。
;; 组里只写层名; 想临时组合就直接写列表, 不必先定义组。
(define stage-groups
  (hash
   'loko        '(loko-compat loko-lower loko-image expand-pseudo analyze dce relax bind-labels encode)
   'loko-manual '(loko-compat loko-lower expand-pseudo analyze dce relax bind-labels encode)
   'elf         '(loko-compat loko-lower loko-image expand-pseudo analyze dce relax bind-labels encode loko-elf)
   'elf-manual  '(loko-compat loko-lower expand-pseudo analyze dce relax bind-labels encode loko-elf)
   'frontend '(expand-data flatten expand-pseudo)
   'ir       '(analyze dce)
   'backend  '(relax bind-labels encode)
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
;;   'analyze                单层
;;   'frontend               层组
;;   '(frontend ir backend)  多个层/组, 按顺序展开
;;   '((analyze dce))        任意片段; 嵌套列表也按顺序展开
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
    (for ([r (in-list (stage-requires st))])
      (unless (hash-has-key? ctx r)
        (error 'run-flow
               "第 ~a 步 `~a` 需要 `~a`，但它前面没有层产出它，seed 里也没有。~a"
               step n r
               (let ([ps (providers-of r)])
                 (if (null? ps) "" (format "能产出它的是: ~a" ps))))))
    (define in (for/hash ([r (in-list (stage-requires st))]) (values r (hash-ref ctx r))))
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

(define (context-value ctx name)
  (hash-ref ctx name
            (lambda () (error 'context-value "流里没有 `~a`（有的: ~a）" name (hash-keys ctx)))))

;; 统一编译入口: target + seed (+ 可选 flow) -> build。
;; 只做组合, 不增加任何层语义。
(define (compile target seeds [flow default-flow])
  (context-value (run-flow target flow seeds) 'build))

(define (compile-image target seeds [flow 'elf])
  (context-value (run-flow target flow seeds) 'image))
