#lang racket
;;; L7/demo.rkt -- s-exp -> 字节(最后一步)
;;;
;;; 输入: L6 之后的 layout(段 + 偏移 + 符号 + problems)
;;; 输出: (build (segment (name …) (start …) (size …) (bytes #vu8…)) …)
;;;
;;; 这里手写 layout 输入, 不依赖前面的层; 想看完整链就 L1→L7 手动串。

(require "encode.rkt"
         "../L6/relax.rkt"
         (only-in "../L3/analyze.rkt" analyze))
;; 注意: (la rd 链) 还没实现(L7 Phase 2), 见到会报"未实现"。

;; 只用 Phase 1 支持的东西: 去掉 la 那一行
(define prog1
  '((label main)
    (addi a0 a0 1)
    (beq t0 t1 (cold))
    (jalr x0 ra 0)
    (label cold) (ret)))

(define data
  '((label data1 table)
    (bytes 72 101 108 108 111 0)                 ; "Hello"
    (align 8)
    (value 8 (label+ (data1 table) 0))           ; 指向自己
    (value 4 #x12345678)
    (fill 4 #xAA)))

(define layout-input
  '((segments (segment prog1 code #x100000 #x100FFF 16)
              (segment data1 data #x200000 #x200FFF 8))
    (place prog1 (main) (cold))
    (place data1 (data1 table))))

(define laid (relax (analyze prog1) data layout-input))

(displayln ";; layout 里每条 item 和它的偏移")
(for ([seg (in-list (cdr (assoc 'segments laid)))])
  (displayln (format "  ~a:" (cadr (assoc 'name (cdr seg)))))
  (for ([e (in-list (cdr (assoc 'items (cdr seg))))]) (displayln (format "    ~s" e))))
(displayln (format "  problems: ~s" (cdr (assoc 'problems laid))))
(newline)

(define build (encode-layout laid))

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

(displayln ";; (build …)")
(for ([seg (in-list (cdr build))])
  (define name (cadr (assoc 'name (cdr seg))))
  (define start (cadr (assoc 'start (cdr seg))))
  (define size (cadr (assoc 'size (cdr seg))))
  (displayln (format "  segment ~a start=#x~x size=~a" name start size))
  (hexdump start (cadr (assoc 'bytes (cdr seg)))))
