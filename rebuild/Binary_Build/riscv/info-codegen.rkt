#lang racket/base

(require racket/string
         racket/list
         "parse/main.rkt"
         "codegen.rkt"
         "render.rkt"
         "../paths.rkt")

;; ============================================================
;; instruction_info 生成
;;
;; 元数据直接从同一份 instruction-def 计算，不再重复解析源文件。
;; ============================================================

(define (asm-format name operands)
  (if (null? operands)
      name
      (format "~a ~a" name (string-join operands ", "))))

(define (gen-info-code extension idef)
  (define name (instruction-def-name idef))
  (define rebuilt-operands
    (operand-plan-args (rebuilt-operand-plan idef)))
  (define raw-operands
    (operand-plan-args (raw-operand-plan idef)))
  (define fixed-fields
    (for/list ([ff (in-list (instruction-def-fixed-fields idef))])
      (list (fixed-field-lo ff)
            (fixed-field-hi ff)
            (fixed-field-value ff))))
  (define aliases (instruction-aliases idef))
  (format "(instruction-info ~s ~s ~a '~s '~s '~s '~s ~s)"
          name
          extension
          (instruction-width idef)
          rebuilt-operands
          raw-operands
          fixed-fields
          aliases
          (asm-format name rebuilt-operands)))

(define (info-var extension)
  (format "~a-instructions" extension))

(define (gen-info-file-content extension defs output-path)
  (define var (info-var extension))
  (define body
    (if (null? defs)
        "(list)"
        (format "(list\n   ~a)"
                (string-join
                 (for/list ([idef (in-list defs)])
                   (gen-info-code extension idef))
                 "\n   "))))
  (render-module
   (info-require-specs output-path)
   (list (format "(define ~a\n  ~a)" var body))
   (list var)))

(define (sorted-extensions ext->defs)
  (sort (hash-keys ext->defs) string<?))

(define (gen-all-info-content ext->defs output-path)
  (define extensions (sorted-extensions ext->defs))
  (define require-specs
    (for/list ([ext (in-list extensions)])
      (info-module-require-spec output-path ext)))
  (define vars
    (for/list ([ext (in-list extensions)])
      (info-var ext)))
  (define definition
    (if (null? vars)
        "(define all-instruction-info '())"
        (format "(define all-instruction-info\n  (append ~a))"
                (string-join vars " "))))
  (render-module require-specs
                 (list definition)
                 (list "all-instruction-info")))

(define (gen-extension-map-content ext->defs)
  (define name->exts (make-hash))
  (for ([ext (in-list (sorted-extensions ext->defs))])
    (for ([idef (in-list (hash-ref ext->defs ext))])
      (hash-update! name->exts
                    (instruction-def-name idef)
                    (lambda (exts) (cons ext exts))
                    '())))
  (define names (sort (hash-keys name->exts) string<?))
  (define entries
    (for/list ([name (in-list names)])
      (format "      (~s . ~s)"
              name
              (sort (remove-duplicates
                     (hash-ref name->exts name))
                    string<?))))
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
    "(define (get-extensions name)\n  (hash-ref instruction->extensions name '()))")
  (render-module '()
                 (list map-definition getter-definition)
                 (list "instruction->extensions"
                       "get-extensions")))

(provide gen-info-code
         gen-info-file-content
         gen-all-info-content
         gen-extension-map-content)
