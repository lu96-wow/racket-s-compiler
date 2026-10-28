#lang racket/base

;; ============================================================
;; call / tailcall / return 的 stack-policy lowering
;;
;; 前置条件：
;;   - 已经过寄存器分配，args/values 都是物理寄存器；
;;   - (cont K (code L) (env fp)) 已经被收集成 (K . L) 表。
;;
;; 产物：
;;   (call f (args a0 a1) (cont K0))
;;     -> 参数并行移动 + (jal ra f) + (jal x0 Lafter)
;;   (tailcall f (args ...))
;;     -> 参数并行移动 + epilogue + (jal x0 f)
;;   (return (a0))
;;     -> 返回值移动 + epilogue + (jalr x0 ra 0)
;;
;; 这里只实现 one-shot 续延：
;;   ra  = 续延的 code
;;   fp  = 续延的 env（栈帧）
;; heap 续延以后替换这一层，不改上面的形式。
;; ============================================================

(require racket/list
         racket/string
         "asm.rkt"
         "frame.rkt")

(provide lower-calls
         parallel-move)

(define argument-registers
  '(a0 a1 a2 a3 a4 a5 a6 a7))

(define (sreg i)
  (string->symbol (format "s~a" i)))

;; ------------------------------------------------------------
;; 并行移动
;;
;; moves : ((dest . src) ...)
;; 用 tp 打破环。tp 不在物理寄存器池里。
;; ------------------------------------------------------------

(define (parallel-move moves)
  (define (loop moves acc)
    (define real
      (filter (lambda (move)
                (not (eq? (car move) (cdr move))))
              moves))
    (cond
      [(null? real) (reverse acc)]
      [else
       (define sources (map cdr real))
       (define ready
         (findf (lambda (move)
                  (not (memq (car move) sources)))
                real))
       (cond
         [ready
          (loop (remove ready real)
                (cons (list 'addi (car ready) (cdr ready) 0)
                      acc))]
         [else
          ;; 环：把当前 src 存到 tp，再把所有以它为源的 move 改成 tp。
          (define move (car real))
          (define src (cdr move))
          (define saved
            (for/list ([item (in-list real)])
              (if (eq? (cdr item) src)
                  (cons (car item) 'tp)
                  item)))
          (loop saved
                (cons (list 'addi 'tp src 0) acc))])]))
  (loop moves '()))

;; ------------------------------------------------------------
;; epilogue
;; ------------------------------------------------------------

(define (epilogue frame)
  (append
   (list (list 'ld 'ra 8 'fp))
   (for/list ([i (in-range 12)])
     (list 'ld (sreg i) (frame-saved-offset frame i) 'fp))
   (list (list 'ld 'fp 0 'fp)
         (list 'addi 'sp 'sp (frame-size frame)))))

;; ------------------------------------------------------------
;; 跳转
;; ------------------------------------------------------------

(define (direct-or-indirect target ra-or-zero)
  (cond
    [(physical-register? target)
     (list 'jalr ra-or-zero target 0)]
    [else
     (list 'jal ra-or-zero target)]))

;; 间接调用时，target 寄存器可能被参数移动覆盖。
;; 先把它存到 gp（保留寄存器，不参与分配）。
(define (protect-target target moves)
  (if (and (physical-register? target)
           (or (eq? target 'tp)
               (memq target (map car moves))))
      (values 'gp
              (cons (list 'addi 'gp target 0) '()))
      (values target '())))

;; tailcall 的 epilogue 会写 ra/fp/sp/s0..s11。
;; 间接目标如果落在这些寄存器里，必须在 epilogue 之前搬到 gp。
(define (epilogue-clobbers? reg)
  (or (memq reg '(ra fp sp tp))
      (for/or ([i (in-range 12)])
        (eq? reg (sreg i)))))

(define (protect-tail-target target moves)
  (cond
    [(not (physical-register? target))
     (values target '())]
    [(or (eq? target 'tp)
         (epilogue-clobbers? target)
         (memq target (map car moves)))
     (values 'gp
             (list (list 'addi 'gp target 0)))]
    [else
     (values target '())]))

;; ------------------------------------------------------------
;; 单条 lowering
;; ------------------------------------------------------------

(define (require-physical who regs)
  (for ([reg (in-list regs)])
    (unless (physical-register? reg)
      (error who
             "expected physical register after coloring, got: ~a"
             reg))))

(define (cont-code conts name)
  (cond
    [(assoc name conts) => cdr]
    [else
     (error 'lower-calls "unknown continuation: ~a" name)]))

(define (lower-call frame conts item)
  (define args (call-args item))
  (define target (call-target item))
  (define code (cont-code conts (call-cont item)))
  (when (> (length args) (length argument-registers))
    (error 'lower-calls
           "more than ~a arguments not supported: ~a"
           (length argument-registers) args))
  (require-physical 'lower-calls args)

  (define moves
    (for/list ([src (in-list args)]
               [dst (in-list argument-registers)])
      (cons dst src)))
  (define-values (safe-target pre)
    (protect-target target moves))

  (append pre
          (parallel-move moves)
          (list (direct-or-indirect safe-target 'ra))
          ;; callee 返回到这里，再跳到续延代码。
          ;; 如果 Lafter 紧跟在后面，branch-opt 会删掉这条跳转。
          (list (list 'jal 'x0 code))))

(define (lower-tailcall frame item)
  (define args (tailcall-args item))
  (define target (tailcall-target item))
  (when (> (length args) (length argument-registers))
    (error 'lower-calls
           "more than ~a tailcall arguments not supported: ~a"
           (length argument-registers) args))
  (require-physical 'lower-calls args)

  (define moves
    (for/list ([src (in-list args)]
               [dst (in-list argument-registers)])
      (cons dst src)))
  (define-values (safe-target pre)
    (protect-tail-target target moves))

  (append pre
          (parallel-move moves)
          (epilogue frame)
          (list (direct-or-indirect safe-target 'x0))))

(define (lower-return frame item)
  (define values (cadr item))
  (when (> (length values) (length argument-registers))
    (error 'lower-calls
           "more than ~a return values not supported: ~a"
           (length argument-registers) values))
  (require-physical 'lower-calls values)

  (define moves
    (for/list ([src (in-list values)]
               [dst (in-list argument-registers)])
      (cons dst src)))

  (append (parallel-move moves)
          (epilogue frame)
          (list (list 'jalr 'x0 'ra 0))))

(define (lower-item frame conts item)
  (cond
    [(call-form? item) (lower-call frame conts item)]
    [(tailcall-form? item) (lower-tailcall frame item)]
    [(return-form? item) (lower-return frame item)]
    [(or (frame-form? item) (cont-form? item) (env-ref? item) (env-set? item))
     (error 'lower-calls "form not lowered yet: ~a" item)]
    [else (list item)]))

(define (lower-calls asm frame conts)
  (append-map (lambda (item) (lower-item frame conts item)) asm))
