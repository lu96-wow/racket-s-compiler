#lang racket
;;; ir/liveness.rkt
;;;
;;; virtual IR 的 def-use 和 liveness。只做集合运算，不改 IR。
;;;
;;; 它服务于分配：
;;;   - 每个 block 的 live-in / live-out；
;;;   - 每条 op / term 的 defs / uses / live-before / live-after。
;;;
;;; 不做：
;;;   - 寄存器分配；
;;;   - spill；
;;;   - 指令选择；
;;;   - 布局。

(require racket/list
         "../core/sexp.rkt"
         "shape.rkt"
         "cfg.rkt")

(provide (struct-out instruction)
         (struct-out liveness)
         op-def-use
         term-def-use
         analyze-liveness
         set-union
         set-minus
         set-empty?
         set->list
         set-size)

;; form：op 或 term。
(struct instruction (form defs uses live-before live-after) #:mutable #:transparent)

(struct liveness
  (live-in       ; hash block -> (setof vreg)
   live-out      ; hash block -> (setof vreg)
   instructions) ; hash block -> (listof instruction)，程序顺序
  #:transparent)

;; ---------------------------------------------------------------------------
;; def-use
;; ---------------------------------------------------------------------------

;; -> (values (listof vreg) (listof vreg))
(define (op-def-use op)
  (unless (and (form? op) (symbol? (car op)))
    (error 'liveness "malformed op: ~e" op))
  (define head (car op))
  (case head
    [(const)
     (values (list (cadr op)) '())]

    [(copy)
     (values (list (cadr op)) (vreg-operands (list (caddr op))))]

    [(load)
     (values (list (cadr op)) (vreg-operands (list (caddr op))))]

    [(store)
     (values '() (vreg-operands (list (cadr op) (cadddr op))))]

    [(addr)
     (values (list (cadr op)) (vreg-operands (list (caddr op))))]

    [(call)
     (values (list (cadr op)) (vreg-operands (cdddr op)))]

    [(asm)
     (define table
       (for/hash ([clause (in-list (cdr op))])
         (values (car clause) (cdr clause))))
     (define ins (hash-ref table 'inputs '()))
     (define outs (hash-ref table 'outputs '()))
     (values (for/list ([entry (in-list outs)]) (car entry))
             (for/list ([entry (in-list ins)]) (car entry)))]

    [else
     (if (binary-op-head? head)
         (values (list (cadr op))
                 (vreg-operands (list (caddr op) (cadddr op))))
         (error 'liveness "unknown virtual op: ~e" op))]))

(define (term-def-use term)
  (unless (term-form? term)
    (error 'liveness "malformed term: ~e" term))
  (match (cadr term)
    [(list 'jump _) (values '() '())]
    [(list 'branch (list _ a b) _ _)
     (values '() (vreg-operands (list a b)))]
    [(list 'return operands ...)
     (values '() (vreg-operands operands))]
    [(list 'trap) (values '() '())]))

(define (form-def-use form)
  (cond
    [(and (form? form) (eq? (car form) 'term)) (term-def-use form)]
    [else (op-def-use form)]))

(define (vreg-operands operands)
  (filter vreg? operands))

;; ---------------------------------------------------------------------------
;; liveness
;; ---------------------------------------------------------------------------

(define (analyze-liveness func)
  (unless (and (tagged? func 'func) (>= (length func) 2))
    (error 'liveness "expected a func: ~e" func))
  (define cfg (build-cfg func))
  (define blocks (cfg-blocks cfg))
  (define successors (cfg-successors cfg))
  (define block-forms
    (for/fold ([h (make-hash)])
              ([form (in-list (filter (lambda (x)
                                        (and (form? x) (eq? (car x) 'block)))
                                      (cddr func)))])
      (hash-set! h (cadr form) form)
      h))

  (define instructions (make-hash))
  (for ([block (in-list blocks)])
    (define form (hash-ref block-forms block))
    (define forms (cddr form))
    (hash-set! instructions block
               (for/list ([form (in-list forms)])
                 (define-values (defs uses) (form-def-use form))
                 (instruction form defs uses
                              (make-set '()) (make-set '())))))

  ;; 每个 block 的 upward-exposed use / def。
  ;; use 只包含在本 block 第一次定义之前被使用的 vreg。
  (define block-uses (make-hash))
  (define block-defs (make-hash))
  (for ([block (in-list blocks)])
    (define defined (make-hash))
    (define use-set (make-hash))
    (for ([ins (in-list (hash-ref instructions block))])
      (for ([vreg (in-list (instruction-uses ins))])
        (unless (hash-has-key? defined vreg)
          (hash-set! use-set vreg #t)))
      (for ([vreg (in-list (instruction-defs ins))])
        (hash-set! defined vreg #t)))
    (hash-set! block-uses block use-set)
    (hash-set! block-defs block
               (for/fold ([acc (make-set '())])
                         ([ins (in-list (hash-ref instructions block))])
                 (set-union acc (make-set (instruction-defs ins))))))

  (define live-in (make-hash))
  (define live-out (make-hash))
  (for ([block (in-list blocks)])
    (hash-set! live-in block (make-set '()))
    (hash-set! live-out block (make-set '())))

  (let loop ()
    (define changed? #f)
    (for ([block (in-list blocks)])
      (define out
        (for/fold ([acc (make-set '())])
                  ([succ (in-list (hash-ref successors block '()))])
          (set-union acc (hash-ref live-in succ))))
      (define in
        (set-union (hash-ref block-uses block)
                   (set-minus out (hash-ref block-defs block))))
      (unless (set=? out (hash-ref live-out block))
        (set! changed? #t)
        (hash-set! live-out block out))
      (unless (set=? in (hash-ref live-in block))
        (set! changed? #t)
        (hash-set! live-in block in)))
    (when changed? (loop)))

  ;; 反向扫描，填每条 instruction 的 live-before / live-after。
  (for ([block (in-list blocks)])
    (define ins-list (hash-ref instructions block))
    (define out (hash-ref live-out block))
    (for/fold ([after out] [acc '()])
              ([ins (in-list (reverse ins-list))])
      (define defs (make-set (instruction-defs ins)))
      (define uses (make-set (instruction-uses ins)))
      (define before (set-union uses (set-minus after defs)))
      (set-instruction-live-before! ins before)
      (set-instruction-live-after! ins after)
      (values before (cons ins acc))))

  (liveness live-in live-out instructions))

;; ---------------------------------------------------------------------------
;; sets
;; ---------------------------------------------------------------------------

(define (make-set vs)
  (for/fold ([h (hash)]) ([v (in-list vs)])
    (hash-set h v #t)))

(define (set-union a b)
  (for/fold ([h a]) ([(v _) (in-hash b)])
    (hash-set h v #t)))

(define (set-minus a b)
  (for/fold ([h a]) ([(v _) (in-hash b)])
    (hash-remove h v)))

(define (set-empty? s)
  (zero? (hash-count s)))

(define (set->list s)
  (sort (hash-keys s)
        (lambda (a b)
          (string<? (format "~a" a) (format "~a" b)))))

(define (set-size s)
  (hash-count s))

(define (set=? a b)
  (and (= (hash-count a) (hash-count b))
       (for/and ([(v _) (in-hash a)])
         (hash-has-key? b v))))
