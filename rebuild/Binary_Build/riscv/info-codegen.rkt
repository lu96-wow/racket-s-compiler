#lang racket/base

(require racket/string
         racket/list
         "parse/main.rkt"
         "codegen.rkt")

;; ============================================================
;; instruction_info 生成
;;
;; 元数据直接从同一份 instruction-def 计算，不再重复解析源文件。
;; ============================================================

(define (fixed-bit-value fixed-fields bit)
  (for/first ([ff (in-list fixed-fields)]
              #:when (<= (fixed-field-lo ff) bit (fixed-field-hi ff)))
    (bitwise-and
     (arithmetic-shift (fixed-field-value ff)
                       (- (- bit (fixed-field-lo ff))))
     1)))

(define (instruction-width idef)
  (define fixed-fields (instruction-def-fixed-fields idef))
  (define b0 (fixed-bit-value fixed-fields 0))
  (define b1 (fixed-bit-value fixed-fields 1))
  (cond
    [(and b0 b1)
     (if (and (= b0 1) (= b1 1)) 32 16)]
    [else 32]))

(define (instruction-aliases idef)
  (for/list ([token (in-list (instruction-def-operands idef))]
             #:when (alias-token? token))
    (define a (parse-alias token))
    (list (alias-binding-target a)
          (alias-binding-source a))))

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

(define (gen-info-file-content extension defs)
  (define var (info-var extension))
  (define body
    (if (null? defs)
        "(list)"
        (format "(list\n   ~a)"
                (string-join
                 (for/list ([idef (in-list defs)])
                   (gen-info-code extension idef))
                 "\n   "))))
  (string-join
   (list "#lang racket/base"
         ""
         "(require \"struct.rkt\")"
         ""
         (format "(define ~a\n  ~a)" var body)
         ""
         (format "(provide ~a)" var)
         "")
   "\n"))

(define (sorted-extensions ext->defs)
  (sort (hash-keys ext->defs) string<?))

(define (gen-all-info-content ext->defs)
  (define extensions (sorted-extensions ext->defs))
  (define require-lines
    (for/list ([ext (in-list extensions)])
      (format "\"~a.rkt\"" ext)))
  (define vars
    (for/list ([ext (in-list extensions)])
      (info-var ext)))
  (string-join
   (list "#lang racket/base"
         ""
         (format "(require ~a)"
                 (string-join require-lines "\n         "))
         ""
         (if (null? vars)
             "(define all-instruction-info '())"
             (format "(define all-instruction-info\n  (append ~a))"
                     (string-join vars " ")))
         ""
         "(provide all-instruction-info)"
         "")
   "\n"))

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
  (string-join
   (append
    (list "#lang racket/base"
          ""
          "(define instruction->extensions"
          "  (make-immutable-hash"
          "    '(")
    entries
    (list "    )))"
          ""
          "(provide instruction->extensions)"
          ""))
   "\n"))

(provide gen-info-code
         gen-info-file-content
         gen-all-info-content
         gen-extension-map-content
         instruction-width)
