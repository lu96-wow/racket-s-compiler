#lang racket/base

(require racket/string
         racket/list
         racket/path
         "parse/main.rkt")

;; ============================================================
;; codegen：解析结果 → raw / rebuilt 两个表示层
;;
;; operand-groups 只存在于生成期，用来把多个源 token 归并成一个
;; 重建操作数。生成出来的模块里没有运行期操作数表。
;; ============================================================

(struct operand-group (name raw-tokens)
  #:transparent)

(define operand-groups
  (list
   ;; scalar
   (operand-group "simm12" '("imm12hi" "imm12lo"))
   (operand-group "bimm12" '("bimm12hi" "bimm12lo"))

   ;; compressed
   (operand-group "c_uimm7" '("c_uimm7lo" "c_uimm7hi"))
   (operand-group "c_uimm8" '("c_uimm8lo" "c_uimm8hi"))
   (operand-group "c_uimm9" '("c_uimm9lo" "c_uimm9hi"))
   (operand-group "c_imm6" '("c_imm6lo" "c_imm6hi"))
   (operand-group "c_nzimm6" '("c_nzimm6lo" "c_nzimm6hi"))
   (operand-group "c_nzimm10" '("c_nzimm10lo" "c_nzimm10hi"))
   (operand-group "c_nzimm18" '("c_nzimm18lo" "c_nzimm18hi"))
   (operand-group "c_bimm9" '("c_bimm9lo" "c_bimm9hi"))
   (operand-group "c_nzuimm6" '("c_nzuimm6lo" "c_nzuimm6hi"))
   (operand-group "c_uimm8sp" '("c_uimm8splo" "c_uimm8sphi"))
   (operand-group "c_uimm9sp" '("c_uimm9splo" "c_uimm9sphi"))
   (operand-group "c_uimm10sp" '("c_uimm10splo" "c_uimm10sphi"))

   ;; vector
   (operand-group "zimm6" '("zimm6lo" "zimm6hi"))

   ;; Zimop
   (operand-group "mop_r_t"
                  '("mop_r_t_30" "mop_r_t_27_26" "mop_r_t_21_20"))
   (operand-group "mop_rr_t"
                  '("mop_rr_t_30" "mop_rr_t_27_26"))))

(define token->group
  (make-immutable-hash
   (for*/list ([g (in-list operand-groups)]
               [token (in-list (operand-group-raw-tokens g))])
     (cons token g))))

;; ------------------------------------------------------------
;; operand token / alias
;; ------------------------------------------------------------

(struct alias-binding (target source)
  #:transparent)

(define (alias-token? token)
  (string-contains? token "="))

(define (parse-alias token)
  (define parts (string-split token "="))
  (unless (= (length parts) 2)
    (error 'parse-alias "invalid alias operand: ~a" token))
  (alias-binding (list-ref parts 0) (list-ref parts 1)))

(define (normal-operands idef)
  (filter (lambda (token) (not (alias-token? token)))
          (instruction-def-operands idef)))

;; ------------------------------------------------------------
;; rebuilt 分组
;; ------------------------------------------------------------

(define (group-names)
  (map operand-group-name operand-groups))

(define (rebuilt-group-name? name)
  (and (member name (group-names)) #t))

(define (complete-group? g operands)
  (for/and ([token (in-list (operand-group-raw-tokens g))])
    (and (member token operands) #t)))

;; ------------------------------------------------------------
;; operand plan：字段引用、用户参数、每个字段对应的值表达式
;; ------------------------------------------------------------

(struct operand-plan (fields args exprs)
  #:transparent)

(define (validate-alias-sources! plan)
  (for ([expr (in-list (operand-plan-exprs plan))])
    (unless (member expr (operand-plan-args plan))
      (error 'validate-alias-sources!
             "alias source '~a' is not one of the operands: ~a"
             expr
             (operand-plan-args plan)))))

(define (raw-operand-plan idef)
  (define tokens (instruction-def-operands idef))
  (define args '())
  (define fields '())
  (define exprs '())

  (for ([token (in-list tokens)])
    (cond
      [(alias-token? token)
       (define a (parse-alias token))
       (set! fields (cons (alias-binding-target a) fields))
       (set! exprs (cons (alias-binding-source a) exprs))]
      [else
       (set! fields (cons token fields))
       (set! exprs (cons token exprs))
       (unless (member token args)
         (set! args (cons token args)))]))

  (define plan (operand-plan (reverse fields)
                             (reverse args)
                             (reverse exprs)))
  (validate-alias-sources! plan)
  plan)

(define (rebuilt-operand-plan idef)
  (define tokens (instruction-def-operands idef))
  (define operands (normal-operands idef))
  (define token->arg (make-hash))

  ;; 先为普通 token 建立“它对应的逻辑参数名”。
  ;; 只有当一个组的 raw token 全部出现时才使用 rebuilt 组合字段；
  ;; 否则保留原始 token（例如 RV32 的 c.slli 只有 c_nzuimm6lo）。
  (for ([token (in-list tokens)])
    (unless (alias-token? token)
      (define g (hash-ref token->group token #f))
      (define arg
        (if (and g (complete-group? g operands))
            (operand-group-name g)
            token))
      (hash-set! token->arg token arg)))

  (define args '())
  (define fields '())
  (define exprs '())

  (for ([token (in-list tokens)])
    (cond
      [(alias-token? token)
       (define a (parse-alias token))
       (set! fields
             (cons (format "raw:~a" (alias-binding-target a)) fields))
       (define source (alias-binding-source a))
       (define source-expr (hash-ref token->arg source source))
       (set! exprs (cons source-expr exprs))]
      [else
       (define g (hash-ref token->group token #f))
       (define arg (hash-ref token->arg token))
       (define grouped? (and g (complete-group? g operands)))
       (set! fields
             (cons (if grouped?
                       (format "rebuilt:~a" arg)
                       (format "raw:~a" arg))
                   fields))
       (set! exprs (cons arg exprs))
       (unless (member arg args)
         (set! args (cons arg args)))]))

  (define plan (operand-plan (reverse fields)
                             (reverse args)
                             (reverse exprs)))
  (validate-alias-sources! plan)
  plan)

;; ------------------------------------------------------------
;; 代码字符串
;; ------------------------------------------------------------

(define (fixed-field->code ff)
  (format "(bit-range-fixed ~a ~a ~a)"
          (fixed-field-lo ff)
          (fixed-field-hi ff)
          (fixed-field-value ff)))

(define (render-list items)
  (if (null? items)
      "(list)"
      (format "(list ~a)" (string-join items " "))))

(define (field-ref-name ref)
  (cond
    [(string-prefix? ref "raw:") (substring ref 4)]
    [(string-prefix? ref "rebuilt:") (substring ref 8)]
    [else ref]))

(define (direct-plan? plan)
  (equal? (map field-ref-name (operand-plan-fields plan))
          (operand-plan-args plan)))

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
     (format "(define ~a\n  ~a)"
             (instruction-def-name idef)
             make-expr)]
    [else
     (define lambda-expr
       (if (null? args)
           (format "(lambda ()\n      (encode))")
           (format "(lambda (~a)\n      (encode ~a))"
                   (string-join args " ")
                   (string-join exprs " "))))
     (format "(define ~a\n  (let ([encode ~a])\n    ~a))"
             (instruction-def-name idef)
             make-expr
             lambda-expr)]))

(define (gen-raw-instruction-code idef)
  (gen-instruction-code idef (raw-operand-plan idef)))

(define (gen-rebuilt-instruction-code idef)
  (gen-instruction-code idef (rebuilt-operand-plan idef)))

;; ------------------------------------------------------------
;; import / pseudo 展开
;; ------------------------------------------------------------

(define (extension-stem path)
  (path->string (path-replace-suffix (file-name-from-path path) "")))

(define (find-instruction defs name)
  (for/first ([idef (in-list defs)]
              #:when (equal? (instruction-def-name idef) name))
    idef))

(define (resolve-imports extension-file extension-map)
  (for/list ([im (in-list (extension-file-imports extension-file))])
    (define source-extension (import-def-source-extension im))
    (define instruction-name (import-def-instruction-name im))
    (define source-file (hash-ref extension-map source-extension #f))
    (unless source-file
      (error 'resolve-imports
             "cannot resolve import ~a::~a"
             source-extension instruction-name))
    (define idef
      (find-instruction (extension-file-standard source-file)
                        instruction-name))
    (unless idef
      (error 'resolve-imports
             "instruction ~a::~a not found in ~a"
             source-extension
             instruction-name
             (extension-file-path source-file)))
    idef))

(define (add-unique defs seen idef)
  (define name (instruction-def-name idef))
  (cond
    [(hash-has-key? seen name) (values defs seen)]
    [else
     (hash-set! seen name #t)
     (values (cons idef defs) seen)]))

(define (prepare-extension-defs extension-file extension-map)
  (define seen (make-hash))
  (define-values (with-standard seen*)
    (for/fold ([defs '()] [seen seen])
              ([idef (in-list (extension-file-standard extension-file))])
      (add-unique defs seen idef)))
  (define-values (with-imports seen**)
    (for/fold ([defs with-standard] [seen seen*])
              ([idef (in-list (resolve-imports extension-file extension-map))])
      (add-unique defs seen idef)))
  (define-values (all _seen)
    (for/fold ([defs with-imports] [seen seen**])
              ([pseudo (in-list (extension-file-pseudo extension-file))])
      (add-unique defs seen (pseudo-def-instruction pseudo))))
  (reverse all))

;; ------------------------------------------------------------
;; 文件内容
;; ------------------------------------------------------------

(define raw-requires
  (string-join
   '("\"../../../base.rkt\""
     "\"../../raw/scalar.rkt\""
     "\"../../raw/compressed.rkt\""
     "\"../../raw/vector.rkt\""
     "\"../../raw/mop.rkt\"")
   "\n         "))

(define rebuilt-requires
  (string-join
   '("\"../../../base.rkt\""
     "(prefix-in raw: \"../../raw/scalar.rkt\")"
     "(prefix-in raw: \"../../raw/compressed.rkt\")"
     "(prefix-in raw: \"../../raw/vector.rkt\")"
     "(prefix-in raw: \"../../raw/mop.rkt\")"
     "(prefix-in rebuilt: \"../../rebuilt/scalar.rkt\")"
     "(prefix-in rebuilt: \"../../rebuilt/compressed.rkt\")"
     "(prefix-in rebuilt: \"../../rebuilt/vector.rkt\")"
     "(prefix-in rebuilt: \"../../rebuilt/mop.rkt\")")
   "\n         "))

(define (render-provide defs)
  (if (null? defs)
      "(provide)"
      (format "(provide\n ~a)"
              (string-join
               (for/list ([idef (in-list defs)])
                 (instruction-def-name idef))
               "\n "))))

(define (gen-raw-file-content defs)
  (string-join
   (append
    (list "#lang racket/base"
          ""
          (format "(require ~a)" raw-requires)
          "")
    (for/list ([idef (in-list defs)])
      (gen-raw-instruction-code idef))
    (list ""
          (render-provide defs)
          ""))
   "\n"))

(define (gen-rebuilt-file-content defs)
  (string-join
   (append
    (list "#lang racket/base"
          ""
          (format "(require ~a)" rebuilt-requires)
          "")
    (for/list ([idef (in-list defs)])
      (gen-rebuilt-instruction-code idef))
    (list ""
          (render-provide defs)
          ""))
   "\n"))

(provide gen-raw-instruction-code
         gen-rebuilt-instruction-code
         gen-raw-file-content
         gen-rebuilt-file-content
         prepare-extension-defs
         operand-plan
         operand-plan?
         operand-plan-fields
         operand-plan-args
         operand-plan-exprs
         raw-operand-plan
         rebuilt-operand-plan
         alias-binding
         alias-binding?
         alias-binding-target
         alias-binding-source
         alias-token?
         parse-alias)
