#lang racket

(require (for-syntax "asm.rkt"
                     "module-process.rkt"
                     racket/base
                     racket/match
                     syntax/parse))

;; ============================================================
;; asm — 编译期汇编
;;
;; 所有 form 必须是 (quote ...) 形式。
;; 用户宏展开为 (begin '(insn) '(insn) ...)。
;; asm 只剥 quote → 模块消解 → 汇编 → bytes 字面量。
;; ============================================================

(define-syntax (asm stx)
  (syntax-parse stx
    [(_asm word-size:expr exts:expr form ...)
     ;; 1. 展开用户宏（asm 指令被 quote 保护，只需阻止 asm 指令名）
     (define stop-list
       (list #'module #'module+ #'provide #'require #'label #'space #'li))

     (define expanded
       (for/list ([f (in-list (syntax->list #'(form ...)))])
         (local-expand f 'expression stop-list)))

     ;; 2. 展平 begin，提取 quote
     (define items (extract-quoted (flatten-begins expanded)))

     ;; 3. 模块处理
     (define flat-items (process-modules items))

     ;; 4. → struct
     (define structs
       (for/list ([item (in-list flat-items)])
         (match item
           [`(asm-label ',name)     (asm-label name)]
           [`(asm-insn ',mn ',args) (asm-insn mn args)]
           [`(asm-space ,size)      (asm-space size)]
           [_ (error 'asm "bad item: ~a" item)])))

     ;; 5. 汇编
     (define bytes (assemble structs (syntax->datum #'word-size) (syntax->datum #'exts)))

     ;; 6. bytes 字面量
     (datum->syntax stx bytes stx stx)]))

;; 从展开+展平后的 syntax 列表中提取所有 (quote ...) → 数据列表
;; 模块 body 内部递归剥 quote
(define-for-syntax (extract-quoted stx-list)
  (for/list ([stx (in-list stx-list)])
    (match (syntax->datum stx)
      [`(quote ,item) (unwrap-quote item)]
      [other (error 'asm "expected (quote ...), got: ~a" other)])))

(define-for-syntax (unwrap-quote item)
  (match item
    [`(quote ,inner)     (unwrap-quote inner)]
    [`(module ,name ,body ...)   `(module ,name ,@(map unwrap-quote body))]
    [`(module+ ,name ,body ...)  `(module+ ,name ,@(map unwrap-quote body))]
    [_ item]))

;; 展平 begin
(define-for-syntax (flatten-begins stx-list)
  (apply append
    (for/list ([stx (in-list stx-list)])
      (match (syntax->datum stx)
        [`(begin ,sub ...) (flatten-begins (cdr (syntax-e stx)))]
        [_ (list stx)]))))

(provide asm)
