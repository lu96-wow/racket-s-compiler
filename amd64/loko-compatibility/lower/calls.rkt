#lang racket
;;; amd64/loko-compatibility/lower/calls.rkt
;;;
;;; 调用点的 save/restore 注记。
;;;
;;; Loko 的 codegen 在调用前后发出：
;;;
;;;   (%comment save-live-registers)
;;;   ... call ...
;;;   (%comment liveness-information)
;;;   (%comment restore-live-registers)
;;;
;;; 本层把它们展开成显式的伪寄存器搬运：
;;;
;;;   (mov (reg fresh) (reg live)) ...
;;;   ... call ...
;;;   (mov (reg live) (reg fresh)) ...
;;;
;;; fresh 是新的伪寄存器，只在这个 save/restore 范围内 live。这样：
;;;   - 原始值可以在调用中被打坏；
;;;   - 保存副本成为跨调用 live 的值，后续分配/溢出层只需要处理它。
;;;
;;; 注意：本层只展开注记，不决定 fresh 最终放在物理寄存器还是栈上。
;;; 如果保存副本太多，分配器仍会报 uncolored；真正的 spill 属于下一层。

(require "../../amd64-asm/sexp.rkt"
         (only-in "../../compiler/item.rkt" make-label)
         "../../compiler/analyze/analyze.rkt"
         "liveness.rkt"
         "pseudo.rkt")

(provide (struct-out call-save-result)
         expand-call-saves
         call-crossing-pseudos
         save-comment?
         restore-comment?
         liveness-comment?)

(define (marker-comment? x name)
  (and (form? x)
       (eq? (car x) 'comment)
       (pair? (cdr x))
       (eq? (cadr x) name)))

(define (save-comment? x) (marker-comment? x 'save-live-registers))
(define (restore-comment? x) (marker-comment? x 'restore-live-registers))
(define (liveness-comment? x) (marker-comment? x 'liveness-information))

(define (call-head? h)
  (memq h '(call call-near call-indirect syscall)))

(define (call-item? x)
  (and (form? x) (call-head? (car x))))

(define (as-program x)
  (if (program? x) x (analyze x)))

;; 所有跨调用仍 live 的伪寄存器。
(define (call-crossing-pseudos lv program-or-items)
  (define prog (as-program program-or-items))
  (define blocks (list->vector (program-blocks prog)))
  (define out (make-hash))
  (for ([i (in-range (vector-length blocks))])
    (define items (block-items (vector-ref blocks i)))
    (for ([j (in-range (length items))])
      (define item (list-ref items j))
      (when (call-item? item)
        (for ([p (in-list (live-out-after lv i j))])
          (hash-set! out p #t)))))
  (sort (hash-keys out) <))

(define (problem kind . detail)
  (cons 'problem (cons kind detail)))

;; items 是 program-items 列表。
;; 返回 call-save-result：展开后的 items、fresh 数量、problems。
(struct call-save-result (items fresh-count problems) #:transparent)

;; 返回两类 entry：块头 label 是直接的 (label ...)，块内 item 是
;; (item live-out)。
(define (items-with-live-out program lv)
  ;; 用 analyze 的块顺序重建一个扁平的 item 序列。
  ;; 块头的多个 label 合并成一个 (label 名字 ...)；语义不变。
  (define blocks (list->vector (program-blocks program)))
  (define out '())
  (for ([i (in-range (vector-length blocks))])
    (define block (vector-ref blocks i))
    (define head (block-head block))
    (when (pair? head)
      (set! out (cons (make-label (append* head)) out)))
    (define items (block-items block))
    (for ([j (in-range (length items))])
      (set! out (cons (list (list-ref items j) (live-out-after lv i j)) out))))
  ;; 每个元素现在是 (item live-out) 或 (label ...)。统一成 pair。
  (reverse out))

(define (expand-call-saves items)
  (define program (analyze items))
  (define lv (compute-liveness program))
  (define pseudos (liveness-pseudos lv))
  (define start-fresh (if (null? pseudos) 0 (add1 (last pseudos))))

  (define next-fresh start-fresh)
  (define stack '())
  (define problems '())
  (define out '())

  (define (emit! x) (set! out (cons x out)))
  (define (new-fresh!)
    (define n next-fresh)
    (set! next-fresh (add1 next-fresh))
    n)

  (for ([entry (in-list (items-with-live-out program lv))])
    (cond
      [(and (pair? entry) (eq? (car entry) 'label))
       (emit! entry)]
      [else
       (define item (car entry))
       (define live-out (cadr entry))
       (cond
         [(save-comment? item)
          (define saved
            (for/list ([p (in-list live-out)])
              (cons p (new-fresh!))))
          (for ([p/f (in-list saved)])
            (emit! (list 'mov
                         (make-pseudo-register (cdr p/f))
                         (make-pseudo-register (car p/f)))))
          (set! stack (cons saved stack))]

         [(restore-comment? item)
          (cond
            [(null? stack)
             (set! problems
                   (cons (problem 'restore-without-save item) problems))]
            [else
             (define saved (car stack))
             (set! stack (cdr stack))
             (for ([p/f (in-list saved)])
               (emit! (list 'mov
                            (make-pseudo-register (car p/f))
                            (make-pseudo-register (cdr p/f)))))])]

         [else (emit! item)])]))

  (when (pair? stack)
    (set! problems
          (cons (problem 'save-without-restore (length stack)) problems)))

  (call-save-result (reverse out)
                    (- next-fresh start-fresh)
                    (reverse problems)))
