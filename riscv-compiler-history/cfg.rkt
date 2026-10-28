#lang racket/base

;; ============================================================
;; CFG：basic block + 后继
;;
;; 输入：
;;   ((label main) (addi v0 x0 0) ... (bge ... L0) ...)
;;
;; 输出：
;;   (cfg
;;     (blocks
;;       (block B0 (labels main) (insns ...))
;;       ...)
;;     (label-map ((main . B0) ...))
;;     (succ ((B0 . (B2 B1)) ...)))
;;
;; 规则：
;;   - 函数入口、label、terminator 后第一条指令是 leader
;;   - label 归属下一个 block
;;   - 当前所有指令固定 4 字节
;; ============================================================

(require racket/list
         "asm.rkt"
         "frame.rkt")

(provide build-cfg
         cfg?
         cfg-blocks
         cfg-label-map
         cfg-succ
         cfg-block
         cfg-entry
         cfg-succ-of
         cfg-target-block
         block?
         block-id
         block-labels
         block-insns)

;; ------------------------------------------------------------
;; 数据访问
;; ------------------------------------------------------------

(define (cfg? value)
  (and (list? value)
       (= (length value) 4)
       (eq? (car value) 'cfg)
       (let ([blocks (cadr value)]
             [labels (caddr value)]
             [succ (cadddr value)])
         (and (list? blocks)
              (eq? (car blocks) 'blocks)
              (list? labels)
              (eq? (car labels) 'label-map)
              (list? succ)
              (eq? (car succ) 'succ)))))

(define (cfg-blocks cfg)
  (cadr (cadr cfg)))

(define (cfg-label-map cfg)
  (cadr (caddr cfg)))

(define (cfg-succ cfg)
  (cadr (cadddr cfg)))

(define (block? value)
  (and (list? value)
       (= (length value) 4)
       (eq? (car value) 'block)
       (symbol? (cadr value))
       (let ([labels (caddr value)]
             [insns (cadddr value)])
         (and (list? labels)
              (eq? (car labels) 'labels)
              (list? insns)
              (eq? (car insns) 'insns)))))

(define (block-id block)
  (cadr block))

(define (block-labels block)
  (cadr (caddr block)))

(define (block-insns block)
  (cadr (cadddr block)))

(define (cfg-block cfg id)
  (or (findf (lambda (block) (eq? (block-id block) id))
             (cfg-blocks cfg))
      (error 'cfg-block "unknown block: ~a" id)))

(define (cfg-succ-of cfg id)
  (cond
    [(assoc id (cfg-succ cfg)) => cdr]
    [else '()]))

(define (cfg-target-block cfg label)
  (cond
    [(assoc label (cfg-label-map cfg)) => cdr]
    [else (error 'cfg-target-block "undefined label: ~a" label)]))

(define (cfg-entry cfg)
  (define blocks (cfg-blocks cfg))
  (unless (pair? blocks)
    (error 'cfg-entry "empty CFG"))
  (block-id (car blocks)))

;; ------------------------------------------------------------
;; 建块
;; ------------------------------------------------------------

(define (close-block blocks current pending next-id)
  (define id (string->symbol (format "B~a" next-id)))
  (values
   (cons (list 'block
               id
               (list 'labels (reverse pending))
               (list 'insns (reverse current)))
         blocks)
   '()
   '()
   (add1 next-id)))

(define (build-blocks asm)
  (define-values (blocks-rev current pending next-id)
    (for/fold ([blocks '()]
               [current '()]
               [pending '()]
               [next-id 0])
              ([item (in-list asm)])
      (cond
        [(label? item)
         (define name (cadr item))
         (cond
           [(pair? current)
            (define-values (blocks* _current _pending next-id*)
              (close-block blocks current pending next-id))
            (values blocks* '() (list name) next-id*)]
           [else
            (values blocks current (cons name pending) next-id)])]

        [(instruction? item)
         (define current* (cons item current))
         (if (terminator? item)
             (close-block blocks current* pending next-id)
             (values blocks current* pending next-id))]

        [else
         (error 'build-cfg "invalid asm item: ~a" item)])))

  (define-values (blocks* _current _pending _next)
    (if (or (pair? current) (pair? pending))
        (close-block blocks-rev current pending next-id)
        (values blocks-rev current pending next-id)))

  (reverse blocks*))

;; ------------------------------------------------------------
;; label 表 / 后继
;; ------------------------------------------------------------

(define (build-label-map blocks)
  (reverse
   (for*/fold ([acc '()])
              ([block (in-list blocks)]
               [label (in-list (block-labels block))])
     (when (assoc label acc)
       (error 'build-cfg "duplicate label: ~a" label))
     (cons (cons label (block-id block)) acc))))

(define (build-next-map blocks)
  (for/fold ([acc '()])
            ([block (in-list blocks)]
             [next (in-list (cdr blocks))])
    (cons (cons (block-id block) (block-id next)) acc)))

(define (unique-in-order values)
  (remove-duplicates values eq?))

(define (block-successors block next-map label-map)
  (define id (block-id block))
  (define next (and (assoc id next-map) (cdr (assoc id next-map))))
  (define insns (block-insns block))

  (define (fallthrough)
    (if next (list next) '()))

  (define (target label)
    (cond
      [(assoc label label-map) => cdr]
      [else (error 'build-cfg "undefined target label: ~a" label)]))

  ;; 块内任意位置的 call 都要把 callee 当作可达后继。
  (define call-succ
    (for/list ([insn (in-list insns)]
               #:when (call-form? insn))
      (define t (call-target insn))
      (cond
        [(or (vreg? t) (physical-register? t)) #f]
        [else (target t)])))

  (cond
    [(null? insns)
     (unique-in-order (append (fallthrough) (filter values call-succ)))]

    [else
     (define last-insn (last insns))
     (unique-in-order
      (append
       (filter values call-succ)
       (cond
        [(return-form? last-insn)
         '()]

        [(tailcall-form? last-insn)
         (define target* (tailcall-target last-insn))
         (if (or (vreg? target*) (physical-register? target*))
             '()
             (list (target target*)))]

        [(branch-instruction? last-insn)
         (append (list (target (list-ref last-insn 3)))
                 (fallthrough))]

        [(unconditional-jump? last-insn)
         (list (target (list-ref last-insn 2)))]

        [(return-instruction? last-insn)
         '()]

        [(jal-instruction? last-insn)
         ;; 函数调用：目标 + fallthrough
         (append (list (target (list-ref last-insn 2)))
                 (fallthrough))]

        [(jalr-instruction? last-insn)
         (fallthrough)]

        [else
         (fallthrough)])))]))

(define (build-cfg asm)
  (define blocks (build-blocks asm))
  (define label-map (build-label-map blocks))
  (define next-map (build-next-map blocks))
  (define succ
    (for/list ([block (in-list blocks)])
      (cons (block-id block)
            (block-successors block next-map label-map))))
  (list 'cfg
        (list 'blocks blocks)
        (list 'label-map label-map)
        (list 'succ succ)))
