#lang racket
;;; amd64/tools/flow-cache-test.rkt
;;;
;;; 缓存失效逻辑的单元测试。这里的错误不会让测试"看起来失败"——它会让
;;; 构建悄悄复用旧产物，所以每条失效条件都要有一条用例。
;;;
;;; 失效条件（见 flow-cache.rkt 开头）：
;;;   format-version / stage-version / flow / dump / 源文件指纹

(require rackunit
         racket/file
         (file "flow-cache.rkt"))

(define tmp (make-temporary-file "flow-cache-test~a" 'directory))

(define (write-text! path text)
  (call-with-output-file path #:exists 'replace
    (lambda (out) (display text out))))

(define dump (build-path tmp "dump.sexp"))
(write-text! dump "(mov rax 1)\n")

;; 假的 amd64 根目录：指纹只看 *.rkt 的名字/个数/mtime
(define root (build-path tmp "amd64"))
(define sources (build-path root "compiler"))
(make-directory* sources)
(define src (build-path sources "a.rkt"))
(write-text! src "#lang racket\n")

(define flow '(loko-compat encode))
(define (fresh? cache [flow* flow])
  (define-values (ok? _why) (cache-fresh? cache dump root flow*))
  ok?)
(define (fresh-why cache [flow* flow])
  (define-values (_ok? why) (cache-fresh? cache dump root flow*))
  why)

(define cache (make-cache dump root flow (hash 'build '(build (segment (name text))))))

(check-true (fresh? cache) "刚做出来的缓存是新的")

;; 写盘 → 读回来，内容要一模一样（缓存是 serialize 出来的）
(define file (cache-file-path tmp 'encode))
(check-equal? (path->string file) (path->string (build-path tmp "encode.rktd")))
(write-flow-cache! file cache)
(define loaded (read-flow-cache file))
(check-true (and loaded (fresh? loaded)) "写盘再读回来还是新的")
(check-equal? (cache-value loaded 'build) '(build (segment (name text))))
(check-false (read-flow-cache (build-path tmp "nope.rktd")) "没有文件就没有缓存")
(write-text! (build-path tmp "junk.rktd") "not a cache")
(check-false (read-flow-cache (build-path tmp "junk.rktd")) "坏文件当成没有缓存")

;; flow 不同：loko-near 和 loko 的 build 不是一回事
(check-false (fresh? cache '(loko)) "选的是另一组层")
(check-true (string-contains? (fresh-why cache '(loko)) "flow"))

;; dump 变了（这里改大小，不改 mtime，最坏情况）
(write-text! dump "(mov rax 2)\n(mov rbx 3)\n")
(check-false (fresh? cache) "dump 变了")
(check-true (string-contains? (fresh-why cache) "dump"))

;; 源文件多了/少了：指纹里的个数变
(define cache2 (make-cache dump root flow (hash 'build '(build))))
(check-true (fresh? cache2) "重新按新 dump 做缓存")
(write-text! (build-path sources "b.rkt") "#lang racket\n")
(check-false (fresh? cache2) "流水线源码改过了")
(check-true (string-contains? (fresh-why cache2) "源码"))

(delete-directory/files tmp)
(printf "flow-cache: ok\n")
