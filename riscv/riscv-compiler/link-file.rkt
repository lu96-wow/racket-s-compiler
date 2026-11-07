#lang racket/base

;;; link-file.rkt
;;;
;;; 把 build 里"对外承诺"的那部分投影成**单独一个文件**的内容。
;;;
;;; 分工：
;;;   镜像文件  回答"这些地址上是什么字节"  —— 加载器 / 烧写器要
;;;   link 文件 回答"这些名字在哪个地址"    —— 下一个编译单元要
;;;
;;; 文件内容：
;;;
;;;   (link (base B) (symbol 链 地址) …)
;;;
;;; 只含 `provides` 里那些名字，顺序与 build 的 link 表一致（按地址升序），
;;; 所以它就是 link 表的一个**子序列**。
;;;
;;; 这个形状和输入侧的 `(link …)` 完全一样：写出来的文件可以直接当另一个
;;; 编译单元的输入。输出里不会出现未解析的项，缺口不随文件传播。
;;;
;;; 一行一个 s-exp，`read` 就能读回来（不需要 #lang）。

(require racket/list)

(provide link-file
         link-file->string
         write-link-file)

;; ---------------------------------------------------------------------------
;; build 里的投影
;; ---------------------------------------------------------------------------

(define (build-item build tag)
  (or (findf (lambda (x) (and (pair? x) (eq? (car x) tag))) (cdr build))
      (error 'link-file "build 里没有 ~a: ~e" tag (map car (cdr build)))))

(define (base-row link) (cadr link))
(define (symbol-rows link) (cddr link))
(define (row-chain row) (cadr row))

;; build -> (link (base B) (symbol 链 地址) …)   ; 只留 provides 里的名字
(define (link-file build)
  (define link (build-item build 'link))
  (define provides (build-item build 'provides))
  (define wanted (make-hash))
  (for ([chain (in-list (cdr provides))]) (hash-set! wanted chain #t))
  (cons 'link
        (cons (base-row link)
              (for/list ([row (in-list (symbol-rows link))]
                         #:when (hash-ref wanted (row-chain row) #f))
                row))))

;; 一行的 s-exp；和 (write …) 一致，read 就能读回来。
(define (link-file->string build)
  (format "~s\n" (link-file build)))

(define (write-link-file build path)
  (call-with-output-file path
    (lambda (out) (display (link-file->string build) out))
    #:exists 'replace))
