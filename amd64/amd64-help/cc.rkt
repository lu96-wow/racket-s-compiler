#lang racket
;;; amd64-help/cc.rkt
;;;
;;; Condition-code names are source spelling, not encoding.  This module is
;;; the only place that maps aliases such as z/nz/c/nc to canonical x86 cc
;;; names.  It does not choose short/near forms and does not encode bytes.

(provide canonical-cc
         jcc-alias?)

(define jcc-alias
  (hash
   'je 'e   'jz 'e
   'jne 'ne 'jnz 'ne
   'jc 'b   'jnae 'b
   'jnc 'ae 'jnb 'ae 'jae 'ae
   'jbe 'be 'jna 'be
   'ja 'a   'jnbe 'a
   'js 's   'jns 'ns
   'jp 'p   'jpe 'p
   'jnp 'np 'jpo 'np
   'jl 'l   'jnge 'l
   'jge 'ge 'jnl 'ge
   'jle 'le 'jng 'le
   'jg 'g   'jnle 'g
   'jo 'o   'jno 'no
   ;; Canonical condition-code spellings are accepted directly too.
   'jb 'b   'jae 'ae 'jbe 'be 'ja 'a
   'js 's   'jns 'ns
   'jp 'p   'jnp 'np
   'jl 'l   'jge 'ge 'jle 'le 'jg 'g
   'jo 'o   'jno 'no))

(define (jcc-alias? name)
  (and (symbol? name) (hash-has-key? jcc-alias name) #t))

(define (canonical-cc name)
  (cond
    [(and (symbol? name) (hash-ref jcc-alias name #f))
     => values]
    [else #f]))
