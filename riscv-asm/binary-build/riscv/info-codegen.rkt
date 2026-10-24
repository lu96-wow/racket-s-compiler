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

;; size 是 width 的字节数。parcel 规则只会给出 16/32，
;; 这里仍做整除检查，避免规则以后被改坏时静默截断。
(define (width->size width)
  (define size (quotient width 8))
  (unless (= width (* size 8))
    (error 'gen-info-code
           "instruction width ~a is not a whole number of bytes"
           width))
  size)

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
  (define width (instruction-width idef))
  (format "(instruction-info ~v ~v ~a ~a '~s '~s '~s '~s ~s)"
          (string->symbol name)
          (string->symbol extension)
          width
          (width->size width)
          rebuilt-operands
          raw-operands
          fixed-fields
          aliases
          (asm-format name rebuilt-operands)))

(define (info-variable-name extension)
  (format "~a-instructions" extension))

(define (gen-info-file-content extension defs output-path)
  (define var (info-variable-name extension))
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

;; 只生成“有哪些扩展”的清单，不再把所有表 append 成一个总表。
;; 查表一律走某个扩展的表，避免跨扩展同名（rv32/rv64 变体）选错。
(define (gen-extension-list-content ext->defs)
  (define extensions (sorted-extensions ext->defs))
  (define definition
    (format "(define extensions\n  '~s)"
            (map string->symbol extensions)))
  (render-module '()
                 (list definition)
                 (list "extensions")))

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
      (format "      (~a . ~a)"
              (string->symbol name)
              (map string->symbol
                   (sort (remove-duplicates
                          (hash-ref name->exts name))
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
  (render-module '()
                 (list map-definition getter-definition)
                 (list "instruction->extensions"
                       "get-extensions")))

(provide gen-info-code
         gen-info-file-content
         gen-extension-list-content
         gen-extension-map-content)
