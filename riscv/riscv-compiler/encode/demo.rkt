#lang racket
;;; encode/demo.rkt -- 编码（最后一步）
;;;
;;; 本层的**全部输入**就是 bind-labels 的产物（bound-layout）：
;;;
;;;   ((phase bound)
;;;    (segments (segment (name …) (kind …) (start …) (end …) (align …)
;;;                       (items (offset k item) ...) (size n)) ...)
;;;    (anchors (anchor 链 段名 偏移) ...)
;;;    (symbols (symbol 链 段名 偏移 绝对地址) ...)
;;;    (requests ...) (problems ...))
;;;
;;; 这个 demo 先手写 measured-layout，再跑 bind-labels 得到 bound-layout。

(require "encode.rkt"
         (only-in "../target.rkt" target-rv64-base)
         (rename-in "../bind-labels/bind.rkt" [bind-labels bind-labels*]))

(define laid
  '((phase measured)
    (segments
     (segment (name prog1) (kind code) (start #x100000) (end #x100FFF) (align 16)
              (items (offset 0 (label main))
                     (offset 0 (li t0 #x12345678))       ; 8 字节: lui + addi
                     (offset 8 (la t3 (data1 table)))    ; 8 字节: auipc + addi
                     (offset 16 (addi a0 a0 1))
                     (offset 20 (pad 4))                 ; 对齐补出来的 4 个字节
                     (offset 24 (ret)))
              (size 28))
     (segment (name data1) (kind data) (start #x200000) (end #x200FFF) (align 8)
              (items (offset 0 (label data1 table))
                     (offset 0 (bytes 72 101 108 108 111 0))          ; "Hello\0"
                     (offset 6 (pad 2))                               ; 对齐补的 2 字节
                     (offset 8 (value 8 (data1 table)))    ; 指向自己
                     (offset 16 (value 4 #x12345678))
                     (offset 20 (fill 4 #xAA)))
              (size 24)))
    (anchors (anchor (main) prog1 0)
             (anchor (data1 table) data1 0))
    (requests)
    (problems)))

(displayln ";; 输入: measured-layout（每段: 起点 + 每条 item 的偏移 + 尺寸）")
(for ([seg (in-list (cdr (assoc 'segments laid)))])
  (displayln (format "  ~a ~a start=#x~x size=~a"
                     (cadr (assoc 'name (cdr seg)))
                     (cadr (assoc 'kind (cdr seg)))
                     (cadr (assoc 'start (cdr seg)))
                     (cadr (assoc 'size (cdr seg)))))
  (for ([e (in-list (cdr (assoc 'items (cdr seg))))]) (displayln (format "    ~s" e))))
(newline)

(define bound (bind-labels* laid))

(newline)
(displayln ";; bind-labels 产物: 符号行（偏移 -> 绝对地址）")
(for ([sym (in-list (cdr (assoc 'symbols bound)))])
  (displayln (format "  ~s -> ~a+~x (#x~x)"
                     (cadr sym) (caddr sym) (cadddr sym) (last sym))))

(define build (encode-layout target-rv64-base bound))

(define (hexdump start bs)
  (for ([i (in-range 0 (bytes-length bs) 16)])
    (define end (min (bytes-length bs) (+ i 16)))
    (define chunk (subbytes bs i end))
    (define addr (number->string (+ start i) 16))
    (printf "  ~a~a  " (make-string (max 0 (- 8 (string-length addr))) #\space) addr)
    (for ([b (in-bytes chunk)])
      (define h (string-upcase (number->string b 16)))
      (printf "~a " (if (= 1 (string-length h)) (string-append "0" h) h)))
    (for ([_ (in-range (- 16 (bytes-length chunk)))]) (printf "   "))
    (printf " |")
    (for ([b (in-bytes chunk)])
      (printf "~a" (if (<= 32 b 126) (integer->char b) #\.)))
    (displayln "|")))

(displayln ";; 输出: (build …)，每个段一坨字节")
(for ([seg (in-list (cdr build))])
  (displayln (format "  segment ~a start=#x~x size=~a"
                     (cadr (assoc 'name (cdr seg)))
                     (cadr (assoc 'start (cdr seg)))
                     (cadr (assoc 'size (cdr seg)))))
  (hexdump (cadr (assoc 'start (cdr seg))) (cadr (assoc 'bytes (cdr seg)))))
