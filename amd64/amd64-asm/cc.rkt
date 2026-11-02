#lang racket
;;; amd64/amd64-asm/cc.rkt
;;;
;;; 条件码的唯一事实来源：
;;;
;;;   固定表 cc-table.rkt  规范码 + 同义拼写
;;;   派生别名             j 前缀助记符 jz -> e
;;;   编码顺序             cc-codes 的列表下标 -> cc-index
;;;
;;; 编码侧（special/control.rkt）要 cc-index，前端侧（expand-pseudo）要
;;; canonical-cc / jcc-alias?。两边都从这里取，不各写一张表。
;;; amd64-help/cc.rkt 是给 help 层的转发入口（和 ranges.rkt 一样）。

(require "cc-table.rkt")

(provide cc-codes
         cc-index
         canonical-cc
         jcc-alias?)

(define (j-prefixed spelling)
  (string->symbol (string-append "j" (symbol->string spelling))))

;; 任何拼写（z / jz / e / je）-> 裸规范码
(define cc-alias
  (for*/hash ([row (in-list cc-spellings)]
              [spelling (in-list (cdr row))]
              [form (in-list (list spelling (j-prefixed spelling)))])
    (values form (car row))))

(define (canonical-cc name)
  (and (symbol? name) (hash-ref cc-alias name #f)))

(define (jcc-alias? name)
  (and (canonical-cc name)
       (let ([s (symbol->string name)])
         (and (> (string-length s) 1) (char=? (string-ref s 0) #\j)))
       #t))

(define (cc-index cc)
  (unless (memq cc cc-codes)
    (error 'cc-index "unknown condition code: ~e (canonical codes: ~a)"
           cc cc-codes))
  (list-index cc-codes cc))

(define (list-index xs x)
  (let loop ([xs xs] [i 0])
    (cond [(null? xs) #f]
          [(eq? (car xs) x) i]
          [else (loop (cdr xs) (add1 i))])))
