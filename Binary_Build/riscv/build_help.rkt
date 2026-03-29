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
(define (looks-like-bit-range? s)
  (and (string-contains? s "=")
       (let ([parts (string-split s "=")])
         (and (= (length parts) 2)
              (let ([lhs (car parts)] [rhs (cadr parts)])
                (and (string->integer rhs 0) ; 先粗略检查 value
                     (string-contains? lhs "..")
                     (let ([bits (string-split lhs "..")])
                       (and (= (length bits) 2)
                            (string->number (car bits))
                            (string->number (cadr bits))))))))))

;; 解析 "high..low=value" → "(range-fixed high low value)"
(define (parse-bit-range s line-number)
  (match-let ([(list lhs rhs) (string-split s "=")])
    (match-let ([(list high low) (string-split lhs "..")])
      (format "(bit-range-fixed ~a ~a ~a)"
              high low (string->integer rhs line-number)))))

;; 主解析函数：一行 → Racket define 表达式字符串
(define (parse-instruction-line line line-number)
  (define tokens (filter (λ (t) (not (string=? t ""))) (string-split line)))
  (cond
    [(null? tokens) ""]
    [else
     (define mnemonic (car tokens))
     (define rest (cdr tokens))
     ;; 分离操作数 vs 位段
     (define-values (operands bit-ranges)
       (partition (λ (t) (not (looks-like-bit-range? t))) rest))
     ;; 合并 hi/lo 对：只保留 base name（去重）
     (define operand-bases
       (remove-duplicates (map strip-hi/lo operands)))
     ;; 生成参数列表
     (define args
       (append operand-bases
               (map (λ (br) (parse-bit-range br line-number)) bit-ranges)))
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
     ;; 分离操作数（非位段）
     (define operand-tokens
       (filter (λ (t) (not (looks-like-bit-range? t))) rest))
     ;; 合并 hi/lo 并去重（保留首次出现顺序）
     (define operand-bases
       (remove-duplicates (map strip-hi/lo operand-tokens)))
     (cons mnemonic (map string->symbol operand-bases))]))


(provide string->integer
         hi/lo-suffix?
         strip-hi/lo
         looks-like-bit-range?
         parse-bit-range
         parse-instruction-line
         extract-mnemonic-and-operands)