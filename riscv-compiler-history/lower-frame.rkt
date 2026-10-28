#lang racket/base

;; ============================================================
;; frame / env 形式的 stack-policy lowering
;;
;; 输入：(asm ... (frame ...) (env-ref ...) (env-set ...) (cont ...) ...)
;; 输出：
;;   asm'   : 已插入 prologue、env-ref/env-set 已变成 ld/sd
;;   frame  : frame 描述
;;   conts  : (K . code-label) 表
;;
;; 只支持 depth 0 的 (heap 0 i)。
;; depth > 0 需要词法 link（closure env），留给 heap policy。
;; ============================================================

(require racket/list
         racket/string
         "asm.rkt"
         "frame.rkt"
         "repr.rkt")

(provide lower-frame-forms
         default-frame
         frame-entry-label)

;; ------------------------------------------------------------
;; 默认 frame
;; ------------------------------------------------------------

(define (default-frame)
  (list 'frame
        (list 'base 'fp)
        (list 'link 'fp)
        (list 'slots)))

(define (sreg i)
  (string->symbol (format "s~a" i)))

;; ------------------------------------------------------------
;; 校验
;; ------------------------------------------------------------

(define (validate-frame! frame)
  (unless (eq? (frame-base frame) 'fp)
    (error 'lower-frame-forms
           "stack policy only supports (base fp), got: ~a"
           (frame-base frame)))
  (unless (eq? (frame-link frame) 'fp)
    (error 'lower-frame-forms
           "stack policy only supports (link fp), got: ~a"
           (frame-link frame)))
  (define indices (map slot-decl-index (frame-slot-decls frame)))
  (unless (= (length indices) (length (remove-duplicates indices)))
    (error 'lower-frame-forms "duplicate slot index in frame: ~a" indices))
  (for ([decl (in-list (frame-slot-decls frame))])
    (define repr (slot-decl-repr decl))
    (unless (repr-slot? repr)
      (error 'lower-frame-forms
             "frame slot ~a must be one word; got ~a; use (ptr ...)"
             (slot-decl-name decl) repr))))

(define (collect-conts asm)
  (for/fold ([conts '()]) ([item (in-list asm)]
                           #:when (cont-form? item))
    (define name (cont-name item))
    (when (assoc name conts)
      (error 'lower-frame-forms "duplicate continuation: ~a" name))
    (unless (eq? (cont-env item) 'fp)
      (error 'lower-frame-forms
             "stack policy only supports (env fp), got: ~a"
             (cont-env item)))
    (cons (cons name (cont-code item)) conts)))

;; ------------------------------------------------------------
;; env-ref / env-set -> ld / sd
;; ------------------------------------------------------------

(define (require-depth-0 loc)
  (unless (zero? (heap-depth loc))
    (error 'lower-frame-forms
           "depth > 0 needs a lexical link; only (heap 0 i) is supported: ~a"
           loc)))

(define (lower-item frame item)
  (cond
    [(env-ref? item)
     (define loc (env-ref-loc item))
     (require-depth-0 loc)
     (list (list 'ld
                 (env-ref-dst item)
                 (frame-slot-offset frame (heap-index loc))
                 (frame-base frame)))]

    [(env-set? item)
     (define loc (env-set-loc item))
     (require-depth-0 loc)
     (list (list 'sd
                 (env-set-src item)
                 (frame-slot-offset frame (heap-index loc))
                 (frame-base frame)))]

    [(or (frame-form? item) (cont-form? item))
     (error 'lower-frame-forms "declaration not removed: ~a" item)]

    [else (list item)]))

;; ------------------------------------------------------------
;; prologue
;; ------------------------------------------------------------

(define (make-prologue frame)
  (append
   (list (list 'addi 'sp 'sp (- (frame-size frame)))
         ;; 0 = old fp, 8 = ra
         (list 'sd 'fp 0 'sp)
         (list 'sd 'ra 8 'sp))
   ;; 先保存全部 callee-saved；以后再缩成实际使用集合。
   (for/list ([i (in-range 12)])
     (list 'sd (sreg i) (frame-saved-offset frame i) 'sp))
   (list (list 'addi 'fp 'sp 0))))

;; 插在第一个 label 之后：入口 label 必须指向 prologue。
(define (insert-after-first-label prologue asm)
  (define-values (before after)
    (splitf-at asm (lambda (item) (not (label? item)))))
  (cond
    [(null? after)
     (error 'lower-frame-forms "asm has no entry label")]
    [else
     (append before
             (list (car after))
             prologue
             (cdr after))]))

(define (frame-entry-label asm)
  (define label-item (findf label? asm))
  (cond
    [label-item (cadr label-item)]
    [else (error 'lower-frame-forms "asm has no entry label")]))

;; ------------------------------------------------------------
;; 主过程
;; ------------------------------------------------------------

(define (lower-frame-forms asm)
  (define frames (filter frame-form? asm))
  (when (> (length frames) 1)
    (error 'lower-frame-forms "expected at most one (frame ...)"))
  (define frame (if (null? frames) (default-frame) (car frames)))
  (validate-frame! frame)

  (define conts (collect-conts asm))
  (define structs (filter struct-form? asm))
  (define body
    (filter-not struct-form?
                (filter-not cont-form?
                            (filter-not frame-form? asm))))
  (define lowered (append-map (lambda (item) (lower-item frame item)) body))
  (define with-prologue
    (insert-after-first-label (make-prologue frame) lowered))

  (values with-prologue frame conts structs))
