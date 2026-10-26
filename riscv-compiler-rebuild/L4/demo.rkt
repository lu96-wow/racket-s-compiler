#lang racket
;;; L4/demo.rkt -- 死代码消除: block list -> block list (控制流会变)
;;;
;;; 输入是 L3 的分析结果(这里用 L3 的 IR 读入口写字面量, 不跑分析逻辑)

(require "dce.rkt"
         (only-in "../L3/analyze.rkt" program? program-blocks program-flows
                  sexp->program program->sexp))

(define prog
  (sexp->program
   '(program
     (blocks
      (block ((main)) (lwu t0 sp 8) (bge t1 t0 (done)))
      (block () (jal x0 (done)))
      (block ((dead)) (lb t2 t0 0))
      (block ((done)) (li t3 42) (jal ra (helper)))
      (block ((helper)) (add a0 a0 x0) (jalr x0 ra 0)))
     (flows
      (flow (succ 3 1) (fallthrough 1) (root? #t))
      (flow (succ 3) (fallthrough #f) (root? #f))
      (flow (succ 3) (fallthrough 3) (root? #f))
      (flow (succ 4) (fallthrough 4) (root? #f))
      (flow (succ) (fallthrough #f) (root? #f))))))

(define (show prog)
  (for ([b (in-list (program-blocks prog))]
        [f (in-list (program-flows prog))])
    (displayln (format "  ~s" b))
    (displayln (format "      ~s" f))))

(displayln ";; L4 输入")
(show prog)

(define out (eliminate-dead prog))

(newline)
(displayln ";; L4 输出 (dead 删掉; 空块并入下一块; 于是 done 紧邻, 那条 bge 也变成多余的)")
(show out)

(newline)
(displayln (format "passes: ~s" (pass-names)))
