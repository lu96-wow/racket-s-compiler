#lang racket
;;; L5/demo.rkt -- 布局计算
;;;
;;; 输入三样, 都是各自的形状(这里都直接手写, 不依赖别层的代码):
;;;   program : L4 的输出 = 块(身份 + 程序) + 流
;;;   data    : 扁平 item 列表
;;;   layout  : (segments ...) + (place ...)
;;; 输出: (layout (segment ...) (symbols ...) (problems ...))

(require "layout.rkt"
         (only-in "../L3/analyze.rkt" sexp->program))

(define prog
  (sexp->program
   '((blocks
      (block ((prog1 main)) (lwu t0 sp 8) (bge t1 t0 (prog1 done)))
      (block () (jal x0 (prog1cold cold)))
      (block ((prog1 done)) (la t2 (data1 table)) (add a0 a0 x0) (jalr x0 ra 0))
      (block ((prog1cold cold)) (addi a0 a0 1) (jalr x0 ra 0)))
     (flows
      (flow (succ 2 1) (fallthrough 1) (root? #t))
      (flow (succ 3) (fallthrough #f) (root? #f))
      (flow (succ) (fallthrough #f) (root? #f))
      (flow (succ) (fallthrough #f) (root? #f))))))

(define data
  '((label data1 table) (align 8) (bytes 1 2 3 4 5 6 7 8)))

(define layout-input
  '((segments (segment prog1     code #x100000 #x100FFF 16)
              (segment prog1cold code #x300000 #x300FFF 16)
              (segment data1     data #x001000 #x0010FF 16))
    ;; 精确匹配块头的 label 链; 没有 label 的块跟随前一个锚点
    (place prog1     (prog1 main) (prog1 done))
    (place prog1cold (prog1cold cold))
    (place data1     (data1 table))))

(define laid (layout-program prog data layout-input))

(displayln ";; L5 输出 (offset 注解 + 符号 + 问题)")
(for ([seg (in-list (cdr laid))]
      #:when (and (pair? seg) (eq? (car seg) 'segment)))
  (define name (cadr (assoc 'name (cdr seg))))
  (define kind (cadr (assoc 'kind (cdr seg))))
  (define start (cadr (assoc 'start (cdr seg))))
  (define size (cadr (assoc 'size (cdr seg))))
  (displayln (format "  ~a ~a start=~x size=~a" name kind start size))
  (for ([entry (in-list (cdr (assoc 'items (cdr seg))))])
    (displayln (format "    ~s" entry))))

(newline)
(displayln ";; 符号 (链 -> 段 偏移 绝对地址)")
(for ([s (in-list (cdr (assoc 'symbols (cdr laid))))])
  (displayln (format "  ~s -> ~a+~x (#x~x)" (car s) (cadr s) (caddr s) (cadddr s))))

(newline)
(displayln (format "problems: ~s" (layout-problems laid)))
