#lang racket/base

;; ============================================================
;; Metadata queries and canonical signatures
;;
;; Encoding identity deliberately excludes:
;;   - name / extension / asm
;;   - provenance (standard/import/pseudo)
;;   - size (implied by width)
;;
;; Fixed fields are normalized to the actual fixed word produced by
;; bitwise-ior, so different orderings/splittings compare equal.
;; Raw/rebuilt bindings are compared as order-insensitive sets because
;; make-instruction ORs fields together.
;; ============================================================

(require racket/list
         racket/string
         "struct.rkt")

;; ------------------------------------------------------------
;; basic lookup/accessors
;; ------------------------------------------------------------

(define (find-instruction-info infos name)
  (unless (symbol? name)
    (raise-argument-error 'find-instruction-info "symbol?" name))
  (for/first ([info (in-list infos)]
              #:when (eq? (instruction-info-name info) name))
    info))

(define (info-param-count info)
  (length (instruction-info-operands info)))

(define (info-raw-param-count info)
  (length (instruction-info-raw-operands info)))

(define (info-operands info) (instruction-info-operands info))
(define (info-raw-operands info) (instruction-info-raw-operands info))
(define (info-asm-format info) (instruction-info-asm info))
(define (info-width info) (instruction-info-width info))
(define (info-size info) (instruction-info-size info))
(define (info-fixed-fields info) (instruction-info-fixed-fields info))
(define (info-aliases info) (instruction-info-aliases info))
(define (info-origin info) (instruction-info-origin info))
(define (info-raw-bindings info) (instruction-info-raw-bindings info))
(define (info-rebuilt-bindings info) (instruction-info-rebuilt-bindings info))

(define (info-kind info)
  (instruction-origin-kind (info-origin info)))
(define (info-source-extension info)
  (instruction-origin-source-extension (info-origin info)))
(define (info-source-instruction info)
  (instruction-origin-source-instruction (info-origin info)))

;; ------------------------------------------------------------
;; canonical forms
;; ------------------------------------------------------------

(define (fixed-fields->word fixed-fields)
  (for/fold ([word 0]) ([ff (in-list fixed-fields)])
    (define lo (list-ref ff 0))
    (define hi (list-ref ff 1))
    (define value (list-ref ff 2))
    ;; bit-range-fixed validates that value fits [lo, hi] and the
    ;; generated make-instruction ORs all fixed fields together.
    (bitwise-ior word (arithmetic-shift value lo))))

(define (string-pair<? a b)
  (or (string<? (car a) (car b))
      (and (string=? (car a) (car b))
           (string<? (cadr a) (cadr b)))))

(define (canonical-pairs pairs)
  (sort
   (remove-duplicates
    (for/list ([p (in-list pairs)])
      (list (car p) (cadr p)))
    equal?)
   string-pair<?))

(define (instruction-info-encoding-signature info)
  (list (info-width info)
        (fixed-fields->word (info-fixed-fields info))
        (canonical-pairs (info-raw-bindings info))
        (canonical-pairs (info-rebuilt-bindings info))))

(define (instruction-info-interface-signature info)
  (list (info-operands info)
        (info-raw-operands info)
        (canonical-pairs (info-aliases info))))

(define (instruction-info-provenance-signature info)
  (let ([o (info-origin info)])
    (list (instruction-origin-kind o)
          (instruction-origin-source-extension o)
          (instruction-origin-source-instruction o))))

(define (instruction-info-encoding=? a b)
  (equal? (instruction-info-encoding-signature a)
          (instruction-info-encoding-signature b)))

(define (instruction-info-interface=? a b)
  (equal? (instruction-info-interface-signature a)
          (instruction-info-interface-signature b)))

(provide find-instruction-info
         info-param-count
         info-raw-param-count
         info-operands
         info-raw-operands
         info-asm-format
         info-width
         info-size
         info-fixed-fields
         info-aliases
         info-origin
         info-raw-bindings
         info-rebuilt-bindings
         info-kind
         info-source-extension
         info-source-instruction
         fixed-fields->word
         canonical-pairs
         instruction-info-encoding-signature
         instruction-info-interface-signature
         instruction-info-provenance-signature
         instruction-info-encoding=?
         instruction-info-interface=?)
