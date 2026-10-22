#lang racket/base

(require racket/string
         racket/list
         "struct.rkt"
         "field.rkt")

;; ============================================================
;; 行过滤与单行解析
;; ============================================================

(define (comment-or-blank? line)
  (define s (string-trim line))
  (or (string=? s "")
      (string-prefix? s "#")))

(define (skip-line? line)
  (define s (string-trim line))
  (or (comment-or-blank? line)
      (string-prefix? s "$")))

(define (check-fixed-overlap! name fixed-fields line-number)
  (define seen (make-hash))
  (for ([ff (in-list fixed-fields)])
    (for ([bit (in-range (fixed-field-lo ff)
                         (add1 (fixed-field-hi ff)))])
      (when (hash-has-key? seen bit)
        (error 'parse-line
               "instruction ~a on line ~a assigns bit ~a more than once"
               name line-number bit))
      (hash-set! seen bit ff))))

;; 一行 → instruction-def
;;
;; 注意：这里保留源文件里的 operand token 顺序，不合并 imm12hi/imm12lo，
;; 也不按名字做任何字段推断。
(define (parse-line line line-number)
  (define tokens (string-split (string-trim line)))
  (cond
    [(null? tokens) #f]
    [else
     (define name (car tokens))
     (define rest (cdr tokens))
     (define-values (fixed-tokens operand-tokens)
       (partition looks-like-fixed-field? rest))

     (define fixed-fields
       (for/list ([token (in-list fixed-tokens)])
         (parse-fixed-field token line-number)))

     (check-fixed-overlap! name fixed-fields line-number)

     (instruction-def name operand-tokens fixed-fields)]))

;; ------------------------------------------------------------
;; $pseudo_op / $import
;; ------------------------------------------------------------

(define extension-ref-rx #rx"^([^:]+)::(.+)$")

(define (parse-extension-ref ref line-number)
  (define m (regexp-match extension-ref-rx ref))
  (unless m
    (error 'parse-extension-ref
           "invalid extension reference '~a' on line ~a"
           ref line-number))
  (values (list-ref m 1) (list-ref m 2)))

(define (parse-pseudo-line line line-number)
  (define parts (string-split (string-trim line)))
  (unless (and (>= (length parts) 3)
               (string=? (car parts) "$pseudo_op"))
    (error 'parse-pseudo-line
           "invalid pseudo_op on line ~a: ~a"
           line-number line))
  (define-values (source-extension source-instruction)
    (parse-extension-ref (list-ref parts 1) line-number))
  (define name (list-ref parts 2))
  (define instruction-text
    (string-join (cons name (drop parts 3)) " "))
  (define instruction (parse-line instruction-text line-number))
  (pseudo-def source-extension source-instruction name instruction))

(define (parse-import-line line line-number)
  (define parts (string-split (string-trim line)))
  (unless (and (= (length parts) 2)
               (string=? (car parts) "$import"))
    (error 'parse-import-line
           "invalid import on line ~a: ~a"
           line-number line))
  (define-values (source-extension instruction-name)
    (parse-extension-ref (list-ref parts 1) line-number))
  (import-def source-extension instruction-name))

(provide comment-or-blank?
         skip-line?
         parse-line
         parse-pseudo-line
         parse-import-line)
