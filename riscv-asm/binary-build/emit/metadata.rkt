#lang racket/base

;; ============================================================
;; instruction-info generation
;;
;; Metadata records actual field bindings, not just operand names,
;; so the runtime can compare encodings without re-deriving layouts.
;; ============================================================

(require racket/list
         racket/string
         "../model.rkt"
         "../fixed.rkt"
         "../layout/plan.rkt"
         "../parcel.rkt"
         "../paths.rkt"
         "render.rkt")

(define (instruction-width idef)
  (parcel-length
   (lambda (bit)
     (fixed-fields-bit-value (instruction-def-fixed-fields idef) bit))
   (instruction-def-name idef)))

(define (asm-format name operands)
  (if (null? operands)
      name
      (format "~a ~a" name (string-join operands ", "))))

(define (width->size width)
  (define size (quotient width 8))
  (unless (= width (* size 8))
    (error 'gen-info-code
           "instruction width ~a is not a whole number of bytes" width))
  size)

(define (fixed-fields->code fixed-fields)
  (for/list ([ff (in-list fixed-fields)])
    (list (fixed-field-lo ff)
          (fixed-field-hi ff)
          (fixed-field-value ff))))

(define (origin->code origin)
  (format "(instruction-origin '~a ~v ~v)"
          (definition-origin-kind origin)
          (definition-origin-source-extension origin)
          (definition-origin-source-instruction origin)))

(define (gen-info-code extension resolved)
  (define idef (resolved-def-definition resolved))
  (define origin (resolved-def-origin resolved))
  (define raw-plan (raw-operand-plan idef))
  (define rebuilt-plan (rebuilt-operand-plan idef))
  (define raw-operands (operand-plan-args raw-plan))
  (define rebuilt-operands (operand-plan-args rebuilt-plan))
  (define fixed-fields (fixed-fields->code
                        (instruction-def-fixed-fields idef)))
  (define aliases (instruction-aliases idef))
  (define width (instruction-width idef))
  (format "(instruction-info ~v ~v ~a ~a '~s '~s '~s '~s ~a '~s '~s ~s)"
          (string->symbol (instruction-def-name idef))
          (string->symbol extension)
          width
          (width->size width)
          rebuilt-operands
          raw-operands
          fixed-fields
          aliases
          (origin->code origin)
          (plan-bindings raw-plan)
          (plan-bindings rebuilt-plan)
          (asm-format (instruction-def-name idef) rebuilt-operands)))

(define (info-variable-name extension)
  (format "~a-instructions" extension))

(define (gen-info-file-content extension resolved-defs output-path root)
  (define var (info-variable-name extension))
  (define body
    (if (null? resolved-defs)
        "(list)"
        (format "(list\n   ~a)"
                (string-join
                 (for/list ([resolved (in-list resolved-defs)])
                   (gen-info-code extension resolved))
                 "\n   "))))
  (render-module
   (info-require-specs output-path root)
   (list (format "(define ~a\n  ~a)" var body))
   (list var)))

(define (sorted-extensions ext->defs)
  (sort (hash-keys ext->defs) string<?))

(define (gen-extension-list-content ext->defs)
  (define extensions (sorted-extensions ext->defs))
  (render-module
   '()
   (list (format "(define extensions\n  '~s)"
                 (map string->symbol extensions)))
   (list "extensions")))

(define (gen-extension-map-content ext->defs)
  (define name->exts (make-hash))
  (for ([ext (in-list (sorted-extensions ext->defs))])
    (for ([resolved (in-list (hash-ref ext->defs ext))])
      (hash-update! name->exts
                    (instruction-def-name (resolved-def-definition resolved))
                    (lambda (exts) (cons ext exts))
                    '())))
  (define names (sort (hash-keys name->exts) string<?))
  (define entries
    (for/list ([name (in-list names)])
      (format "      (~a . ~a)"
              (string->symbol name)
              (map string->symbol
                   (sort (remove-duplicates (hash-ref name->exts name))
                         string<?)))))
  (define map-definition
    (string-join
     (append
      (list "(define instruction->extensions"
            "  (make-immutable-hash"
            "    '(")
      entries
      (list "    )))"))
     "\n"))
  (define getter-definition
    (string-append
     "(define (get-extensions name)\n"
     "  (unless (symbol? name)\n"
     "    (raise-argument-error 'get-extensions \"symbol?\" name))\n"
     "  (hash-ref instruction->extensions name '()))"))
  (render-module
   '()
   (list map-definition getter-definition)
   (list "instruction->extensions" "get-extensions")))

(provide gen-info-file-content
         gen-extension-list-content
         gen-extension-map-content)
