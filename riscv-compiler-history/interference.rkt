#lang racket/base

;; ============================================================
;; interference graph
;;
;; 输入：CFG + liveness
;; 输出：
;;   (interference
;;     (v0 v1 ra)
;;     (v1 v0 ra)
;;     ...)
;;
;; 规则：
;;   对每条定义 d，把 d 与指令 live-out 中的每个寄存器连边。
;; ============================================================

(require racket/list
         "asm.rkt"
         "sets.rkt"
         "cfg.rkt"
         "liveness.rkt")

(provide build-interference
         interference?
         interference-nodes
         interference-neighbors)

(define (interference? value)
  (and (list? value)
       (pair? value)
       (eq? (car value) 'interference)))

(define (interference-nodes interference)
  (map car (cdr interference)))

(define (interference-neighbors interference node)
  (cond
    [(assoc node (cdr interference)) => cdr]
    [else '()]))

(define (operand-vregs operand)
  (cond
    [(vreg? operand) (list operand)]
    [(list? operand) (append-map operand-vregs operand)]
    [else '()]))

(define (instruction-vregs instruction)
  (append-map operand-vregs (cdr instruction)))

(define (collect-vregs cfg)
  (sort-set
   (append-map
    (lambda (block)
      (append-map instruction-vregs
                  (block-insns block)))
    (cfg-blocks cfg))))

(define (add-edge! graph a b)
  (unless (eq? a b)
    (hash-set! graph a
               (sort-set (cons b (hash-ref graph a '()))))
    (hash-set! graph b
               (sort-set (cons a (hash-ref graph b '()))))))

(define (build-interference cfg liveness)
  (define graph (make-hash))

  ;; 所有 vreg 都要出现在图里，即使没有边。
  (for ([vreg (in-list (collect-vregs cfg))])
    (hash-set! graph vreg '()))

  (for ([block (in-list (cfg-blocks cfg))])
    (define block-id* (block-id block))
    (define live (liveness-out liveness block-id*))
    (for ([instruction (in-list (reverse (block-insns block)))])
      (define-values (use def)
        (instruction-use-def instruction))
      (for ([defined (in-list def)])
        (for ([alive (in-list live)])
          (add-edge! graph defined alive)))
      (set! live
            (set-union use
                       (set-subtract live def)))))

  (cons 'interference
        (for/list ([node (in-list (sort (hash-keys graph) symbol<?))])
          (cons node (hash-ref graph node '())))))
