#lang racket
;;; layout/program.rkt
;;;
;;; 程序级布局：把多个已 call-lower 的 machine func、raw 单元和 data 段
;;; 排成一段代码 + 数据，解析 call-target 和 addr-global 的地址。
;;;
;;; 第一版：
;;;   - 处理 func + raw + data；
;;;   - 顺序固定：函数 → raw → data（各自按输入顺序）；
;;;   - 每个函数先走 layout-plan + layout-func；
;;;   - call-target 初始按 8 字节的 auipc+jalr 预留；
;;;   - 能放进 jal 的调用缩短为 4 字节；
;;;   - addr-global 固定 8 字节：auipc + addi；
;;;   - data 地址初值在所有段放置后按 origin + 目标偏移 + addend 回填；
;;;   - 尺寸只减不增，迭代到固定点；
;;;   - 不处理外部符号 / linker。

(require racket/list
         "../../riscv-help/ranges.rkt"
         "../core/sexp.rkt"
         "../ir/cfg.rkt"
         "../ir/verify-machine.rkt"
         "../data/data.rkt"
         "../raw/raw.rkt"
         "../asm/code.rkt"
         "../link/external.rkt"
         "policy.rkt"
         "plan.rkt"
         "relax.rkt")

(provide (struct-out function-section)
         (struct-out raw-section)
         (struct-out data-section)
         (struct-out program-layout)
         layout-program
         addr-global-items
         program-layout->sexp)

;; items 已经是最终形式：
;;   call-jal / addr-global 已解析；call-target 不再存在。
(struct function-section
  (name    ; 全局链
   items   ; layout items
   base    ; 程序内起始偏移
   size    ; 字节数
   result) ; 原 layout-result，保留 frame / scratch
  #:transparent)

(struct raw-section
  (name
   items
   base
   size
   labels)  ; hash 全局链 -> 段内偏移
  #:transparent)

(struct data-section
  (name    ; 全局链
   base
   size
   align
   bytes       ; (listof byte)，本地地址位置已回填
   relocations ; (listof data-relocation)，原始 relocation
   external-relocations ; 留给 link 的 data-relocation
   labels)      ; hash 全局链 -> 段内偏移
  #:transparent)

(struct program-layout
  (sections      ; (listof function-section | data-section)
   size          ; 总字节数，包括段间 padding
   bases         ; hash 本地全局名 -> 起始偏移
   origin        ; 程序绝对地址起点；data 地址初值使用
   externs       ; 外部 (extern chain (kind kind)) 列表
   scratch-request) ; 所有函数的 max scratch request
  #:transparent)

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (layout-program program
                        #:policy [policy default-layout-policy]
                        #:xlen [xlen 64]
                        #:origin [origin 0]
                        #:externs [externs '()])
  (unless (list? program)
    (error 'layout-program "expected a proper program list: ~e" program))
  (unless (policy-valid? policy)
    (error 'layout-program "invalid layout policy: ~e" policy))
  (unless (memq xlen '(32 64))
    (error 'layout-program "xlen must be 32 or 64: ~e" xlen))
  (unless (exact-nonnegative-integer? origin)
    (error 'layout-program "origin must be a non-negative integer: ~e" origin))
  (define extern-table* (extern-table externs))

  (define funcs
    (for/list ([item (in-list program)] #:when (tagged? item 'func)) item))
  (define datas
    (for/list ([item (in-list program)] #:when (tagged? item 'data)) item))
  (define raws
    (for/list ([item (in-list program)] #:when (tagged? item 'raw)) item))
  (for ([item (in-list program)])
    (unless (or (tagged? item 'func) (tagged? item 'data) (tagged? item 'raw))
      (error 'layout-program
             "program layout only accepts func / data / raw: ~e" item)))

  (define data-layouts
    (for/list ([data (in-list datas)])
      (cons data (layout-data data))))
  (define raw-layouts
    (for/list ([raw (in-list raws)])
      (layout-raw raw)))

  ;; 函数 / raw / data 共用一个全局名字空间。
  (define names
    (append (map cadr funcs)
            (map data-name datas)
            (map raw-layout-name raw-layouts)
            (append*
             (for/list ([entry (in-list data-layouts)])
               (hash-keys (data-layout-labels (cdr entry)))))
            (append*
             (for/list ([l (in-list raw-layouts)])
               (for/list ([label (in-list (hash-keys (raw-layout-labels l)))]
                          #:unless (equal? label (raw-layout-name l)))
                 label)))))
  (define seen (make-hash))
  (for ([name (in-list names)])
    (when (hash-has-key? seen name)
      (error 'layout-program "global name ~a is defined twice"
             (chain->string name)))
    (hash-set! seen name #t))
  (for ([name (in-hash-keys extern-table*)])
    (when (hash-has-key? seen name)
      (error 'layout-program
             "global name ~a is both local and extern"
             (chain->string name))))

  ;; 每个函数先独立布局。call-target / addr-global 仍按 8 字节计。
  (define layout-sections
    (for/list ([func (in-list funcs)])
      (verify-machine-func func)
      (define cfg (build-cfg func))
      (define plan (plan-layout cfg policy))
      (define result (layout-func func plan #:policy policy #:xlen xlen))
      (function-section (cadr func)
                        (layout-result-items result)
                        0
                        0
                        result)))

  ;; 先固定调用形式（近 / 远），再计算函数偏移。
  (define decisions (decide-call-forms layout-sections extern-table*))
  (define-values (func-bases _func-sizes func-total)
    (compute-layout layout-sections decisions))

  ;; raw 段放在函数之后，data 段放在 raw 之后。
  (define-values (raw-total raw-sections)
    (place-raw raw-layouts func-total))
  (define-values (program-total data-sections)
    (place-data data-layouts raw-total))

  ;; 所有全局名 -> 地址。
  (define all-bases (make-hash))
  (for ([(name base) (in-hash func-bases)])
    (hash-set! all-bases name base))
  (for ([section (in-list raw-sections)])
    (define base (raw-section-base section))
    (hash-set! all-bases (raw-section-name section) base)
    (for ([(label offset) (in-hash (raw-section-labels section))])
      (hash-set! all-bases label (+ base offset))))
  (for ([section (in-list data-sections)])
    (define base (data-section-base section))
    (hash-set! all-bases (data-section-name section) base)
    (for ([(label offset) (in-hash (data-section-labels section))])
      (hash-set! all-bases label (+ base offset))))

  ;; 所有段都放好之后，回填 data 里的地址初值。
  (define final-data-sections
    (for/list ([section (in-list data-sections)])
      (define-values (bytes external-relocations)
        (apply-data-relocations section origin all-bases extern-table*))
      (data-section (data-section-name section)
                    (data-section-base section)
                    (data-section-size section)
                    (data-section-align section)
                    bytes
                    (data-section-relocations section)
                    external-relocations
                    (data-section-labels section))))

  (define final-func-sections
    (for/list ([section (in-list layout-sections)]
               [section-index (in-naturals)])
      (define name (function-section-name section))
      (define base (hash-ref func-bases name))
      (define local 0)
      (define items
        (append*
         (for/list ([item (in-list (function-section-items section))]
                    [item-index (in-naturals)])
           (define key (call-key section-index item-index))
           (define size (item-size-with-decisions item decisions key))
           (define here (+ base local))
           (set! local (+ local size))
           (cond
             [(call-target-item? item)
              (resolve-call-target item key here func-bases decisions xlen
                                   extern-table*)]
             [(addr-global-item? item)
              (resolve-addr-global item here all-bases origin xlen
                                   extern-table*)]
             [else (list item)]))))
      (function-section name items base local (function-section-result section))))

  (define final-func-total
    (for/fold ([n 0]) ([section (in-list final-func-sections)])
      (+ n (function-section-size section))))
  (unless (= final-func-total func-total)
    (error 'layout-program
           "internal: call relaxation changed sizes unexpectedly (~a vs ~a)"
           final-func-total func-total))

  (define scratch-request
    (for/fold ([n 0]) ([section (in-list final-func-sections)])
      (max n (layout-result-scratch-request
              (function-section-result section)))))

  (program-layout (append final-func-sections raw-sections final-data-sections)
                  program-total
                  all-bases
                  origin
                  externs
                  scratch-request))

(define (program-layout->sexp program)
  (list 'program
        (list 'size (program-layout-size program))
        (list 'origin (program-layout-origin program))
        (cons 'externs (program-layout-externs program))
        (cons 'sections
              (for/list ([section (in-list (program-layout-sections program))])
                (cond
                  [(function-section? section)
                   (list 'function-section
                         (list 'name (function-section-name section))
                         (list 'base (function-section-base section))
                         (list 'size (function-section-size section))
                         (cons 'items (function-section-items section)))]
                  [(raw-section? section)
                   (list 'raw-section
                         (list 'name (raw-section-name section))
                         (list 'base (raw-section-base section))
                         (list 'size (raw-section-size section))
                         (cons 'items (raw-section-items section)))]
                  [(data-section? section)
                   (list 'data-section
                         (list 'name (data-section-name section))
                         (list 'base (data-section-base section))
                         (list 'size (data-section-size section))
                         (list 'align (data-section-align section))
                         (cons 'labels
                               (sort (hash-keys (data-section-labels section))
                                     chain<?)))]
                  [else
                   (error 'layout-program "unknown program section: ~e" section)])))))

;; ---------------------------------------------------------------------------
;; data 放置
;; ---------------------------------------------------------------------------

(define (place-raw raw-layouts start)
  (for/fold ([offset start] [sections '()])
            ([l (in-list raw-layouts)])
    (define base offset)
    (define size (raw-layout-size l))
    (values (+ base size)
            (append sections
                    (list (raw-section (raw-layout-name l)
                                       (raw-layout-items l)
                                       base size
                                       (raw-layout-labels l)))))))

(define (place-data data-layouts start)
  (for/fold ([offset start] [sections '()])
            ([entry (in-list data-layouts)])
    (define data (car entry))
    (define l (cdr entry))
    (define align (data-layout-align l))
    (define base (align-up offset align))
    (define size (data-layout-size l))
    (values (+ base size)
            (append sections
                    (list (data-section (data-name data)
                                        base size align
                                        (data-layout-bytes l)
                                        (data-layout-relocations l)
                                        '()
                                        (data-layout-labels l)))))))

;; ---------------------------------------------------------------------------
;; data 地址回填
;; ---------------------------------------------------------------------------

(define (apply-data-relocations section origin bases extern-table*)
  (define vec (list->vector (data-section-bytes section)))
  (define external '())
  (for ([reloc (in-list (data-section-relocations section))])
    (define target (data-relocation-target reloc))
    (define target-base (hash-ref bases target #f))
    (cond
      [target-base
       (define value (+ origin target-base (data-relocation-addend reloc)))
       (define width (data-relocation-width reloc))
       (define max (sub1 (arithmetic-shift 1 (* 8 width))))
       (unless (<= 0 value max)
         (error 'layout-program
                "data address value for ~a does not fit in ~a bytes: ~a"
                (chain->string target) width value))
       (define offset (data-relocation-offset reloc))
       (for ([i (in-range width)])
         (vector-set! vec (+ offset i)
                      (bitwise-and (arithmetic-shift value (- (* 8 i))) #xFF)))]
      [else
       (define kind (hash-ref extern-table* target #f))
       (unless (and kind (extern-address-kind? kind))
         (error 'layout-program "data value refers to undefined global ~a"
                (chain->string target)))
       (set! external (append external (list reloc)))]))
  (values (vector->list vec) external))

;; ---------------------------------------------------------------------------
;; call-target 决策
;; ---------------------------------------------------------------------------

;; 返回 (hash (section-index item-index) -> #t)；#t 表示最终用 4 字节 jal。
(define (decide-call-forms sections extern-table*)
  (define decisions (make-hash))
  (let loop ()
    (define-values (bases _sizes _total)
      (compute-layout sections decisions))
    (define additions '())
    (for ([section (in-list sections)]
          [section-index (in-naturals)])
      (define base (hash-ref bases (function-section-name section)))
      (define local 0)
      (for ([item (in-list (function-section-items section))]
            [item-index (in-naturals)])
        (define key (call-key section-index item-index))
        (define size (item-size-with-decisions item decisions key))
        (define here (+ base local))
        (when (call-target-item? item)
          (define target (call-target-chain item))
          (define target-base (hash-ref bases target #f))
          (unless target-base
            (define kind (hash-ref extern-table* target #f))
            (unless (and kind (extern-call-kind? kind))
              (error 'layout-program "call refers to undefined function ~a"
                     (chain->string target))))
          (when target-base
            (define delta (- target-base here))
            (when (and (not (hash-has-key? decisions key))
                       (fits-jal? delta))
              (set! additions (cons key additions)))))
        (set! local (+ local size))))
    (cond
      [(null? additions)
       decisions]
      [else
       (for ([key (in-list additions)])
         (hash-set! decisions key #t))
       (loop)])))

(define (resolve-call-target item key here bases decisions xlen extern-table*)
  (define target (call-target-chain item))
  (define target-base (hash-ref bases target #f))
  (unless target-base
    (define kind (hash-ref extern-table* target #f))
    (unless (and kind (extern-call-kind? kind))
      (error 'layout-program "call refers to undefined function ~a"
             (chain->string target))))
  (cond
    [(not target-base)
     (list (list 'reloc-call (list 'global target)))]
    [else
     (define delta (- target-base here))
     (cond
       [(hash-has-key? decisions key)
        (unless (fits-jal? delta)
          (error 'layout-program
                 "internal: near call to ~a no longer fits jal (delta ~a)"
                 (chain->string target) delta))
        (list (list 'call-jal delta))]
       [else
        (unless (fits-auipc-pair? delta (if (= xlen 64) 'rv64 'rv32))
          (error 'layout-program
                 "call to ~a is outside auipc+jalr range (delta ~a)"
                 (chain->string target) delta))
        (define-values (hi lo) (split-hi-lo delta))
        (list (list 'auipc '(native x1) hi)
              (list 'jalr '(native x1) '(native x1) lo))])]))

;; ---------------------------------------------------------------------------
;; addr(global)
;; ---------------------------------------------------------------------------

(define (resolve-addr-global item here bases origin xlen extern-table*)
  (define dst (cadr item))
  (define target (cadr (caddr item)))    ; (global chain) -> chain
  (define target-base (hash-ref bases target #f))
  (cond
    [target-base
     (addr-global-items dst target-base here origin xlen)]
    [else
     (define kind (hash-ref extern-table* target #f))
     (unless (and kind (extern-address-kind? kind))
       (error 'layout-program "addr refers to undefined global ~a"
              (chain->string target)))
     (list (list 'reloc-addr dst (list 'global target)))]))

;; addr(global) 的最终形式。
;;   近：auipc + addi（PC-relative）
;;   远：lui + addi（绝对地址，仍然是 8 字节）
;; 两种形式尺寸相同，因此可以放在 program-layout 里直接决定，不改变尺寸固定点。
(define (addr-global-items dst target-base here origin xlen)
  (define word-size (if (= xlen 64) 'rv64 'rv32))
  (define delta (- target-base here))
  (cond
    [(fits-auipc-pair? delta word-size)
     (define-values (hi lo) (split-hi-lo delta))
     (list (list 'auipc dst hi)
           (list 'addi dst dst lo))]
    [else
     (define absolute (+ origin target-base))
     (unless (fits-lui-addi? absolute word-size)
       (error 'layout-program
              "addr far form cannot encode absolute address ~a for ~a"
              absolute word-size))
     (define-values (hi lo) (split-hi-lo absolute))
     (list (list 'lui dst hi)
           (list 'addi dst dst lo))]))

;; ---------------------------------------------------------------------------
;; 尺寸 / 偏移
;; ---------------------------------------------------------------------------

(define (call-key section-index item-index)
  (list section-index item-index))

(define (call-target-item? item)
  (eq? (car item) 'call-target))

(define (addr-global-item? item)
  (eq? (car item) 'addr-global))

(define (call-target-chain item)
  (cadr (cadr item)))                   ; (call-target (global chain)) -> chain

;; 这里输入的是 layout-relax 已经 emit 的 flat items：
;;   (label name) / native 指令 / call-target / addr-global。
;; 除 label、call-target、addr-global 外，所有指令都是 4 字节。
(define (flat-item-size item)
  (case (car item)
    [(label) 0]
    [(call-target) 8]
    [(addr-global) 8]
    [(call-jal) 4]
    [(reloc-call) 8]
    [(reloc-addr) 8]
    [(asm-code) (asm-code-size (cadr item))]
    [else 4]))

(define (item-size-with-decisions item decisions key)
  (cond
    [(and (call-target-item? item)
          (hash-has-key? decisions key))
     4]
    [else (flat-item-size item)]))

;; 返回 (values bases sizes total)。
(define (compute-layout sections decisions)
  (define bases (make-hash))
  (define sizes (make-hash))
  (define offset 0)
  (for ([section (in-list sections)]
        [section-index (in-naturals)])
    (define name (function-section-name section))
    (hash-set! bases name offset)
    (define local 0)
    (for ([item (in-list (function-section-items section))]
          [item-index (in-naturals)])
      (set! local
            (+ local
               (item-size-with-decisions item decisions
                                         (call-key section-index item-index)))))
    (hash-set! sizes name local)
    (set! offset (+ offset local)))
  (values bases sizes offset))
