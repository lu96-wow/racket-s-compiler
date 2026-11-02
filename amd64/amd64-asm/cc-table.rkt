#lang racket
;;; amd64/amd64-asm/cc-table.rkt
;;;
;;; 条件码固定表。只放数据，不放编码/别名策略。
;;;
;;;   cc-codes     规范码，顺序就是 Jcc rel8 的 cc-index
;;;   cc-spellings 规范码 -> 同义裸拼写（j 前缀由 cc.rkt 派生）

(provide cc-codes
         cc-spellings)

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
