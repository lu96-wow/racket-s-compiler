#lang racket
;;; L3/demo.rkt -- 控制流: 输入是 L2 的输出(扁平 item, 无 module), 输出是块列表

(require "cfg.rkt"
         "opt.rkt")

;; L3 的输入形状: 扁平 item 列表(这里直接写 L2 的输出)
(define items
  '((label main entry)
    (lwu t0 sp 8)                 ; 可达
    (bge t1 t0 (main done))
    (jal x0 (main done))          ; 紧邻 (main done) -> 多余
    (label main dead)             ; 没人引用 -> 整块不可达
    (lb t2 t0 0)
    (label main done)
    (li t3 42)
    (jal ra (lib helper))
    (label lib helper)
    (add a0 a0 x0)
    (jalr x0 ra 0)))

(displayln ";; L3 输入 (L2 输出)")
(for ([it (in-list items)]) (displayln (format "  ~s" it)))

(newline)
(displayln ";; CFG (优化前)")
(for ([line (in-list (cfg->lines (build-cfg items)))])
  (displayln (string-append "  " line)))

(define blocks (optimize-program items))

(newline)
(displayln ";; L3 输出: 块列表")
(for ([b (in-list blocks)])
  (displayln (format "  id=~a labels=~s insns=~s succ=~s fallthrough=~s"
                     (cadr (assoc 'id (cdr b)))
                     (cdr (assoc 'labels (cdr b)))
                     (cdr (assoc 'insns (cdr b)))
                     (cdr (assoc 'succ (cdr b)))
                     (cadr (assoc 'fallthrough (cdr b))))))
