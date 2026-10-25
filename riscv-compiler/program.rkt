#lang racket/base

;; ============================================================
;; 顶层 S-expression 程序
;;
;; 输入：
;;   name, label 表, 已解析跳转偏移的指令序列
;;
;; 输出：
;;   (program
;;     (func main
;;       (labels ((main . 0) ...))
;;       (code
;;         (addi t0 x0 1)
;;         ...)))
;; ============================================================

(require racket/list)

(provide make-program-sexpr)

(define (make-program-sexpr name labels code)
  (list 'program
        (list 'func name
              (list 'labels labels)
              (cons 'code code))))
