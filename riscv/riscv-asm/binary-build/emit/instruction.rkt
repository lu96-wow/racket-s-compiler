#lang racket/base

;; ============================================================
;; Raw / rebuilt instruction module generation
;; ============================================================

(require racket/list
         racket/string
         "../model.rkt"
         "../layout/plan.rkt"
         "../paths.rkt"
         "render.rkt")

(define (fixed-field->code ff)
  (format "(bit-range-fixed ~a ~a ~a)"
          (fixed-field-lo ff)
          (fixed-field-hi ff)
          (fixed-field-value ff)))

(define (render-list items)
  (if (null? items)
      "(list)"
      (format "(list ~a)" (string-join items " "))))

(define (gen-instruction-code idef plan)
  (define fields (operand-plan-fields plan))
  (define args (operand-plan-args plan))
  (define exprs (operand-plan-exprs plan))
  (define fixed
    (for/list ([ff (in-list (instruction-def-fixed-fields idef))])
      (fixed-field->code ff)))
  (define make-expr
    (format "(make-instruction\n   ~a\n   ~a)"
            (render-list fields)
            (render-list fixed)))
  (cond
    [(direct-plan? plan)
     (format "(define ~a\n  ~a)" (instruction-def-name idef) make-expr)]
    [else
     (define lambda-expr
       (if (null? args)
           (format "(lambda ()\n      (encode))")
           (format "(lambda (~a)\n      (encode ~a))"
                   (string-join args " ")
                   (string-join exprs " "))))
     (format "(define ~a\n  (let ([encode ~a])\n    ~a))"
             (instruction-def-name idef) make-expr lambda-expr)]))

(define (instruction-names defs)
  (for/list ([idef (in-list defs)]) (instruction-def-name idef)))

(define (gen-raw-file-content defs output-path root)
  (render-module
   (raw-require-specs output-path root)
   (for/list ([idef (in-list defs)])
     (gen-instruction-code idef (raw-operand-plan idef)))
   (instruction-names defs)))

(define (gen-rebuilt-file-content defs output-path root)
  (render-module
   (rebuilt-require-specs output-path root)
   (for/list ([idef (in-list defs)])
     (gen-instruction-code idef (rebuilt-operand-plan idef)))
   (instruction-names defs)))

(provide gen-raw-file-content
         gen-rebuilt-file-content)
