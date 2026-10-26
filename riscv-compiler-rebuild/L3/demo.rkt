#lang racket
;;; L3/demo.rkt -- L1 展平 -> L2 按表替换 -> L3 CFG 优化

(require (only-in "../L1/flatten.rkt" flatten-program)
         (only-in "../L2/rewrite.rkt" rewrite-program pseudo-leftover?)
         "cfg.rkt"
         "opt.rkt")

(define src
  '((module main
       (label entry)
       (load-32 t0 sp 8)          ; L2: 伪指令
       (ble t0 t1 (done))         ; L1: 链 -> (main done); L2: ble -> bge
       (jal x0 (done))            ; L3: 后面紧邻 done, 多余
       (label dead)               ; L3: 没人引用, 整块不可达
       (load-s8 t2 t0)            ; L2: -> lb
       (label done)               ; 同位置的第二个名字
       (li t3 42))                ; 透传
     (jal ra (lib helper))        ; 跨模块调用: 写完整链
     (module lib
       (label helper)
       (move a0 a0)               ; L2: -> add a0 a0 x0
       (jalr x0 ra 0))))

(define (show x) (format "~s" x))

(define after-l1 (flatten-program src))
(displayln ";; after L1 (模块展平: 链带作用域前缀)")
(displayln (show after-l1))

(define after-l2 (rewrite-program after-l1))
(newline)
(displayln ";; after L2 (按表替换)")
(displayln (show after-l2))
(displayln (format "pseudo leftover? ~a" (pseudo-leftover? after-l2)))

(newline)
(displayln ";; CFG of L2 output")
(for ([piece (in-list (split-into-segments after-l2))])
  (cond
    [(segment? piece)
     (for ([line (in-list (cfg->lines (build-cfg (segment-items piece))))])
       (displayln (string-append "  " line)))]
    [else (displayln (format "  ;; 屏障 ~s" piece))]))

(define after-l3 (optimize-program after-l2))
(newline)
(displayln ";; after L3 (CFG 优化)")
(displayln (show after-l3))
(displayln (format "list? ~a" (list? after-l3)))
