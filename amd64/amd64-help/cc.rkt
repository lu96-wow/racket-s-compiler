#lang racket
;;; amd64-help/cc.rkt
;;;
;;; 条件码的 help 层视图。事实表在 amd64-asm/cc.rkt（编码侧也要用它算
;;; 条件码编号），这里只转发，免得两边各写一张别名表。
;;; 本模块不选 short/near 形式，也不发字节。

(require "../amd64-asm/cc.rkt")

(provide canonical-cc
         jcc-alias?)
