#lang racket/base

;; ============================================================
;; layout：label 地址和跳转偏移
;;
;; 输入：
;;   ((label main) (bge t0 t1 L0) ... (label L0) ...)
;;
;; 输出：
;;   label 表
;;   branch/jal 目标已替换成数值偏移的指令序列
;;
;; 当前所有指令固定 4 字节，label 不占空间。
;; ============================================================

(require racket/list
         "asm.rkt"
         "../riscv-help/main.rkt")

(provide layout)

(define branch-mnemonics
  '(beq bne blt bge bltu bgeu))

(define (label-address label labels)
  (define entry (assoc label labels))
  (unless entry
    (error 'layout "undefined label: ~a" label))
  (cdr entry))

(define (target-offset target pc labels)
  (cond
    [(symbol? target)
     (- (label-address target labels) pc)]
    [(exact-integer? target)
     target]
    [else
     (error 'layout "invalid jump target: ~a" target)]))

(define (resolve-instruction instruction pc labels)
  (define mnemonic (car instruction))
  (cond
    [(memq mnemonic branch-mnemonics)
     (define offset
       (target-offset (list-ref instruction 3) pc labels))
     (unless (fits-branch? offset)
       (error 'layout
              "branch offset out of range at ~a: ~a"
              pc offset))
     (list (car instruction)
           (cadr instruction)
           (caddr instruction)
           offset)]

    [(eq? mnemonic 'jal)
     (define offset
       (target-offset (list-ref instruction 2) pc labels))
     (unless (fits-jal? offset)
       (error 'layout
              "jal offset out of range at ~a: ~a"
              pc offset))
     (list 'jal (cadr instruction) offset)]

    [else instruction]))

(define (collect-labels asm)
  (define-values (labels _pc)
    (for/fold ([labels '()]
               [pc 0])
              ([item (in-list asm)])
      (cond
        [(label? item)
         (define name (cadr item))
         (when (assoc name labels)
           (error 'layout "duplicate label: ~a" name))
         (values (cons (cons name pc) labels)
                 pc)]
        [(instruction? item)
         (values labels
                 (+ pc (instruction-size item)))]
        [else
         (error 'layout "invalid asm item: ~a" item)])))
  (reverse labels))

(define (resolve-layout asm labels)
  (define-values (_pc resolved)
    (for/fold ([pc 0]
               [resolved '()])
              ([item (in-list asm)])
      (cond
        [(label? item)
         (values pc resolved)]
        [(instruction? item)
         (values (+ pc (instruction-size item))
                 (cons (resolve-instruction item pc labels)
                       resolved))]
        [else
         (error 'layout "invalid asm item: ~a" item)])))
  (reverse resolved))

(define (layout asm)
  (define labels (collect-labels asm))
  (values labels
          (resolve-layout asm labels)))
