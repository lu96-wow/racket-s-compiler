#lang racket
;;; L4/demo.rkt -- L1 -> L2 -> L3 -> L4 (布局计算)

(require (only-in "../L1/flatten.rkt" flatten-inputs)
         (only-in "../L2/rewrite.rkt" rewrite-program)
         (only-in "../L3/opt.rkt" optimize-program)
         "layout.rkt")

(define program
  '((module prog1
      (label main)
      (load-32 t0 sp 8)            ; L2: lwu
      (ble t0 t1 (done))           ; L2: bge
      (jal x0 (prog1cold cold))    ; 跨段跳: 写完整链
      (label done)
      (la t2 (data1 table))        ; 跨段取址
      (move a0 a0)                 ; L2: add
      (jalr x0 ra 0))              ; 顺序执行到此为止(否则 fallthrough 会跨段)
    (module prog1cold
      (label cold)                 ; 段归属由 layout 的 place 行决定
      (addi a0 a0 1)
      (jalr x0 ra 0))))

(define data
  '((module data1
      (label table)
      (align 8)
      (bytes 1 2 3 4 5 6 7 8))))

(define layout-input
  '((segments (segment prog1     code #x100000 #x100FFF 16)
              (segment prog1cold code #x300000 #x300FFF 16)
              (segment data1     data #x001000 #x0010FF 16))
    ;; 精确匹配 label 链; 没有 section, 没有 primary, 没有 entry
    ;; 放完 L4 会检查 fallthrough 有没有被段切断
    (place prog1     (prog1 main) (prog1 done))
    (place prog1cold (prog1cold cold))
    (place data1     (data1 table))))

;; L1 一次吃程序 + 数据, 共享一张名字表(跨输入引用才查得到)
(define-values (flat-inputs _) (flatten-inputs (list program data)))
(define after-l1 (list-ref flat-inputs 0))
(define data*    (list-ref flat-inputs 1))
(define after-l2 (rewrite-program after-l1))
(define after-l3 (optimize-program after-l2))   ; 输出块列表, 不是扁平 item

(displayln ";; L3 输出块 (id labels succ fallthrough)")
(for ([b (in-list after-l3)])
  (displayln (format "  ~a"
                     (list (cadr (assoc 'id (cdr b)))
                           (cdr (assoc 'labels (cdr b)))
                           (cadr (assoc 'fallthrough (cdr b)))))))
(define laid     (layout-program after-l3 data* layout-input))



(displayln ";; L4 布局")
(for ([seg (in-list (cdr laid))]
      #:when (and (pair? seg) (eq? (car seg) 'segment)))
  (displayln (format "  ~a ~a start=~x end=~x size=~a"
                     (cadr (assoc 'name (cdr seg)))
                     (cadr (assoc 'kind (cdr seg)))
                     (cadr (assoc 'start (cdr seg)))
                     (cadr (assoc 'end (cdr seg)))
                     (cadr (assoc 'size (cdr seg)))))
  (for ([entry (in-list (cdr (assoc 'items (cdr seg))))])
    (displayln (format "    ~s" entry))))

(newline)
(displayln ";; 符号")
(for ([s (in-list (cdr (assoc 'symbols (cdr laid))))])
  (displayln (format "  ~s -> ~a+~x (#x~x)"
                     (car s) (cadr s) (caddr s) (cadddr s))))

(newline)
(displayln (format "problems: ~s" (cdr (assoc 'problems (cdr laid)))))
