#lang racket
;;; L3/analyze.rkt
;;;
;;; 控制流分析: 只分析, 不改程序。
;;;
;;;   (analyze program) -> (listof block)
;;;
;;; 输入 : 扁平 item 列表 '((label ...) (insn ...) ...)
;;; 输出 : block list —— 从此以后 IR 就是块列表(Racket 数据), 不是指令 s-exp
;;;
;;; block 字段:
;;;   id          块身份
;;;   labels      块头的所有链(一个位置多名都在这)
;;;   insns       块内容
;;;   succ        后继块 id
;;;   fallthrough 物理下一条是哪个块; #f = 不以顺序方式离开
;;;   root?       外部入口: 程序入口 / (有间接跳转时)地址被取过的块
;;;
;;; 注意: block 的边界只由控制流决定(程序开头 / 转移目标 / 切流指令之后)。
;;; 非目标的 label 不是边界, 它作为位置标记留在 insns 里。
;;;
;;; root? 由分析层算好, 后面的层不需要再认识指令语义。
;;;
;;; blocks->sexp / sexp->blocks 只用于打印和写字面量(测试/demo)。

(require "insn.rkt"
         (prefix-in cfg: "cfg.rkt"))   ; cfg 里也有一个 block struct(CFG 内部用), 避免撞名

(provide (struct-out block)
         analyze
         blocks->sexp
         sexp->blocks
         program-items)

(struct block (id labels insns succ fallthrough root?) #:transparent)

;; ---------------------------------------------------------------------------
;; 程序 -> item 列表(旧壳 quote/begin 也收)
;; ---------------------------------------------------------------------------

(define (program-items prog)
  (define body
    (cond
      [(and (form? prog) (eq? (car prog) 'quote) (= 2 (length prog)) (list? (cadr prog)))
       (cadr prog)]
      [(list? prog) prog]
      [else (list prog)]))
  (define items
    (cond
      [(null? body) '()]
      [(pair? (car body)) body]
      [else (list body)]))
  (if (and (= 1 (length items)) (form? (car items)) (eq? (caar items) 'begin))
      (cdar items)
      items))

;; ---------------------------------------------------------------------------
;; 分析
;; ---------------------------------------------------------------------------

(define (analyze program)
  (define items (program-items program))
  (define g (cfg:build-cfg items))
  (define blocks (cfg:graph-blocks g))
  (define n (vector-length blocks))

  ;; 根只有"外部入口": 入口块 + (有间接跳转时)地址被取过的块。
  ;; 内部引用不需要当根 —— 它们在 CFG 里就是边。
  (define address-taken (if (cfg:graph-indirect? g)
                            (cfg:address-taken-paths items)
                            '()))

  (for/list ([b (in-vector blocks)] [i (in-naturals)])
    (define succ (cfg:block-successors b))
    (define next (and (< (add1 i) n) (add1 i)))
    (define fallthrough (and next (memv next succ) next))
    ;; 块里所有 label(块头 + 块内位置标记)
    (define all-labels
      (append (cfg:block-labels b)
              (for/list ([it (in-list (cfg:block-insns b))] #:when (label-form? it))
                (label-path it))))
    (define root? (or (zero? i)
                      (and (ormap (lambda (p) (member p address-taken)) all-labels) #t)))
    (block i (cfg:block-labels b) (cfg:block-insns b) succ (or fallthrough #f) root?)))

;; ---------------------------------------------------------------------------
;; 打印 / 读字面量
;; ---------------------------------------------------------------------------

(define (blocks->sexp blocks)
  (for/list ([b (in-list blocks)])
    (list 'block
          (list 'id (block-id b))
          (cons 'labels (block-labels b))
          (cons 'insns (block-insns b))
          (cons 'succ (block-succ b))
          (list 'fallthrough (block-fallthrough b))
          (list 'root? (block-root? b)))))

(define (sexp->blocks xs)
  (for/list ([x (in-list xs)])
    (unless (and (form? x) (eq? (car x) 'block))
      (error 'sexp->blocks "expected (block ...), got: ~e" x))
    (define fields (cdr x))
    (define (need k)
      (or (assoc k fields) (error 'sexp->blocks "block field ~a missing: ~e" k x)))
    (block (cadr (need 'id))
           (cdr (need 'labels))
           (cdr (need 'insns))
           (cdr (need 'succ))
           (cadr (need 'fallthrough))
           (cadr (need 'root?)))))
