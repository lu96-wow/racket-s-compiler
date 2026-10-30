#lang racket
;;; bind-labels/demo.rkt -- anchors -> symbols
;;;
;;; 输入 measured-layout（只有 anchors，没有绝对地址）:
;;;   ((phase measured) (segments ...) (anchors ...) (requests ...) (problems ...))
;;;
;;; 输出 bound-layout:
;;;   ((phase bound) (segments ...) (anchors ...) (symbols ...) (requests ...) (problems ...))
;;;
;;; 本层不改 item/尺寸，只把 (anchor 链 段 偏移) 变成 (symbol 链 段 偏移 地址)。

(require "bind.rkt"
         (only-in "../target.rkt" target-rv64-base)
         (only-in "../analyze/analyze.rkt" analyze)
         (only-in "../layout/layout.rkt"
                  layout-program layout-phase layout-problems layout-requests
                  layout-anchors))

(define measured
  (layout-program
   target-rv64-base
   (analyze '((label main) (ret)))
   '((label d data) (value 8 (main)) (fill 8 0))
   '((segments (segment (name c) (kind code) (start #x100000) (end #x100FFF) (align 16))
               (segment (name d) (kind data) (start #x200000) (end #x200FFF) (align 8)))
     (place c (main)) (place d (d data)))))

(define bound (bind-labels measured))

(displayln (format ";; measured-layout: phase=~a" (layout-phase measured)))
(displayln ";; anchor 行 (anchor 链 段名 偏移) —— 只有位置")
(for ([a (in-list (layout-anchors measured))])
  (displayln (format "  ~s -> ~a+~x" (cadr a) (caddr a) (cadddr a))))

(newline)
(displayln ";; requests / problems (measured)")
(displayln (format "  requests: ~s" (layout-requests measured)))
(displayln (format "  problems: ~s" (layout-problems measured)))

(newline)
(displayln (format ";; bound-layout: phase=~a" (layout-phase bound)))
(displayln ";; symbol 行 (symbol 链 段名 偏移 绝对地址) —— 偏移已经落到地址")
(for ([s (in-list (layout-symbols bound))])
  (displayln (format "  ~s -> ~a+~x = #x~x"
                     (cadr s) (caddr s) (cadddr s)
                     (symbol-address s))))

(newline)
(displayln (format "  requests: ~s" (layout-requests bound)))
(displayln (format "  problems: ~s" (layout-problems bound)))
