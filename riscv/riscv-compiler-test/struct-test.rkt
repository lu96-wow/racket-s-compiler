#lang racket
;;; struct-test.rkt -- struct 布局 / 静态数据 / 动态访问 / 导出元数据

(require rackunit
         racket/list
         "helpers.rkt"
         (only-in "../riscv-compiler/struct/struct.rkt" expand-struct-inputs)
         (only-in "../riscv-compiler/flow/flow.rkt"
                  run-flow flow-value default-flow)
         (only-in "../riscv-compiler/target.rkt"
                  target-rv64-base target-rv32-all))

(define target target-rv64-base)

(define (expand prog data [tgt target])
  (call-with-values (lambda () (expand-struct-inputs tgt prog data))
    (lambda (p d s _sp) (list p d s))))

(define (expand-all prog data [tgt target] [extern-structs '()])
  (call-with-values (lambda () (expand-struct-inputs tgt prog data extern-structs))
    (lambda (p d s sp) (list p d s sp))))

(define (structs-of-build build)
  (cdr (assoc 'structs (cdr build))))

(define (sdef-name def) (cadr (assoc 'name (cdr def))))
(define (sdef-size def) (cadr (assoc 'size (cdr def))))
(define (sdef-align def) (cadr (assoc 'align (cdr def))))
(define (sdef-fields def) (cdr (assoc 'fields (cdr def))))
(define (field-name f) (cadr (assoc 'name (cdr f))))
(define (field-type f) (cadr (assoc 'type (cdr f))))
(define (field-offset f) (cadr (assoc 'offset (cdr f))))
(define (field-size f) (cadr (assoc 'size (cdr f))))
(define (field-align f) (cadr (assoc 'align (cdr f))))

;; ---------------------------------------------------------------------------
;; 布局 / sizeof / offsetof
;; ---------------------------------------------------------------------------

(define layout-prog
  '((label main)
    (li t0 (sizeof rect))
    (li t1 (offsetof rect w))
    (jalr x0 ra 0)))

(define layout-data
  '((struct point (x b32) (y b32))
    (struct rect (p point) (w b16) (h b16))))

(define-values (expanded-prog expanded-data structs)
  (apply values (expand layout-prog layout-data)))

(check-equal? expanded-prog
              '((label main)
                (li t0 12)
                (li t1 8)
                (jalr x0 ra 0)))

(check-equal? (length structs) 2)
(define point-def (findf (lambda (d) (equal? (sdef-name d) '(point))) structs))
(define rect-def  (findf (lambda (d) (equal? (sdef-name d) '(rect))) structs))
(check-equal? (sdef-size point-def) 8)
(check-equal? (sdef-align point-def) 4)
(check-equal? (map (lambda (f) (list (field-name f) (field-offset f)))
                   (sdef-fields point-def))
              '((x 0) (y 4)))

(check-equal? (sdef-size rect-def) 12)
(check-equal? (sdef-align rect-def) 4)
(check-equal? (map (lambda (f) (list (field-name f) (field-type f)
                                      (field-offset f) (field-size f)))
                   (sdef-fields rect-def))
              '((p (struct-ref (point)) 0 8)
                (w b16 8 2)
                (h b16 10 2)))

;; ---------------------------------------------------------------------------
;; 静态数据
;; ---------------------------------------------------------------------------

(define static-prog '((label main) (jalr x0 ra 0)))
(define static-data
  '((struct point (x b32) (y b32))
    (label d p)
    (struct-data point (x 1) (y 2))))

(define-values (static-p static-d _static-s)
  (apply values (expand static-prog static-data)))

(check-equal? static-d
              '((label d p)
                (align 4)
                (value 4 1)
                (value 4 2)))

;; 嵌套 struct + padding
(define nested-data
  '((struct point (x b32) (y b32))
    (struct rect (p point) (w b16) (h b16))
    (label d r)
    (struct-data rect
      (p (x 1) (y 2))
      (w 3)
      (h 4))))

(define-values (_np nested-d _ns)
  (apply values (expand static-prog nested-data)))

(check-equal? nested-d
              '((label d r)
                (align 4)
                (align 4)
                (value 4 1)
                (value 4 2)
                (value 2 3)
                (value 2 4)))

;; 数组字段
(define arr-data
  '((struct point (x b32) (y b32))
    (struct arr (a (array 2 point)))
    (label d a)
    (struct-data arr
      (a (array ((x 1) (y 2)) ((x 3) (y 4)))))))

(define-values (_ap arr-d _as)
  (apply values (expand static-prog arr-data)))

(check-equal? arr-d
              '((label d a)
                (align 4)
                (align 4)
                (value 4 1)
                (value 4 2)
                (align 4)
                (value 4 3)
                (value 4 4)))


;; ---------------------------------------------------------------------------
;; 内部对齐 / 空洞
;; ---------------------------------------------------------------------------

(define align-data
  '((struct aligned
      (a b8)
      (align 8)
      (b b32)
      (pad 3)
      (c b16))
    (label d a)
    (struct-data aligned
      (a 1)
      (b 2)
      (c 3))))

(define-values (align-p align-d align-s)
  (apply values
         (expand '((label main)
                   (li t0 (sizeof aligned))
                   (li t1 (offsetof aligned c))
                   (struct-load t2 t3 aligned b)
                   (jalr x0 ra 0))
                 align-data)))

(check-equal? align-p
              '((label main)
                (li t0 24)
                (li t1 16)
                (lwu t2 t3 8)
                (jalr x0 ra 0)))

(check-equal? align-d
              '((label d a)
                (align 8)
                (value 1 1)
                (pad 7)
                (value 4 2)
                (pad 3)
                (pad 1)
                (value 2 3)
                (pad 6)))

(define aligned-def (car align-s))
(check-equal? (sdef-size aligned-def) 24)
(check-equal? (sdef-align aligned-def) 8)
(check-equal? (map (lambda (f) (list (field-name f) (field-offset f)))
                   (sdef-fields aligned-def))
              '((a 0) (b 8) (c 16)))
(check-equal? (cdr (assoc 'padding (cdr aligned-def)))
              '((align (n 8) (offset 1) (size 7))
                (pad (n 3) (offset 12) (size 3))))

(check-exn exn:fail?
           (lambda ()
             (expand '((label main) (jalr x0 ra 0))
                     '((struct bad (align 3))))))

(check-exn exn:fail?
           (lambda ()
             (expand '((label main) (jalr x0 ra 0))
                     '((struct bad (a b32) (pad -1))))))

;; ---------------------------------------------------------------------------
;; 动态访问
;; ---------------------------------------------------------------------------

(define access-prog
  '((label main)
    (struct-load t0 t1 point y)
    (struct-store t1 point y t0)
    (struct-address t2 t1 rect w)
    (struct-load-far t3 t1 rect w t4)
    (struct-store-far t1 rect w t0 t4)
    (jalr x0 ra 0)))

(define access-data
  '((struct point (x b32) (y b32))
    (struct rect (p point) (w b16) (h b16))))

(define-values (access-p _access-d _access-s)
  (apply values (expand access-prog access-data)))

(check-equal? access-p
              '((label main)
                (lwu t0 t1 4)
                (sw 4 t1 t0)
                (addi t2 t1 8)
                ((li t4 8) (add t4 t1 t4) (lhu t3 t4 0))
                ((li t4 8) (add t4 t1 t4) (sh 0 t4 t0))
                (jalr x0 ra 0)))

;; 超过 simm12: short 报错, far 可以
(define big-data
  '((struct big (a (array 600 b32)) (b b32))))

(check-exn exn:fail?
           (lambda ()
             (expand '((label main) (struct-load t0 t1 big b) (jalr x0 ra 0))
                     big-data)))

(define-values (big-p _big-d _big-s)
  (apply values
         (expand '((label main) (struct-load-far t0 t1 big b t2) (jalr x0 ra 0))
                 big-data)))
(check-equal? big-p
              '((label main)
                ((li t2 2400) (add t2 t1 t2) (lwu t0 t2 0))
                (jalr x0 ra 0)))

;; ---------------------------------------------------------------------------
;; RV32: ptr 是 4 字节
;; ---------------------------------------------------------------------------

(define-values (_r32p _r32d r32s)
  (apply values
         (expand '((label main) (jalr x0 ra 0))
                 '((struct head (p ptr) (v b64)))
                 target-rv32-all)))
(define head-def (car r32s))
(check-equal? (sdef-size head-def) 16)
(check-equal? (sdef-align head-def) 8)
(check-equal? (map field-offset (sdef-fields head-def)) '(0 8))

;; ---------------------------------------------------------------------------
;; 模块作用域 + 最终 build 导出 structs
;; ---------------------------------------------------------------------------

(define module-src
  '((module m
      (struct point (x b32) (y b32))
      (struct rect (p point) (w b32))
      (label main)
      (la-pcrel t0 (d p))
      (struct-load t1 t0 point y)
      (jalr x0 ra 0))))

(define module-rich
  '((label d p)
    (struct-data (m point) (x 7) (y 8))))

(define module-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
              (segment (name d) (kind data) (start #x2000) (end #x2100) (align 8)))
    (place c (m main))
    (place d (d p))))

(define ctx
  (run-flow target default-flow
            (list (cons 'rich-data module-rich)
                  (cons 'program-items module-src)
                  (cons 'layout-spec module-spec))))

(define build (flow-value ctx 'build))
(define exported (structs-of-build build))
(check-equal? (map sdef-name exported) '((m point) (m rect)))
(check-equal? (map sdef-size exported) '(8 12))
(check-equal? (build-size build 'd) 8)
(check-equal? (build-bytes build 'd) '(7 0 0 0 8 0 0 0))

;; ---------------------------------------------------------------------------
;; 跨模块 struct：provide / require / prefix-in / rename-in / re-export
;; ---------------------------------------------------------------------------

(define cross-src
  '((module a
      (provide point)
      (struct point (x b32) (y b32)))
    (module b
      (require a)
      (struct rect (p point) (w b32))
      (label main)
      (li t0 (sizeof point))
      (struct-load t1 t2 point y)
      (jalr x0 ra 0))))

(define-values (cross-p _cross-d cross-s cross-sp)
  (apply values (expand-all cross-src '())))

(check-equal? cross-p
              '((module a (provide point))
                (module b
                  (require a)
                  (label main)
                  (li t0 8)
                  (lwu t1 t2 4)
                  (jalr x0 ra 0))))
(check-equal? (map sdef-name cross-s) '((a point) (b rect)))
(check-equal? (map sdef-size cross-s) '(8 12))
(check-equal? (field-type (car (sdef-fields (cadr cross-s))))
              '(struct-ref (a point)))
(check-equal? cross-sp
              '((module (a) (provide (point) (a point)))
                (module (b))))

;; prefix-in 和 rename-in 只改本地名，不改绝对名。
(define rename-src
  '((module a
      (provide point)
      (struct point (x b32) (y b32)))
    (module b
      (require (prefix-in a: a))
      (struct p1 (p a:point)))
    (module c
      (require (rename-in a (point apt)))
      (struct p2 (p apt)))))

(define-values (_rename-p _rename-d rename-s _rename-sp)
  (apply values (expand-all rename-src '())))

(check-equal? (map sdef-name rename-s) '((a point) (b p1) (c p2)))
(check-equal? (map (lambda (d) (field-type (car (sdef-fields d))))
                   (cdr rename-s))
              '((struct-ref (a point)) (struct-ref (a point))))

;; re-export：b 把 require 进来的 struct 再 provide 出去。
(define reexport-src
  '((module a
      (provide point)
      (struct point (x b32) (y b32)))
    (module b
      (provide point)
      (require a))
    (module c
      (require b)
      (struct p (x point)))))

(define-values (_reexport-p _reexport-d reexport-s _reexport-sp)
  (apply values (expand-all reexport-src '())))

(check-equal? (map sdef-name reexport-s) '((a point) (c p)))
(check-equal? (field-type (car (sdef-fields (cadr reexport-s))))
              '(struct-ref (a point)))

;; 没 require 时短名不可见（完整链仍然是兼容路径）。
(check-exn exn:fail?
           (lambda ()
             (expand '((module a
                         (provide point)
                         (struct point (x b32)))
                       (module b
                         (struct rect (p point))))
                     '())))

;; 只有 struct provide 的模块不能让 flatten 误报“provide 未定义”。
(define cross-spec
  '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 4))
              (segment (name d) (kind data) (start #x2000) (end #x2100) (align 8)))
    (place c (b main))
    (place d (d p))))

(define cross-build
  (flow-value
   (run-flow target default-flow
             (list (cons 'program-items
                         '((module a
                             (provide point)
                             (struct point (x b32) (y b32)))
                           (module b
                             (require a)
                             (label main)
                             (la-pcrel t0 (d p))
                             (struct-load t1 t0 point y)
                             (jalr x0 ra 0))))
                   (cons 'rich-data
                         '((label d p)
                           (struct-data (a point) (x 7) (y 8))))
                   (cons 'layout-spec cross-spec)))
   'build))

(check-equal? (map sdef-name (structs-of-build cross-build)) '((a point)))
(check-equal? (build-size cross-build 'd) 8)
(check-equal? (build-bytes cross-build 'd) '(7 0 0 0 8 0 0 0))

;; ---------------------------------------------------------------------------
;; 跨编译单元：上一份 build 的 (structs ...) 直接作为 extern-structs 输入
;; ---------------------------------------------------------------------------

(define extern-point (structs-of-build cross-build))

(define-values (extern-p _extern-d extern-s _extern-sp)
  (apply values
         (expand-all
          '((label main)
            (li t0 (sizeof (a point)))
            (li t1 (offsetof (a point) y))
            (struct-load t2 t3 (a point) y)
            (jalr x0 ra 0))
          '() target extern-point)))

(check-equal? extern-p
              '((label main)
                (li t0 8)
                (li t1 4)
                (lwu t2 t3 4)
                (jalr x0 ra 0)))
(check-equal? (map sdef-name extern-s) '())

;; extern-structs 也可以直接给整份 build。
(check-equal? (map sdef-name
                   (list-ref (expand-all '((label main) (jalr x0 ra 0))
                                          '() target cross-build)
                             2))
              '())

;; 外部元数据里的嵌套 struct 可以直接初始化。
(define nested-extern (structs-of-build build))
(define-values (_nested-ext-p nested-ext-d _nested-ext-s _nested-ext-sp)
  (apply values
         (expand-all
          '((label main) (jalr x0 ra 0))
          '((label d r)
            (struct-data (m rect)
              (p (x 1) (y 2))
              (w 3)))
          target nested-extern)))

(check-equal? nested-ext-d
              '((label d r)
                (align 4)
                (align 4)
                (value 4 1)
                (value 4 2)
                (value 4 3)))

;; 外部元数据里的显式 align / pad 也要能在 struct-data 里还原。
(define extern-aligned
  '((struct-def
      (name (a aligned))
      (size 24)
      (align 8)
      (fields
        (field (name a) (type b8) (offset 0) (size 1) (align 1))
        (field (name b) (type b32) (offset 8) (size 4) (align 4))
        (field (name c) (type b16) (offset 16) (size 2) (align 2)))
      (padding
        (align (n 8) (offset 1) (size 7))
        (pad (n 3) (offset 12) (size 3))))))

(define-values (_align-ext-p align-ext-d _align-ext-s _align-ext-sp)
  (apply values
         (expand-all
          '((label main) (jalr x0 ra 0))
          '((label d a)
            (struct-data (a aligned) (a 1) (b 2) (c 3)))
          target extern-aligned)))

(check-equal? align-ext-d
              '((label d a)
                (align 8)
                (value 1 1)
                (pad 7)
                (value 4 2)
                (pad 3)
                (pad 1)
                (value 2 3)
                (pad 6)))

;; 同一个外部 struct 重复出现（例如两份 build 都带上了 A 的元数据）可以合并。
(check-equal? (map sdef-name
                   (list-ref (expand-all '((label main) (jalr x0 ra 0))
                                          '() target
                                          (append extern-point extern-point))
                             2))
              '())

;; 本单元自己定义同名 struct 时不能和外部定义同时存在。
(check-exn exn:fail?
           (lambda ()
             (expand-all '((struct (a point) (z b8)))
                         '() target extern-point)))

;; 完整 flow：B 不定义 point，只用 A 的元数据。
(define unit-b-program
  '((module b
      (label main)
      (li t0 (sizeof (a point)))
      (la-pcrel t1 (d p))
      (struct-load t2 t1 (a point) y)
      (jalr x0 ra 0))))

(define unit-b-rich
  '((label d p)
    (struct-data (a point) (x 7) (y 8))))

(define unit-b-spec
  '((segments (segment (name c) (kind code) (start #x3000) (end #x3100) (align 4))
              (segment (name d) (kind data) (start #x4000) (end #x4100) (align 8)))
    (place c (b main))
    (place d (d p))))

(define unit-b-build
  (flow-value
   (run-flow target default-flow
             (list (cons 'extern-structs extern-point)
                   (cons 'program-items unit-b-program)
                   (cons 'rich-data unit-b-rich)
                   (cons 'layout-spec unit-b-spec)))
   'build))

(check-equal? (map sdef-name (structs-of-build unit-b-build)) '())
(check-equal? (build-size unit-b-build 'd) 8)
(check-equal? (build-bytes unit-b-build 'd) '(7 0 0 0 8 0 0 0))

;; 跨编译单元也可以用 require：把上一份的 struct-provides 一起传进来。
(define unit-c-program
  '((module c
      (require a)
      (label main)
      (li t0 (sizeof point))
      (la-pcrel t1 (d p))
      (struct-load t2 t1 point y)
      (jalr x0 ra 0))))

(define unit-c-spec
  '((segments (segment (name c) (kind code) (start #x5000) (end #x5100) (align 4))
              (segment (name d) (kind data) (start #x6000) (end #x6100) (align 8)))
    (place c (c main))
    (place d (d p))))

(define unit-c-build
  (flow-value
   (run-flow target default-flow
             (list (cons 'extern-structs extern-point)
                   (cons 'extern-struct-provides
                         (cdr (build-struct-provides cross-build)))
                   (cons 'extern-label-provides '((module (a))))
                   (cons 'program-items unit-c-program)
                   (cons 'rich-data unit-b-rich)
                   (cons 'layout-spec unit-c-spec)))
   'build))

(check-equal? (map sdef-name (structs-of-build unit-c-build)) '())
(check-equal? (build-size unit-c-build 'd) 8)
(check-equal? (build-bytes unit-c-build 'd) '(7 0 0 0 8 0 0 0))

;; 只给 extern-units：struct 声明按当前 target 重新布局，provide 表也从 unit 取。
(define unit-d-build
  (flow-value
   (run-flow target default-flow
             (list (cons 'extern-units (list (build-unit cross-build)))
                   (cons 'program-items unit-c-program)
                   (cons 'rich-data unit-b-rich)
                   (cons 'layout-spec unit-c-spec)))
   'build))

(check-equal? (map sdef-name (structs-of-build unit-d-build)) '())
(check-equal? (build-size unit-d-build 'd) 8)
(check-equal? (build-bytes unit-d-build 'd) '(7 0 0 0 8 0 0 0))


;; 根模块的 provide 也要能写进元数据（scope 是空链）。
(define-values (_root-p _root-d _root-s root-sp)
  (apply values
         (expand-all '((provide point) (struct point (x b32)))
                     '())))
(check-equal? root-sp
              '((module () (provide (point) (point)))))

;; ---------------------------------------------------------------------------
;; 链式名字 + module 遮蔽
;; ---------------------------------------------------------------------------

(define shadow-src
  '((struct (point) (x b16))
    (module m
      (struct (point) (x b8) (y b8))
      (label f)
      (struct-load t0 t1 point x)
      (struct-load t2 t3 (point) y))
    (label g)
    (struct-load t4 t5 point x)))

(define-values (shadow-p _shadow-d shadow-s)
  (apply values (expand shadow-src '())))

(check-equal? shadow-p
              '((module m
                  (label f)
                  (lbu t0 t1 0)
                  (lbu t2 t3 1))
                (label g)
                (lhu t4 t5 0)))

(check-equal? (map sdef-name shadow-s) '((m point) (point)))
(check-equal? (map sdef-size shadow-s) '(2 2))
(check-equal? (map sdef-align shadow-s) '(1 2))

;; ---------------------------------------------------------------------------
;; 错误
;; ---------------------------------------------------------------------------

(check-exn exn:fail?
           (lambda ()
             (expand '((label main) (jalr x0 ra 0))
                     '((struct bad (x nope))))))

(check-exn exn:fail?
           (lambda ()
             (expand '((label main) (jalr x0 ra 0))
                     '((struct a (b (array 2 a)))))))

(check-exn exn:fail?
           (lambda ()
             (expand '((label main) (jalr x0 ra 0))
                     '((struct p (x b32) (x b32))))))

(finish-tests "struct")
