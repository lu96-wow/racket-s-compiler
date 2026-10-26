#lang racket
;;; L4/demo.rkt -- 死代码消除: block list -> block list (控制流会变)
;;;
;;; 输入是 L3 的分析结果(这里用 L3 的 IR 读入口写字面量, 不跑分析逻辑)

(require "dce.rkt"
         (only-in "../L3/analyze.rkt" sexp->blocks blocks->sexp
                  block-id block-labels block-insns block-succ block-fallthrough block-root?))

(define blocks
  (sexp->blocks
   '((block (id 0) (labels (main)) (insns (lwu t0 sp 8) (bge t1 t0 (done)))
            (succ 3 1) (fallthrough 1) (root? #t))
     (block (id 1) (labels) (insns (jal x0 (done))) (succ 3) (fallthrough #f) (root? #f))
     (block (id 2) (labels (dead)) (insns (lb t2 t0 0)) (succ 3) (fallthrough 3) (root? #f))
     (block (id 3) (labels (done)) (insns (li t3 42) (jal ra (helper)))
            (succ 4) (fallthrough 4) (root? #t))
     (block (id 4) (labels (helper)) (insns (add a0 a0 x0) (jalr x0 ra 0))
            (succ) (fallthrough #f) (root? #t)))))

(define (show blocks)
  (for ([b (in-list (blocks->sexp blocks))])
    (displayln (format "  ~s" b))))

(displayln ";; L4 输入")
(show blocks)

(define out (eliminate-dead blocks))

(newline)
(displayln ";; L4 输出 (dead 删掉; 空块并入下一块; 于是 done 紧邻, 那条 bge 也变成多余的)")
(show out)

(newline)
(displayln (format "passes: ~s" (pass-names)))
