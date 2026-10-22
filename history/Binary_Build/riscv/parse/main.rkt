#lang racket

;; ============================================================
;; parse/ 模块聚合入口
;; ============================================================

(require "struct.rkt"
         "field.rkt"
         "line.rkt"
         "file.rkt")

(provide
 ;; structs
 fixed-field fixed-field? fixed-field-high fixed-field-low fixed-field-value
 instruction-def instruction-def? instruction-def-name
 instruction-def-operands instruction-def-fixed-fields
 extension-source extension-source? extension-source-path extension-source-type-sym
 extension-defs extension-defs? extension-defs-source extension-defs-defs
 ;; predicates
 skip-line?
 hi/lo-suffix?
 ;; line parse
 parse-line
 ;; fixed field parse
 parse-fixed-field
 string->integer
 looks-like-fixed-field?
 looks-like-multi-bit?
 looks-like-single-bit?
 ;; hi/lo
 strip-hi/lo
 ;; file
 parse-file
 make-extension-source
 )
