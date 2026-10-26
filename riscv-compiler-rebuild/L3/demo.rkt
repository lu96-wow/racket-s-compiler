#lang racket
;;; L2/demo.rkt -- L1 按表替换 -> L2 CFG 优化

(require "../L1/rewrite.rkt"
         "cfg.rkt"
         "opt.rkt")

(define src
  '(begin
     (label main)
     (load-32 t0 sp 8)            ; L1: 伪指令
     (store-64 sp 16 t0)          ; L1: 地址在前
     (move t1 t0)                 ; L1: 换 add
     (ble t0 t1 done)             ; L1: 换 bge
     (jal x0 done)                ; L2: 后面紧邻 done, 多余
     (label dead)                 ; L2: 没人引用, 整块不可达
     (load-s8 t2 t0)              ; L1: 换 lb
     (label done)
     (li t3 42)))                 ; 透传

(define (show x)
  (if (quote-list? x) (format "'~s" (cadr x)) (format "~s" x)))

(define after-l1 (rewrite-program src))
(displayln ";; after L1 (按表替换)")
(displayln (show after-l1))
(displayln (format "pseudo leftover? ~a" (pseudo-leftover? (cadr after-l1))))

(newline)
(displayln ";; CFG of L1 output (每段一张图)")
(define-values (l1-items _) (program-parts after-l1))
(for ([piece (in-list (split-into-segments l1-items))])
  (cond
    [(segment? piece)
     (define g (build-cfg (segment-items piece)))
     (for ([line (in-list (cfg->lines g))]) (displayln (string-append "  " line)))]
    [else (displayln (format "  ;; 屏障 ~s" piece))]))

(newline)
(define after-l2 (optimize-program after-l1))
(displayln ";; after L2 (CFG 优化)")
(displayln (show after-l2))

(newline)
(define pieces (split-into-segments l1-items))
(displayln (format "段数 ~a, 块数(L1) ~a"
                   (length pieces)
                   (for/sum ([piece (in-list pieces)] #:when (segment? piece))
                     (cfg-block-count (build-cfg (segment-items piece))))))
(displayln (format "quote-list? ~a" (quote-list? after-l2)))
