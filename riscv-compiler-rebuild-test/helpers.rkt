#lang racket
;;; helpers.rkt -- 黑盒测试共用的小工具
;;;
;;; 这里只放"看产物"的函数, 不放任何编译器逻辑。
;;; 每个测试文件都通过公开 API 调用 riscv-compiler-rebuild, 不 require 其内部私有绑定。

(require rackunit
         (only-in "../riscv-compiler-rebuild/analyze/analyze.rkt"
                  sexp->program))

(provide (all-defined-out))

;; ---------------------------------------------------------------------------
;; 断言包装
;; ---------------------------------------------------------------------------

;; 只要求"会报错", 不锁死错误消息。
(define (check-error who thunk)
  (check-exn exn:fail? thunk who))

;; ---------------------------------------------------------------------------
;; program / layout / build 的读取
;; ---------------------------------------------------------------------------

(define (program-of blocks+flows)
  (sexp->program blocks+flows))

(define (build-segment build name)
  (or (findf (lambda (seg)
               (equal? (cadr (assoc 'name (cdr seg))) name))
             (cdr build))
      (error 'build-segment "no segment ~a in ~e" name build)))

(define (build-bytes build name)
  (bytes->list (cadr (assoc 'bytes (cdr (build-segment build name))))))

(define (build-size build name)
  (cadr (assoc 'size (cdr (build-segment build name)))))

(define (layout-segment layout name)
  (or (findf (lambda (seg)
               (equal? (cadr (assoc 'name (cdr seg))) name))
             (cdr (assoc 'segments layout)))
      (error 'layout-segment "no segment ~a in ~e" name layout)))

(define (layout-items layout name)
  (cdr (assoc 'items (cdr (layout-segment layout name)))))

(define (layout-size layout name)
  (cadr (assoc 'size (cdr (layout-segment layout name)))))

(define (layout-symbols layout)
  (cdr (assoc 'symbols layout)))

(define (layout-problem-list layout)
  (cdr (assoc 'problems layout)))

(define (problem-kinds layout)
  (map car (layout-problem-list layout)))

(define (has-problem? layout kind)
  (and (memq kind (problem-kinds layout)) #t))

(define (check-problem layout kind)
  (check-true (has-problem? layout kind)
              (format "expected problem ~a, got ~s"
                      kind (layout-problem-list layout))))

;; 一个 layout 里的 item 序列(去掉 offset 外壳)
(define (layout-item-forms layout name)
  (for/list ([entry (in-list (layout-items layout name))])
    (caddr entry)))

;; ---------------------------------------------------------------------------
;; 字节
;; ---------------------------------------------------------------------------

(define (u16le lo hi) (list lo hi))
(define (u32le b0 b1 b2 b3) (list b0 b1 b2 b3))

;; ---------------------------------------------------------------------------
;; 失败也要反映到进程退出码
;;
;; rackunit 的 check-* 默认只打印失败, 不会中止脚本。run.rkt 按退出码汇总,
;; 所以这里记录失败, 由每个测试文件末尾的 finish-tests 决定 exit 1 还是打印 ok。
;; ---------------------------------------------------------------------------

(define check-failures '())
(define previous-check-handler (current-check-handler))

(current-check-handler
 (lambda (info)
   (set! check-failures (cons info check-failures))
   (previous-check-handler info)))

(define (check-failed?) (pair? check-failures))

(define (finish-tests who)
  (cond
    [(check-failed?)
     (eprintf "~a tests: FAILED (~a check(s))\n" who (length check-failures))
     (exit 1)]
    [else
     (displayln (format "~a tests: ok" who))]))
