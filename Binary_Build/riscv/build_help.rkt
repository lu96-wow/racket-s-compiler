#lang racket

(require racket/string)

;; 支持 #x, 0x, #b, 0b, #o, 0o, 或十进制
(define (string->integer s line-number)
  (define prefixes '["#x" "0x" "#b" "0b" "#o" "0o"])
  (define bases     '(16 16 2 2 8 8))
  (let loop ([ps prefixes] [bs bases])
    (cond
      [(null? ps)
       (or (string->number s 10)
           (error 'string->integer "Invalid number '~a' on line ~a" s line-number))]
      [(string-prefix? s (car ps))
       (or (string->number (substring s (string-length (car ps))) (car bs))
           (error 'string->integer "Invalid number '~a' on line ~a" s line-number))]
      [else (loop (cdr ps) (cdr bs))])))

;; 判断是否以 "hi" 或 "lo" 结尾（长度 > 2）
(define (hi/lo-suffix? s)
  (and (> (string-length s) 2)
       (let ([suffix (substring s (- (string-length s) 2))])
         (or (string=? suffix "hi") (string=? suffix "lo")))))

;; 去掉 hi/lo 后缀
(define (strip-hi/lo s)
  (if (hi/lo-suffix? s)
      (substring s 0 (- (string-length s) 2))
      s))

;; 是否形如 "high..low=value"
(define (looks-like-multi-bit? s)
  (and (string-contains? s "=")
       (let ([parts (string-split s "=")])
         (and (= (length parts) 2)
              (string-contains? (car parts) "..")
              (let ([bits (string-split (car parts) "..")])
                (and (= (length bits) 2)
                     (string->number (car bits))
                     (string->number (cadr bits))))
              (string->integer (cadr parts) 0)))))

;; 是否形如 "bit=value"（单比特固定字段）
(define (looks-like-single-bit? s)
  (and (string-contains? s "=")
       (let ([parts (string-split s "=")])
         (and (= (length parts) 2)
              (string->number (car parts))        ; 左边是纯数字
              (string->integer (cadr parts) 0))))) ; 右边是合法数值

;; 统一判断：是否为固定字段（多比特或单比特）
(define (looks-like-fixed-field? s)
  (or (looks-like-multi-bit? s)
      (looks-like-single-bit? s)))

;; 解析 "high..low=value" → "(bit-range-fixed high low value)"
(define (parse-multi-bit s line-number)
  (match-let ([(list lhs rhs) (string-split s "=")])
    (match-let ([(list high low) (string-split lhs "..")])
      (format "(bit-range-fixed ~a ~a ~a)"
              high low (string->integer rhs line-number)))))

;; 解析 "bit=value" → "(bit-range-fixed bit bit value)"
(define (parse-single-bit s line-number)
  (match-let ([(list lhs rhs) (string-split s "=")])
    (let ([bit (string->number lhs)])
      (format "(bit-range-fixed ~a ~a ~a)"
              bit bit (string->integer rhs line-number)))))

;; 主解析函数：一行 → Racket define 表达式字符串
(define (parse-instruction-line line line-number)
  (define tokens (filter (λ (t) (not (string=? t ""))) (string-split line)))
  (cond
    [(null? tokens) ""]
    [else
     (define mnemonic (car tokens))
     (define rest (cdr tokens))
     ;; 分离固定字段 vs 操作数
     (define fixed-fields
       (filter looks-like-fixed-field? rest))
     (define operands
       (filter (λ (t) (not (looks-like-fixed-field? t))) rest))
     ;; 合并 hi/lo 对：只保留 base name（去重，保持顺序）
     (define operand-bases
       (remove-duplicates (map strip-hi/lo operands)))
     ;; 转换每个固定字段为 (bit-range-fixed ...)
     (define parsed-fields
       (map (λ (f)
              (cond
                [(looks-like-multi-bit? f)
                 (parse-multi-bit f line-number)]
                [(looks-like-single-bit? f)
                 (parse-single-bit f line-number)]
                [else
                 (error 'parse-instruction-line
                        "Unexpected fixed field format: ~a on line ~a" f line-number)]))
            fixed-fields))
     ;; 组装参数：操作数符号 + 固定字段表达式
     (define args (append operand-bases parsed-fields))
     (format "(define ~a (make-instruction ~a))"
             mnemonic
             (string-join args " "))]))

;; 返回 (cons mnemonic-symbol (list operand-symbol ...)) 或 #f（跳过行）
(define (extract-mnemonic-and-operands line line-number)
  (define tokens (filter (λ (t) (not (string=? t ""))) (string-split line)))
  (cond
    [(null? tokens) #f]
    [(or (string-prefix? (car tokens) "#")
         (string-prefix? (car tokens) "$"))
     #f]
    [else
     (define mnemonic (string->symbol (car tokens)))
     (define rest (cdr tokens))
     ;; 只保留非固定字段作为操作数
     (define operand-tokens
       (filter (λ (t) (not (looks-like-fixed-field? t))) rest))
     ;; 合并 hi/lo 并去重（保持首次出现顺序）
     (define operand-bases
       (remove-duplicates (map strip-hi/lo operand-tokens)))
     (cons mnemonic (map string->symbol operand-bases))]))

(provide string->integer
         hi/lo-suffix?
         strip-hi/lo
         looks-like-fixed-field?
         looks-like-multi-bit?
         looks-like-single-bit?
         parse-multi-bit
         parse-single-bit
         parse-instruction-line
         extract-mnemonic-and-operands)