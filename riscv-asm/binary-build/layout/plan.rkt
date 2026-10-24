#lang racket/base

;; ============================================================
;; Operand plans
;;
;; A plan records:
;;   fields : the actual field references passed to make-instruction
;;   args   : the public argument names (first-occurrence order)
;;   exprs  : the expression passed for each field
;;
;; The raw plan keeps source token order.
;; The rebuilt plan replaces complete raw groups with one logical field.
;; ============================================================

(require racket/list
         racket/string
         "../model.rkt"
         "groups.rkt")

(struct operand-plan (fields args exprs)
  #:transparent)

(define (alias-token? token)
  (string-contains? token "="))

(define (parse-alias token)
  (define parts (string-split token "="))
  (unless (= (length parts) 2)
    (error 'parse-alias "invalid alias operand: ~a" token))
  (values (list-ref parts 0) (list-ref parts 1)))

(define (normal-operand-tokens tokens)
  (filter (lambda (token) (not (alias-token? token))) tokens))

(define (instruction-aliases idef)
  (for/list ([token (in-list (instruction-def-operands idef))]
             #:when (alias-token? token))
    (define-values (target source) (parse-alias token))
    (list target source)))

(define (add-arg args arg)
  (if (member arg args) args (cons arg args)))

(define (validate-alias-sources! plan)
  (for ([expr (in-list (operand-plan-exprs plan))])
    (unless (member expr (operand-plan-args plan))
      (error 'validate-alias-sources!
             "alias source '~a' is not one of the operands: ~a"
             expr
             (operand-plan-args plan)))))

(define (raw-operand-plan idef)
  (define-values (args fields exprs)
    (for/fold ([args '()]
               [fields '()]
               [exprs '()])
              ([token (in-list (instruction-def-operands idef))])
      (cond
        [(alias-token? token)
         (define-values (target source) (parse-alias token))
         (values args (cons target fields) (cons source exprs))]
        [else
         (values (add-arg args token)
                 (cons token fields)
                 (cons token exprs))])))
  (define plan
    (operand-plan (reverse fields) (reverse args) (reverse exprs)))
  (validate-alias-sources! plan)
  plan)

(define (rebuilt-operand-plan idef)
  (define tokens (instruction-def-operands idef))
  (define operands (normal-operand-tokens tokens))

  ;; Map each raw token to the logical argument it contributes to.
  (define token->arg
    (for/fold ([h (make-hash)]) ([token (in-list tokens)])
      (if (alias-token? token)
          h
          (let* ([g (hash-ref token->group token #f)]
                 [arg (if (and g (group-complete? g operands))
                          (operand-group-name g)
                          token)])
            (hash-set! h token arg)
            h))))

  (define-values (args fields exprs)
    (for/fold ([args '()]
               [fields '()]
               [exprs '()])
              ([token (in-list tokens)])
      (cond
        [(alias-token? token)
         (define-values (target source) (parse-alias token))
         (define source-expr (hash-ref token->arg source source))
         (values args
                 (cons (string-append "raw:" target) fields)
                 (cons source-expr exprs))]
        [else
         (define g (hash-ref token->group token #f))
         (define arg (hash-ref token->arg token))
         (define grouped? (and g (group-complete? g operands)))
         (values (add-arg args arg)
                 (cons (if grouped?
                           (string-append "rebuilt:" arg)
                           (string-append "raw:" arg))
                       fields)
                 (cons arg exprs))])))

  (define plan
    (operand-plan (reverse fields) (reverse args) (reverse exprs)))
  (validate-alias-sources! plan)
  plan)

(define (plan-bindings plan)
  (for/list ([field (in-list (operand-plan-fields plan))]
             [expr (in-list (operand-plan-exprs plan))])
    (list field expr)))

(define (field-ref-name ref)
  (cond
    [(string-prefix? ref "raw:") (substring ref 4)]
    [(string-prefix? ref "rebuilt:") (substring ref 8)]
    [else ref]))

(define (direct-plan? plan)
  (equal? (map field-ref-name (operand-plan-fields plan))
          (operand-plan-args plan)))

(provide operand-plan
         operand-plan?
         operand-plan-fields
         operand-plan-args
         operand-plan-exprs
         alias-token?
         parse-alias
         normal-operand-tokens
         instruction-aliases
         raw-operand-plan
         rebuilt-operand-plan
         plan-bindings
         direct-plan?)
