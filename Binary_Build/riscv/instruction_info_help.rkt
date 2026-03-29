#lang racket

;; 安全查找：给定哈希表和指令助记符，返回操作数位置（1-indexed），若不存在则返回 #f
;; hash : immutable hash table, e.g., rv_i-rd
;; mnemonic : symbol, e.g., 'jal
(define (find-operand-index hash mnemonic)
  (hash-ref hash mnemonic #f))

;; 批量查找（返回列表，缺失字段为 #f）
(define (find-operand-indices hashes mnemonic)
  (map (λ (h) (find-operand-index h mnemonic)) hashes))

;; 检查某指令是否包含某字段
(define (has-operand? hash mnemonic)
  (not (not (find-operand-index hash mnemonic))))

(provide find-operand-index
         find-operand-indices
         has-operand?)

(require racket/hash)
(require (for-syntax racket/syntax))

;; 合并哈希列表（供宏使用）
(define (merge-hash-list hashes)
  (if (null? hashes)
      (make-immutable-hash '())
      (apply hash-union (reverse hashes) #:combine (λ (old new) new))))

;; 宏：自动拼接 ext + field → 变量名，并合并
;; 用法: (merge-extension-field-hashes '(rv_i rv64_i) rd)
;; 注意: 第一个参数是 QUOTED LIST OF SYMBOLS, 第二个是 IDENTIFIER（不加引号！）
(define-syntax (merge-extension-field-hashes stx)
  (syntax-case stx ()
    ;; 匹配 (merge-extension-field-hashes '(rv_i rv64_i) rd)
    [(_ (quote (ext ...)) field)
     (with-syntax ([(ext-field ...)
                    (for/list ([e (syntax->list #'(ext ...))])
                      (format-id #'field "~a-~a" (syntax-e e) (syntax-e #'field)))])
       #'(merge-hash-list (list ext-field ...)))]
    ;; 错误提示
    [(_ bad field)
     (raise-syntax-error 
       'merge-extension-field-hashes
       "expected a quoted list of symbols as first argument, e.g., '(rv_i rv64_i)"
       stx
       #'bad)]))

(provide merge-extension-field-hashes)