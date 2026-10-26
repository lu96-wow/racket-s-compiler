#lang racket
;;; L3/demo.rkt -- 控制流分析: s-exp 程序 -> block list (只分析, 不改程序)

(require "insn.rkt"
         (prefix-in cfg: "cfg.rkt")
         "analyze.rkt")

(define items
  '((label main entry)
    (lwu t0 sp 8)
    (bge t1 t0 (main done))
    (jal x0 (main done))
    (label main dead)             ; 没人引用
    (lb t2 t0 0)
    (label main done)
    (li t3 42)
    (jal ra (lib helper))
    (label lib helper)
    (add a0 a0 x0)
    (jalr x0 ra 0)))

(displayln ";; 输入 (扁平 item)")
(for ([it (in-list items)]) (displayln (format "  ~s" it)))

(newline)
(displayln ";; CFG")
(for ([line (in-list (cfg:cfg->lines (cfg:build-cfg items)))])
  (displayln (string-append "  " line)))

(newline)
(define prog (analyze items))
(displayln ";; 分析结果: 块(身份 + 程序) 与 流(单独一份)")
(for ([b (in-list (program-blocks prog))]
      [f (in-list (program-flows prog))]
      [i (in-naturals)])
  (displayln (format "  ~a: ~s" i b))
  (displayln (format "      ~s" f)))
