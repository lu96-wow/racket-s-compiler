#lang racket
;;; amd64-help/cc.rkt
;;;
;;; Condition-code names are source spelling, not encoding.  This module is
;;; the only place that maps aliases such as z/nz/c/nc to canonical x86 cc
;;; names.  It does not choose short/near forms and does not encode bytes.

(provide canonical-cc
         jcc-alias?)

;; 别名表: 源写法 -> 规范条件码。一行一个规范码, 别名按 x86 手册列全,
;; 不重复登记(重复的 key 在 hash 里会被静默丢掉, 只会误导读者)。
(define jcc-alias
  (hash
   'je 'e   'jz 'e
   'jne 'ne 'jnz 'ne
   'jb 'b   'jc 'b  'jnae 'b
   'jae 'ae 'jnb 'ae 'jnc 'ae
   'jbe 'be 'jna 'be
   'ja 'a   'jnbe 'a
   'js 's
   'jns 'ns
   'jp 'p   'jpe 'p
   'jnp 'np 'jpo 'np
   'jl 'l   'jnge 'l
   'jge 'ge 'jnl 'ge
   'jle 'le 'jng 'le
   'jg 'g   'jnle 'g
   'jo 'o
   'jno 'no))

(define (jcc-alias? name)
  (and (symbol? name) (hash-has-key? jcc-alias name) #t))

(define (canonical-cc name)
  (cond
    [(and (symbol? name) (hash-ref jcc-alias name #f))
     => values]
    [else #f]))
