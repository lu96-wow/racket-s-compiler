#lang racket

(define (bit-check-print n)
  (unless (and (integer? n) (exact? n) (>= n 0))
    (error 'bit-check-print "Expected non-negative exact integer, got: ~v" n))

  ;; 将 0-15 的数转为 4 位二进制字符串
  (define (to-4bit-bin val)
    (let ([s (number->string val 2)])
      (string-append (make-string (- 4 (string-length s)) #\0) s)))

  (cond
    [(= n 0)
     (printf "Decimal: 0\n")
     (printf "Hex:     0\n")
     (printf "Binary:  0000\n")]
    [else
     ;; 从低位开始提取 4-bit 组，结果是 MSB first 列表
     (define groups
       (let loop ([x n] [acc '()])
         (if (= x 0)
             acc
             (loop (arithmetic-shift x -4)
                   (cons (bitwise-and x #xF) acc)))))

     ;; 转 hex 和 binary 字符串（每组 4 位）
     (define hex-line
       (string-join
        (for/list ([v groups])
          (string-upcase (number->string v 16)))
        " "))
     (define bin-line
       (string-join
        (for/list ([v groups])
          (to-4bit-bin v))
        " "))

     (printf "Decimal: ~a\n" n)
     (printf "Hex:     ~a\n" hex-line)
     (printf "Binary:  ~a\n" bin-line)]))