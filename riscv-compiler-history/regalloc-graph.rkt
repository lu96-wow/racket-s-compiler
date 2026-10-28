#lang racket/base

;; ============================================================
;; 图着色寄存器分配
;;
;; 输入：
;;   asm + interference graph
;;
;; 输出：
;;   物理寄存器 asm
;;   vreg -> preg 映射
;;   coloring S-expression
;;
;; 当前：
;;   - 物理寄存器预着色
;;   - simplify / select
;;   - 不做 spill，分不到颜色直接报错
;; ============================================================

(require racket/list
         "asm.rkt"
         "interference.rkt")

(provide allocate-registers-graph
         physical-pool)

;; 安全颜色池：a0/ra/sp/gp/tp/x0 不作为普通 vreg 的颜色。
(define physical-pool
  '(t0 t1 t2 t3 t4 t5 t6
    s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11
    a1 a2 a3 a4 a5 a6 a7))

(define (interference->hash interference)
  (for/fold ([graph (hash)])
            ([entry (in-list (cdr interference))])
    (hash-set graph (car entry) (cdr entry))))

(define (subst-operand operand regmap)
  (cond
    [(and (symbol? operand) (assoc operand regmap))
     => cdr]
    [(list? operand)
     (for/list ([item (in-list operand)])
       (subst-operand item regmap))]
    [else operand]))

(define (subst-instruction instruction regmap)
  (cons (car instruction)
        (for/list ([operand (in-list (cdr instruction))])
          (subst-operand operand regmap))))

(define (allocate-registers-graph asm interference)
  (define original (interference->hash interference))
  (define nodes (sort (hash-keys original) symbol<?))
  (define vregs
    (sort (filter vreg? nodes) < #:key vreg-index))
  (define color-count (length physical-pool))

  ;; 简化用可变图。
  (define work (make-hash))
  (for ([(node neighbors) (in-hash original)])
    (hash-set! work node neighbors))

  (define stack '())

  (let simplify ()
    (define remaining (filter vreg? (hash-keys work)))
    (when (pair? remaining)
      (define low-degree
        (filter (lambda (vreg)
                  (< (length (hash-ref work vreg '()))
                     color-count))
                remaining))
      (define candidates (if (pair? low-degree) low-degree remaining))
      (define chosen
        (car (sort candidates < #:key vreg-index)))
      (set! stack (cons chosen stack))
      (for ([neighbor (in-list (hash-ref work chosen '()))])
        (hash-set! work neighbor
                   (remove chosen (hash-ref work neighbor '()))))
      (hash-remove! work chosen)
      (simplify)))

  ;; 预着色物理寄存器。
  (define coloring (make-hash))
  (for ([node (in-list nodes)]
        #:when (not (vreg? node)))
    (hash-set! coloring node node))

  ;; 按简化逆序选色。
  (for ([vreg (in-list stack)])
    (define forbidden
      (for/list ([neighbor (in-list (hash-ref original vreg '()))]
                 #:when (hash-has-key? coloring neighbor))
        (hash-ref coloring neighbor)))
    (define color
      (findf (lambda (candidate)
               (not (memq candidate forbidden)))
             physical-pool))
    (unless color
      (error 'allocate-registers-graph
             "register spill not implemented: ~a"
             vreg))
    (hash-set! coloring vreg color))

  (define regmap
    (for/list ([vreg (in-list vregs)])
      (cons vreg (hash-ref coloring vreg))))

  (define coloring-sexpr
    (list 'coloring
          (for/list ([node (in-list (sort (hash-keys coloring) symbol<?))])
            (cons node (hash-ref coloring node)))))

  (values
   (for/list ([item (in-list asm)])
     (if (instruction? item)
         (subst-instruction item regmap)
         item))
   regmap
   coloring-sexpr))
