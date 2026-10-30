#lang racket/base

;; ============================================================
;; Raw/rebuilt field module registry
;;
;; This is the single list of field-module kinds. It connects:
;;   - output file names (paths.rkt, emit/fields.rkt)
;;   - operand-group module symbols (groups.rkt)
;; ============================================================

(struct field-module (name file)
  #:transparent)

(define field-modules
  (list (field-module 'scalar "scalar.rkt")
        (field-module 'compressed "compressed.rkt")
        (field-module 'vector "vector.rkt")
        (field-module 'mop "mop.rkt")))

(define field-module-files
  (for/list ([m (in-list field-modules)])
    (field-module-file m)))

(define field-module-names
  (for/list ([m (in-list field-modules)])
    (field-module-name m)))

(define (field-module-file->name file)
  (or (for/first ([m (in-list field-modules)]
                  #:when (equal? (field-module-file m) file))
        (field-module-name m))
      (error 'field-module-file->name
             "unknown field module file: ~a"
             file)))

(provide field-module
         field-module?
         field-module-name
         field-module-file
         field-modules
         field-module-files
         field-module-names
         field-module-file->name)
