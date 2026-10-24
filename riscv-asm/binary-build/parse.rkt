#lang racket/base

;; ============================================================
;; riscv-opcodes source parser
;;
;; Supported syntax:
;;   name operand ... fixed=value ...
;;   $import ext::name
;;   $pseudo_op ext::name new-name operand ... fixed=value ...
;;
;; Fixed field forms:
;;   lo..hi=value
;;   bit=value
;;
;; Values: decimal, 0x/0b/0o, #x/#b/#o.
;; ============================================================

(require racket/list
         racket/path
         racket/string
         "model.rkt"
         "paths.rkt")

;; ------------------------------------------------------------
;; numbers and fixed fields
;; ------------------------------------------------------------

(define (string->integer s context)
  (define (try str base) (string->number str base))
  (define value
    (cond
      [(regexp-match? #rx"^0[xX]" s) (try (substring s 2) 16)]
      [(regexp-match? #rx"^0[bB]" s) (try (substring s 2) 2)]
      [(regexp-match? #rx"^0[oO]" s) (try (substring s 2) 8)]
      [(regexp-match? #rx"^#[xX]" s) (try (substring s 2) 16)]
      [(regexp-match? #rx"^#[bB]" s) (try (substring s 2) 2)]
      [(regexp-match? #rx"^#[oO]" s) (try (substring s 2) 8)]
      [else (try s 10)]))
  (unless (exact-integer? value)
    (error 'parse-source "invalid integer '~a' in ~a" s context))
  value)

(define multi-bit-rx #rx"^([0-9]+)\\.\\.([0-9]+)=(.+)$")
(define single-bit-rx #rx"^([0-9]+)=(.+)$")

(define (looks-like-fixed-field? token)
  (or (regexp-match? multi-bit-rx token)
      (regexp-match? single-bit-rx token)))

(define (parse-fixed-field token context)
  (cond
    [(regexp-match multi-bit-rx token)
     => (lambda (m)
          (define hi (string->number (list-ref m 1)))
          (define lo (string->number (list-ref m 2)))
          (define value (string->integer (list-ref m 3) context))
          (fixed-field lo hi value))]
    [(regexp-match single-bit-rx token)
     => (lambda (m)
          (define bit (string->number (list-ref m 1)))
          (define value (string->integer (list-ref m 2) context))
          (fixed-field bit bit value))]
    [else
     (error 'parse-source "unexpected fixed field '~a' in ~a" token context)]))

(define (check-fixed-overlap! name fixed-fields context)
  (define seen (make-hash))
  (for ([ff (in-list fixed-fields)])
    (for ([bit (in-range (fixed-field-lo ff)
                         (add1 (fixed-field-hi ff)))])
      (when (hash-has-key? seen bit)
        (error 'parse-source
               "instruction ~a in ~a assigns bit ~a more than once"
               name context bit))
      (hash-set! seen bit ff))))

;; ------------------------------------------------------------
;; one instruction line
;; ------------------------------------------------------------

(define (comment-or-blank? line)
  (define s (string-trim line))
  (or (string=? s "") (string-prefix? s "#")))

(define (parse-line line context)
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
         (parse-fixed-field token context)))
     (check-fixed-overlap! name fixed-fields context)
     (instruction-def name operand-tokens fixed-fields)]))

;; ------------------------------------------------------------
;; directives
;; ------------------------------------------------------------

(define extension-ref-rx #rx"^([^:]+)::(.+)$")

(define (parse-extension-ref ref context)
  (define m (regexp-match extension-ref-rx ref))
  (unless m
    (error 'parse-source "invalid extension reference '~a' in ~a" ref context))
  (values (list-ref m 1) (list-ref m 2)))

(define (parse-pseudo-line line context)
  (define parts (string-split (string-trim line)))
  (unless (and (>= (length parts) 3)
               (string=? (car parts) "$pseudo_op"))
    (error 'parse-source "invalid $pseudo_op in ~a: ~a" context line))
  (define-values (source-extension source-instruction)
    (parse-extension-ref (list-ref parts 1) context))
  (define name (list-ref parts 2))
  (define instruction-text
    (string-join (cons name (drop parts 3)) " "))
  (define instruction (parse-line instruction-text context))
  (pseudo-def source-extension source-instruction name instruction))

(define (parse-import-line line context)
  (define parts (string-split (string-trim line)))
  (unless (and (= (length parts) 2)
               (string=? (car parts) "$import"))
    (error 'parse-source "invalid $import in ~a: ~a" context line))
  (define-values (source-extension instruction-name)
    (parse-extension-ref (list-ref parts 1) context))
  (import-def source-extension instruction-name))

;; ------------------------------------------------------------
;; one extension file
;; ------------------------------------------------------------

(define (parse-extension-file path)
  (define stem (extension-stem path))
  (with-input-from-file path
    (lambda ()
      (define standard '())
      (define pseudo '())
      (define imports '())
      (for ([line (in-lines)]
            [line-number (in-naturals 1)])
        (define trimmed (string-trim line))
        (define context (format "~a:~a" stem line-number))
        (cond
          [(comment-or-blank? trimmed) (void)]
          [(string-prefix? trimmed "$pseudo_op")
           (set! pseudo (cons (parse-pseudo-line trimmed context) pseudo))]
          [(string-prefix? trimmed "$import")
           (set! imports (cons (parse-import-line trimmed context) imports))]
          [(string-prefix? trimmed "$")
           (error 'parse-source "unknown directive in ~a: ~a" context trimmed)]
          [else
           (define result (parse-line trimmed context))
           (unless result
             (error 'parse-source "unexpected empty definition in ~a" context))
           (set! standard (cons result standard))]))
      (extension-file path
                      (reverse standard)
                      (reverse pseudo)
                      (reverse imports)))))

(provide string->integer
         looks-like-fixed-field?
         parse-fixed-field
         comment-or-blank?
         parse-line
         parse-pseudo-line
         parse-import-line
         parse-extension-file)
