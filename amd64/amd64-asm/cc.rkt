#lang racket
;;; amd64/amd64-asm/cc.rkt
;;;
;;; 条件码的唯一事实来源：
;;;
;;;   规范码 + 编码顺序   (o no b ae e ne be a s ns p np l ge le g)  -> cc-index
;;;   同义拼写            z==e, nz==ne, c==b, nc/nae==b 的同族 …
;;;   j 前缀助记符        jz -> e （例如整条 `jnz`）
;;;
;;; 编码侧（special/control.rkt）要 cc-index，前端侧（expand-pseudo）要
;;; canonical-cc / jcc-alias?。两边都从这里取，不各写一张表。
;;; amd64-help/cc.rkt 是给 help 层的转发入口（和 ranges.rkt 一样）。

(provide cc-codes
         cc-index
         canonical-cc
         jcc-alias?)

;; 规范码，顺序就是编码里的条件码编号（Jcc rel8 的 0x70+n）。
(define cc-codes
  '(o no b ae e ne be a s ns p np l ge le g))

;; 规范码 -> 同义裸拼写（x86 手册里的写法）。新增别名只改这一处。
(define cc-spellings
  '((o  o)
    (no no)
    (b  b c nae)
    (ae ae nb nc)
    (e  e z)
    (ne ne nz)
    (be be na)
    (a  a nbe)
    (s  s)
    (ns ns)
    (p  p pe)
    (np np po)
    (l  l nge)
    (ge ge nl)
    (le le ng)
    (g  g nle)))

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
