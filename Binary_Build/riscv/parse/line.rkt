#lang racket

(require racket/string
         racket/list
         "struct.rkt"
         "field.rkt")

;; ============================================================
;; 行过滤
;; ============================================================

;; 是否应跳过该行 (空行 / 注释 / $import / $pseudo_op)
(define (skip-line? line)
  (define s (string-trim line))
  (or (string=? s "")
      (string-prefix? s "#")
      (string-prefix? s "$")))

;; ============================================================
;; hi/lo 后缀处理
;; ============================================================

(define (hi/lo-suffix? s)
  (and (> (string-length s) 2)
       (let ([suffix (substring s (- (string-length s) 2))])
         (or (string=? suffix "hi") (string=? suffix "lo")))))

(define (strip-hi/lo s)
  (if (hi/lo-suffix? s)
      (substring s 0 (- (string-length s) 2))
      s))

;; ============================================================
;; 主解析函数: 一行 → instruction-def 或 #f
;; ============================================================

(define (parse-line line line-number)
  (define tokens (filter (λ (t) (not (string=? t ""))) (string-split line)))
  (cond
    [(null? tokens) #f]
    [else
     (define mnemonic (car tokens))
     (define rest (cdr tokens))

     ;; 分离固定字段 vs 操作数
     (define fixed-tokens
       (filter looks-like-fixed-field? rest))
     (define operand-tokens
       (filter (λ (t) (not (looks-like-fixed-field? t))) rest))

     ;; 合并 hi/lo 对：去重，保持顺序
     (define operands
       (remove-duplicates (map strip-hi/lo operand-tokens)))

     ;; 解析固定字段
     (define ffs
       (map (λ (t) (parse-fixed-field t line-number)) fixed-tokens))

     (instruction-def mnemonic operands ffs)]))

(provide
 skip-line?
 hi/lo-suffix?
 strip-hi/lo
 parse-line)
