#lang racket

;; 1. 定义结构体
;; 使用 #:mutable 允许修改 buffer 和 logical-size
(struct integer-receiver
  (size-n signed? big-endian? capacity buffer logical-size)
  #:mutable)

;; 2. 构造器
;; 返回一个初始化好的结构体实例
(define (make-integer-byte-receiver size-n signed? big-endian?)
  (unless (member size-n '(1 2 4 8))
    (error 'make-integer-byte-receiver "size-n must be 1, 2, 4, or 8"))

  ;; 初始容量：512 字节
  (define initial-capacity 512)
  (define initial-buffer (make-bytes initial-capacity 0))

  ;; 返回结构体实例
  (integer-receiver size-n signed? big-endian?
                    initial-capacity
                    initial-buffer
                    0))

;; 3. 内部辅助过程：确保容量
;; 这是一个纯内部逻辑，操作结构体字段
(define (ensure-capacity! receiver needed)
  (let ([current-capacity (integer-receiver-capacity receiver)])
    (when (> needed current-capacity)
      ;; 计算新容量：翻倍直到够用
      (let loop ([new-capacity (* current-capacity 2)])
        (if (<= new-capacity needed)
            (loop (* new-capacity 2))
            ;; 执行扩容
            (let* ([old-buffer (integer-receiver-buffer receiver)]
                   [logical-size (integer-receiver-logical-size receiver)]
                   [new-buffer (make-bytes new-capacity 0)])
              (bytes-copy! new-buffer 0 old-buffer 0 logical-size)
              ;; 更新结构体字段
              (set-integer-receiver-capacity! receiver new-capacity)
              (set-integer-receiver-buffer! receiver new-buffer)))))))

;; 4. 添加整数函数
(define (receiver-add! receiver n)
  (unless (exact-integer? n)
    (error 'receiver-add! "expected exact integer, got: ~e" n))

  (define size-n (integer-receiver-size-n receiver))
  (define signed? (integer-receiver-signed? receiver))
  (define big-endian? (integer-receiver-big-endian? receiver))

  (let ([new-size (+ (integer-receiver-logical-size receiver) size-n)])
    ;; 检查并扩容
    (ensure-capacity! receiver new-size)

    ;; 写入数据
    (integer->integer-bytes n size-n signed? big-endian?
                            (integer-receiver-buffer receiver)
                            (integer-receiver-logical-size receiver))

    ;; 更新逻辑大小
    (set-integer-receiver-logical-size! receiver new-size)))

;; 5. 获取大小函数
(define (receiver-size receiver)
  (integer-receiver-logical-size receiver))

;; 6. 获取字节函数
(define (receiver-get-bytes receiver)
  (subbytes (integer-receiver-buffer receiver) 0 (integer-receiver-logical-size receiver)))

;; 辅助函数：字节转十六进制字符串（保持不变）
(define (bytes->hex b)
  (apply string-append
         (for/list ([x b])
           (~r x #:base 16 #:min-width 2 #:pad-string "0"))))

(provide (all-defined-out))