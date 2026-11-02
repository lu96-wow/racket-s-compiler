#lang racket
(require racket/serialize
         racket/list
         racket/file
         racket/path)
;;; amd64/tools/flow-cache.rkt
;;;
;;; loko-flow 的缓存文件格式。只有一个入口概念：**这次流水的产物**
;;; （`loko-near` 的 `build`、`elf` 的 `image`），外加一份指纹说明它是从哪来的。
;;;
;;; 为什么不缓存每一层：试过。1.6M 个 item 的 pc 镜像，每层输出序列化后共
;;; 443 MB，命中缓存要 189 s（deserialize 逐层重建那些 list），而**整个流水线
;;; 从头算只要 21 s**。缓存中间层是纯负优化。
;;;
;;; 为什么不用 mtime 单调递增判断：那样只能回答"有没有改过"，回答不了"哪一层
;;; 变了"，而且每层一个文件、每次都要 stat 443 MB 的产物。现在只有一个产物，
;;; 失效条件可以写清楚：
;;;
;;;   1. format-version —— 这个文件格式本身变了
;;;   2. stage-version  —— 流水线语义变了（改编译器就得 +1，见下面注释）
;;;   3. flow           —— 选了哪些层（loko-near 和 loko 的 build 不一样）
;;;   4. dump           —— 输入 dump 的绝对路径 + 大小 + mtime
;;;   5. 源文件指纹     —— compiler/ 等目录里 *.rkt 的 (最大 mtime, 个数)
;;;
;;; 第 2 条和第 5 条是重叠的：stage-version 是"我知道我改了什么"，
;;; 源文件指纹是"你忘了 +1 也不会拿到假结果"。两个都很便宜（命中路径上
;;; 只扫 ~250 个文件名），所以都要。

(provide cache-file-path
         format-version
         stage-version
         make-cache
         read-flow-cache
         write-flow-cache!
         cache-fresh?
         cache-value
         cache-stamp-string)

;; 这个文件格式（头部结构）变了就 +1
(define format-version 1)

;; 流水线语义变了就 +1（改 compiler/ loko-compatibility/ amd64-asm/ 里的东西时）。
;; 忘了 +1 也不会错：下面还有源文件指纹兜着。
(define stage-version 1)

;; 指纹覆盖的目录（相对 amd64/）
(define pipeline-roots
  '("compiler" "loko-compatibility" "amd64-asm" "amd64-help" "amd64-elf"))

;; ---------------------------------------------------------------------------
;; 指纹
;; ---------------------------------------------------------------------------

(define (source-fingerprint root)
  (define-values (newest count)
    (for/fold ([newest 0] [count 0])
              ([dir-name (in-list pipeline-roots)])
      (define dir (build-path root dir-name))
      (if (directory-exists? dir)
          (for/fold ([newest newest] [count count]) ([f (in-directory dir)])
            (define s (path->string f))
            (if (and (file-exists? f)
                     (regexp-match? #rx"[.]rkt$" s)
                     (not (regexp-match? #rx"(^|/)compiled/" s)))
                (values (max newest (file-or-directory-modify-seconds f))
                        (add1 count))
                (values newest count)))
          (values newest count))))
  (list newest count))

(define (dump-identity dump-path)
  (list (path->string (simplify-path (path->complete-path dump-path)))
        (file-size dump-path)
        (file-or-directory-modify-seconds dump-path)))

;; ---------------------------------------------------------------------------
;; 读写
;; ---------------------------------------------------------------------------

(define (cache-file-path dir last-stage)
  (build-path dir (format "~a.rktd" last-stage)))

;; cache 是一个普通 list，头部标签之后就是一张 alist：
;;   (amd64-flow-cache (format 1) (dump …) (pipeline …) (flow …) (values …))
(define (make-cache dump-path root flow names->values)
  (list 'amd64-flow-cache
        (cons 'format format-version)
        (cons 'dump (dump-identity dump-path))
        (list 'pipeline stage-version (source-fingerprint root))
        (cons 'flow flow)
        (cons 'values (for/list ([(k v) (in-hash names->values)]) (cons k v)))))

;; 读不回来（旧格式 / 截断 / 不是缓存文件）一律当成"没有缓存"，不报错：
;; 缓存是加速手段，不能因为它坏了就让构建失败。
(define (read-flow-cache path)
  (and (file-exists? path)
       (with-handlers ([exn:fail? (lambda (_e) #f)])
         (define v (call-with-input-file path
                     (lambda (in) (deserialize (read in)))))
         (and (pair? v)
              (eq? (car v) 'amd64-flow-cache)
              (let ([f (assq 'format (cdr v))])
                (and f (= (cdr f) format-version)))
              (assq 'values (cdr v))
              v))))

(define (write-flow-cache! path cache)
  (define tmp (string->path (format "~a.tmp" path)))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out)
      ;; 这个 Racket 的 serialize 返回的是"可写的 serialized 值"，用 write 包一层。
      (write (serialize cache) out)))
  (rename-file-or-directory tmp path #t))

(define (cache-value cache name [default (lambda () (error 'flow-cache "cache 里没有 ~a" name))])
  (define p (assq name (cdr (assq 'values (cdr cache)))))
  (if p (cdr p) default))

;; ---------------------------------------------------------------------------
;; 失效
;; ---------------------------------------------------------------------------

;; 返回 (values 可用? 原因)
(define (cache-fresh? cache dump-path root flow)
  (cond
    [(not (= (cadr (assq 'pipeline (cdr cache))) stage-version))
     (values #f "stage-version 变了")]
    [(not (equal? (cdr (assq 'flow (cdr cache))) flow))
     (values #f "选的是另一组层（flow 不同）")]
    [(not (equal? (cdr (assq 'dump (cdr cache))) (dump-identity dump-path)))
     (values #f "dump 变了")]
    [(not (equal? (caddr (assq 'pipeline (cdr cache))) (source-fingerprint root)))
     (values #f "流水线源码改过了")]
    [else (values #t "命中")]))

(define (cache-stamp-string cache)
  (define dump (cdr (assq 'dump (cdr cache))))
  (define pipe (cdr (assq 'pipeline (cdr cache))))
  (define flow (cdr (assq 'flow (cdr cache))))
  (format "flow=~a dump=~a(~a B) stage-version=~a fingerprint=~a"
          flow (car dump) (cadr dump) (car pipe) (cadr pipe)))
