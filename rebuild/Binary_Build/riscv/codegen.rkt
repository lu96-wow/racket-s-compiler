#lang racket/base

(require racket/string
         racket/list
         "parse/main.rkt"
         "render.rkt"
         "../paths.rkt")

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
  (define operands (normal-operand-tokens (instruction-def-operands idef)))
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
;; 文件内容
;; ------------------------------------------------------------

(define (instruction-names defs)
  (for/list ([idef (in-list defs)])
    (instruction-def-name idef)))

(define (gen-raw-file-content defs output-path)
  (render-module
   (raw-require-specs output-path)
   (for/list ([idef (in-list defs)])
     (gen-raw-instruction-code idef))
   (instruction-names defs)))

(define (gen-rebuilt-file-content defs output-path)
  (render-module
   (rebuilt-require-specs output-path)
   (for/list ([idef (in-list defs)])
     (gen-rebuilt-instruction-code idef))
   (instruction-names defs)))

(provide gen-raw-instruction-code
         gen-rebuilt-instruction-code
         gen-raw-file-content
         gen-rebuilt-file-content
         operand-plan
         operand-plan?
         operand-plan-fields
         operand-plan-args
         operand-plan-exprs
         raw-operand-plan
         rebuilt-operand-plan)
