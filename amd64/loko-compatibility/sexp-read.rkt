#lang racket
;;; amd64/loko-compatibility/sexp-read.rkt
;;;
;;; 读 Loko `sexp` / `sexp-pc` target 吐出的 dump。
;;;
;;; 为什么不直接用 `read`：pc-repl 的 dump 是 44 MB / 1,615,886 个 item /
;;; 950 万个 token，`read` 要 10–12 s。时间几乎全花在"每个 token 先造一个
;;; string，再 string->symbol / string->number"上：
;;;
;;;   符号 3,976,593 个实例，只有 257,583 种拼写（15 倍重复，最多的是 mov 43 万）
;;;   整数 1,150,766 个，最长 19 位（只有 16,379 个超出 fixnum）
;;;   字符串 1,057、字符 275、bytevector 58,681（平均 82 字节）
;;;
;;; 这里直接扫字节：符号按 (bytes, start, len) 查自建 intern 表（命中零分配），
;;; 整数就地累加，bytevector 就地解码。只有"`read` 才说得准"的东西（flonum、
;;; 带转义的字符串、`|…|` 符号、字符名）才退回 `read`。
;;;
;;; 退回 `read` 时**不能**自己截一段 token 喂给它：`read` 可能只吃其中一部分
;;; （`#\x41` 是字符 `x` 后面跟整数 41，`#true` 是 #t 后面跟 rue）。所以慢路径
;;; 用同一个 port、同一个位置，读完后按 port 的实际位置继续——以 `read` 为准。
;;;
;;; 实测 /tmp/pc.sexp：`read` 10.5–12.4 s -> 2.4 s，结果与 `read` 逐 item `equal?`
;;; （8.5 MB 的 linux dump：2.3 s -> 0.44 s）。判据见 sexp-read-test.rkt：
;;; 快是目的，"读得和 `read` 不一样"就是错。

(require racket/fixnum)

(provide read-dump
         read-dump-bytes)

;; ---------------------------------------------------------------------------
;; 符号 intern：把拼写本身塞进一个 fixnum 当 key
;;
;; 短符号（≤7 字节，占实例的 76%）直接拼进 fixnum，key 精确，命中时不用再比
;; 字节；长符号用整串的 31 位 FNV 当 key，命中后按字节核验。核验是必须的：
;; 同一个 key 下可能有不同拼写，认错了就是静默错读。
;; ---------------------------------------------------------------------------

(define short-max 7)

;; b[i,j)（j-i ≤ 7）→ 非负 fixnum
(define (pack7 b i j)
  (let loop ([k i] [v 0])
    (if (fx= k j)
        v
        (loop (fx+ k 1) (+ (* v 256) (bytes-ref b k))))))

(define (fnv31 b i j)
  (let loop ([k i] [h 2166136261])
    (if (fx= k j)
        (bitwise-and h #x7FFFFFFF)
        (loop (fx+ k 1)
              (bitwise-and (* (bitwise-xor h (bytes-ref b k)) 16777619)
                           #xFFFFFFFF)))))

(struct long-entry (sym start len) #:transparent)

;; in: 整份 dump 的 port（慢路径问 `read` 用，见 read-at!）
(struct parser (short long bytes in))

(define (make-parser b in)
  (parser (make-hash) (make-hash) b in))

;; (bytes=? 在这一版 Racket 里没有区间版本，自己扫)
(define (span=? b1 s1 b2 s2 len)
  (let loop ([k 0])
    (cond
      [(fx= k len) #t]
      [(fx= (bytes-ref b1 (fx+ s1 k)) (bytes-ref b2 (fx+ s2 k))) (loop (fx+ k 1))]
      [else #f])))

(define (intern! p b i j)
  (define len (fx- j i))
  (cond
    [(fx<= len short-max)
     (define key (pack7 b i j))
     (define short (parser-short p))
     (or (hash-ref short key #f)
         (let ([sym (string->symbol (bytes->string/utf-8 (subbytes b i j)))])
           (hash-set! short key sym)
           sym))]
    [else
     (define key (+ (* (fnv31 b i j) 4) (if (fx< len 4) len 3)))
     (define cands (hash-ref (parser-long p) key '()))
     (let loop ([cs cands])
       (cond
         [(null? cs)
          (define sym (string->symbol (bytes->string/utf-8 (subbytes b i j))))
          (hash-set! (parser-long p) key (cons (long-entry sym i len) cands))
          sym]
         [(and (fx= (long-entry-len (car cs)) len)
               (span=? b i (parser-bytes p) (long-entry-start (car cs)) len))
          (long-entry-sym (car cs))]
         [else (loop (cdr cs))]))]))

;; ---------------------------------------------------------------------------
;; 词法
;; ---------------------------------------------------------------------------

;; 是不是 token 分隔符。
;;
;; `[` `{` 与 `(` 等价：Loko 的 printer 把认不出来的对象写成
;; `#[const value: …]`，Racket 的 reader 恰好把 `#[` 当 `#(` 读。
;;
;; `;` 是行注释；`'` `` ` `` `,` 是 quote 语法，dump 里不会出现
;; （Loko 那边已经展开成普通列表/符号）。后三个不当分隔符处理就会静默错读，
;; 所以宁可让它们走到 `read` 那条路上去。
(define delim-table
  (let ([v (make-vector 256 #f)])
    (for ([c (in-list '(32 10 9 13                  ; 空白
                        40 41 91 93 123 125         ; ( ) [ ] { }
                        34 59                       ; " ;
                        39 96 44))])                ; ' ` ,
      (vector-set! v c #t))
    v))

(define (delimiter? c)
  (and (fx>= c 0) (fx< c 256) (vector-ref delim-table c)))

(define (byte-at b i n)
  (if (fx< i n) (bytes-ref b i) -1))

(define (skip-ws b i n)
  (let loop ([i i])
    (define c (byte-at b i n))
    (cond
      [(fx= c 59)                                   ; ;
       (let skip ([k (fx+ i 1)])
         (cond [(fx>= k n) n]
               [(fx= (bytes-ref b k) 10) (loop (fx+ k 1))]
               [else (skip (fx+ k 1))]))]
      [(or (fx= c 32) (fx= c 10) (fx= c 9) (fx= c 13)) (loop (fx+ i 1))]
      [else i])))

(define (digit? c) (and (fx>= c 48) (fx<= c 57)))

;; 慢路径：让 `read` 从位置 i 自己读一个 datum，按它实际吃到哪儿继续。
;; 不用 token 切片，因为 `read` 可能只吃切片的一部分（见文件头）。
(define (read-at! p i)
  (define in (parser-in p))
  (file-position in i)
  (define v (read in))
  (values v (file-position in)))

;; ---------------------------------------------------------------------------
;; 语法
;; ---------------------------------------------------------------------------

(define (open-paren? c) (or (fx= c 40) (fx= c 91) (fx= c 123)))
(define (close-paren? c) (or (fx= c 41) (fx= c 93) (fx= c 125)))

;; `(` `[` `{` 各自要用对应的括号关（和 `read` 一致：混着写是错误，不是宽容）
(define (closer-of c)
  (cond [(fx= c 40) 41] [(fx= c 91) 93] [else 125]))

(define (parse-value p b i n)
  (define c (bytes-ref b i))
  (cond
    [(open-paren? c) (parse-list p b (fx+ i 1) n (closer-of c))]
    [(fx= c 34) (parse-string p b (fx+ i 1) n)]         ; "
    [(fx= c 35) (parse-hash p b (fx+ i 1) n)]           ; #
    [(fx= c 45) (parse-integer p b i n (fx+ i 1) #t)]   ; -
    [(digit? c) (parse-integer p b i n i #f)]
    [(fx= c 43) (parse-plus p b i n)]                   ; +
    [(fx= c 46) (read-at! p i)]                         ; .5 之类
    [(close-paren? c)
     (error 'read-dump "unexpected ~a at offset ~a" (integer->char c) i)]
    [(delimiter? c)
     (error 'read-dump "unexpected ~a at offset ~a" (integer->char c) i)]
    [else (parse-symbol p b i n)]))

(define (parse-list p b i n closer)
  (let loop ([i (skip-ws b i n)]
             [acc '()])
    (define c (byte-at b i n))
    (cond
      [(and (close-paren? c) (not (fx= c closer)))
       (error 'read-dump "expected ~a to close, found ~a at offset ~a"
              (integer->char closer) (integer->char c) i)]
      [(close-paren? c)
       ;; acc 是倒序；元素少于两个时不用 reverse
       (values (if (or (null? acc) (null? (cdr acc))) acc (reverse acc))
               (fx+ i 1))]
      [(fx< c 0) (error 'read-dump "unterminated list")]
      [(and (fx= c 46)                              ; . 点对
            (let ([c2 (byte-at b (fx+ i 1) n)])
              (or (fx< c2 0) (delimiter? c2))))
       (define-values (tail j) (parse-value p b (skip-ws b (fx+ i 1) n) n))
       (define j* (skip-ws b j n))
       (unless (fx= (byte-at b j* n) closer)
         (error 'read-dump "expected ~a after dotted tail, found ~a at offset ~a"
                (integer->char closer) (byte-at b j* n) j*))
       (values (append (reverse acc) tail) (fx+ j* 1))]
      [else
       (define-values (v j) (parse-value p b i n))
       (loop (skip-ws b j n) (cons v acc))])))

;; 字符串：没有转义就一次 subbytes，有转义（\uN… / \" / \\）交给 `read`。
(define (parse-string p b i n)
  (let scan ([k i])
    (cond
      [(fx>= k n) (error 'read-dump "unterminated string")]
      [(fx= (bytes-ref b k) 34)
       (values (bytes->string/utf-8 (subbytes b i k)) (fx+ k 1))]
      [(fx= (bytes-ref b k) 92) (read-at! p (fx- i 1))]
      [else (scan (fx+ k 1))])))

;; # 之后：bytevector / vector / 字符 / #t / #f / 别的
(define (parse-hash p b i n)
  (define c (byte-at b i n))
  (cond
    [(fx= c 34) (parse-bytevector p b (fx+ i 1) n)]       ; #"
    [(open-paren? c)                                      ; #( / #[ / #{
     (define-values (items j) (parse-list p b (fx+ i 1) n (closer-of c)))
     (values (list->vector items) j)]
    [else
     ;; 字符（#\a / #\uD7A3 / #\x41 …）、#t/#f/#true/#false：写法太多，
     ;; 让 `read` 定，并按它实际吃到的位置继续
     (read-at! p (fx- i 1))]))

;; #"\xNN…"：printer 只用两位十六进制转义，别的转义交给 `read`。
(define (parse-bytevector p b i n)
  (define out (make-bytes 256))
  (define len-ref (box 0))
  (let loop ([k i])
    (cond
      [(fx>= k n) (error 'read-dump "unterminated bytevector")]
      [(fx= (bytes-ref b k) 34)
       (values (subbytes out 0 (unbox len-ref)) (fx+ k 1))]
      [(fx= (bytes-ref b k) 92)
       (cond
         [(and (fx< (fx+ k 2) n) (fx= (bytes-ref b (fx+ k 1)) 120))   ; \x
          (define hi (hex-digit (bytes-ref b (fx+ k 2))))
          (define lo (hex-digit (byte-at b (fx+ k 3) n)))
          (cond
            [(and hi lo)
             (define len (unbox len-ref))
             (when (fx>= len (bytes-length out))
               (set! out (bytes-append out (make-bytes (bytes-length out)))))
             (bytes-set! out len (fx+ (fx* 16 hi) lo))
             (set-box! len-ref (fx+ len 1))
             (loop (fx+ k 4))]
            [else (read-at! p (fx- i 2))])]
         [else (read-at! p (fx- i 2))])]
      [else
       (define len (unbox len-ref))
       (when (fx>= len (bytes-length out))
         (set! out (bytes-append out (make-bytes (bytes-length out)))))
       (bytes-set! out len (bytes-ref b k))
       (set-box! len-ref (fx+ len 1))
       (loop (fx+ k 1))])))

(define (hex-digit c)
  (cond
    [(and (fx>= c 48) (fx<= c 57)) (fx- c 48)]
    [(and (fx>= c 97) (fx<= c 102)) (fx- c 87)]
    [(and (fx>= c 65) (fx<= c 70)) (fx- c 55)]
    [else #f]))

;; 整数：就地累加到 fixnum 边界，超界（dump 里只有 19 位以上的 %u64 值）交给
;; `read`。注意这一版 Racket 的 fx* 超界会报错（不是回绕），所以用普通的
;; `*` + fixnum? 判断，溢出自然升成 bignum 再回退。
(define (parse-integer p b i n start neg?)
  (let loop ([k start] [acc 0])
    (define c (byte-at b k n))
    (cond
      [(digit? c)
       (define next (+ (* 10 acc) (- c 48)))
       (if (fixnum? next)
           (loop (fx+ k 1) next)
           (read-at! p i))]
      [(fx= k start) (parse-symbol p b i n)]        ; 单独的 "-" 之类
      [(and (fx>= c 0) (not (delimiter? c)))
       ;; 整数后面还有字符：`0.0`、`1/3`… 可能是别的数
       (read-at! p i)]
      [else (values (if neg? (- 0 acc) acc) k)])))

;; `+` 单独出现是符号（dump 里有 14.8 万个），`+i` / `+inf.0` 才是数
(define (parse-plus p b i n)
  (define c1 (byte-at b (fx+ i 1) n))
  (if (or (fx< c1 0) (delimiter? c1))
      (values (intern! p b i (fx+ i 1)) (fx+ i 1))
      (read-at! p i)))

;; 扫到 token 结尾，顺便记下有没有 `|` / `\`（有就交给 `read`）
(define (symbol-end b i n)
  (let scan ([k i] [special? #f])
    (define c (byte-at b k n))
    (cond
      [(fx< c 0) (values k special?)]
      [(delimiter? c) (values k special?)]
      [(or (fx= c 124) (fx= c 92)) (scan (fx+ k 1) #t)]
      [else (scan (fx+ k 1) special?)])))

(define (parse-symbol p b i n)
  (cond
    [(fx= (bytes-ref b i) 124) (read-at! p i)]      ; | 开头: 里面可以有分隔符
    [else
     (define-values (j special?) (symbol-end b i n))
     (cond
       [(fx= i j) (error 'read-dump "empty token at offset ~a" i)]
       [special? (read-at! p i)]
       [else (values (intern! p b i j) j)])]))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (read-dump-bytes b)
  (define n (bytes-length b))
  (define p (make-parser b (open-input-bytes b)))
  (let loop ([i 0] [acc '()])
    (define i* (skip-ws b i n))
    (if (fx>= i* n)
        (reverse acc)
        (let-values ([(v j) (parse-value p b i* n)])
          (loop j (cons v acc))))))

(define (read-dump path)
  (read-dump-bytes (file->bytes path)))
