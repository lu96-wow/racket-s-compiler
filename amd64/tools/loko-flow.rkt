#lang racket
;;; amd64/tools/loko-flow.rkt
;;;
;;; 跑 Loko dump 的流水线，并把**这次流水的产物**缓存下来：dump 和流水线都没变
;;; 时，连 dump 都不解析，直接把产物读回来。
;;;
;;; 用法：
;;;   racket tools/loko-flow.rkt [--refresh] [--verify] <dump.sexp> <cache-dir> [层/层组 ...]
;;;
;;; 选项要写在位置参数前面（racket/cmdline 的 `. rest` 之后不再解析选项）。
;;;
;;; 默认层组是 loko-near（历史别名；现在默认就是 near-only）。产物是最后一层的输出：
;;;   encode   -> build（各个段的字节）      缓存文件 <cache-dir>/encode.rktd
;;;   loko-elf -> image（ELF 字节 + 入口）   缓存文件 <cache-dir>/loko-elf.rktd
;;; 其它层组（停在中途的调试用）不缓存。
;;;
;;; 缓存命中时打印一段摘要；没命中则（AMD64_FLOW_TIMING=1 时）打印每层耗时并覆盖缓存。
;;; 失效条件见 tools/flow-cache.rkt 开头。
;;;
;;; 为什么只缓存产物、不缓存中间层：pc-repl 的 dump 有 1.6M 个 item，
;;; 逐层缓存要写 443 MB，命中时 deserialize 要 189 s，而整条流水线从头算
;;; 只要 21 s（dump 解析另算 2.4 s）。缓存中间层是纯负优化。

(require racket/cmdline
         racket/file
         racket/path
         (file "../loko-compatibility/flow.rkt")
         (file "../loko-compatibility/sexp-read.rkt")
         (file "../amd64-asm/target.rkt")
         (file "flow-cache.rkt"))

;; 脚本自己在 amd64/tools 里；流水线源码在 amd64/ 下面（指纹覆盖那几个目录）。
(define here
  (let ([rf (find-system-path 'run-file)])
    (if (file-exists? rf)
        (path-only (simplify-path (path->complete-path rf)))
        (current-directory))))
(define amd64-root (simplify-path (build-path here "..")))

;; 只有这几个层的输出是"镜像产物"，值得缓存。
(define artifact-stages '(encode loko-elf))

(define (field s k)
  (define p (assq k (cdr s)))
  (and p (cadr p)))

;; 缓存只留"产物"需要的东西：image 里的 symbols/sections 是给校验用的，
;; 22 万个符号没必要每次序列化一遍。
(define (compact name value)
  (case name
    [(image) (list 'image
                   (assq 'entry (cdr value))
                   (assq 'bytes (cdr value)))]
    [else value]))

(define (summarize name value)
  (case name
    [(build)
     (for ([s (in-list (cdr value))])
       (printf "  ~a kind=~a start=#x~x size=~a bytes=~a\n"
               (field s 'name) (field s 'kind) (field s 'start) (field s 'size)
               (bytes-length (field s 'bytes))))]
    [(image)
     (printf "  image: ~a bytes, entry #x~x\n"
             (bytes-length (field value 'bytes)) (field value 'entry))]
    [else (printf "  ~a: ok\n" name)]))

(define refresh? #f)
(define verify? #f)

(command-line
 #:program "loko-flow"
 #:once-each
 [("--refresh") "忽略已有缓存，重跑流水线" (set! refresh? #t)]
 [("--verify") "命中缓存后仍重跑一遍，核对产物与缓存相同" (set! verify? #t)]
 #:args (dump-path cache-dir . selector-args)
 (define dump (simplify-path (path->complete-path (string->path dump-path))))
 (define dir (string->path cache-dir))
 (define selector (if (null? selector-args)
                      '(loko-near)
                      (for/list ([s (in-list selector-args)]) (string->symbol s))))
 (define names (select-stages selector))
 (define last-stage (last names))
 (define artifact? (and (memq last-stage artifact-stages) #t))
 (define cache-path (cache-file-path dir last-stage))

 (unless (file-exists? dump)
   (error 'loko-flow "没有 dump: ~a（先用 Loko 的 sexp target 导出一份）" dump))
 (unless (directory-exists? dir) (make-directory* dir))
 (printf "flow: ~a\n" names)

 ;; 命中判断只需要 dump 的 stat，不需要解析它
 (define-values (cache why)
   (cond
     [refresh? (values #f "--refresh")]
     [(not artifact?) (values #f (format "最后一层 ~a 不是产物层" last-stage))]
     [else
      (define c (read-flow-cache cache-path))
      (cond
        [(not c) (values #f (format "没有缓存 ~a" (path->string cache-path)))]
        [else
         (define-values (fresh? why) (cache-fresh? c dump amd64-root names))
         (if fresh? (values c "命中") (values #f why))])]))

 (cond
   [cache
    (printf "cache: ~a（~a）\n" (path->string cache-path) (cache-stamp-string cache))
    (for ([p (in-list (cdr (assq 'values (cdr cache))))])
      (summarize (car p) (cdr p)))
    (when verify?
      (printf "verify: 用同一份 dump 重跑，产物必须相同\n")
      (define fresh
        (run-flow target-amd64 names
                  (hash 'loko-source
                        (list 'loko-source (cons 'text (read-dump dump)) '(data)))))
      (for ([p (in-list (cdr (assq 'values (cdr cache))))])
        (unless (equal? (cdr p) (compact (car p) (hash-ref fresh (car p))))
          (error 'loko-flow
                 "缓存里的 ~a 与重跑结果不同 —— 缓存键漏了什么" (car p)))
      (printf "verify: ok\n")))]
   [else
    (printf "cache: miss（~a）\n" why)
    (define started (current-inexact-milliseconds))
    (define ctx
      (run-flow target-amd64 names
                (hash 'loko-source
                      (list 'loko-source (cons 'text (read-dump dump)) '(data)))))
    (define out-names (core:stage-provides (hash-ref stage-table last-stage)))
    (define produced
      (for/hash ([n (in-list out-names)]) (values n (compact n (hash-ref ctx n)))))
    (for ([(k v) (in-hash produced)]) (summarize k v))
    (define elapsed (round (- (current-inexact-milliseconds) started)))
    (cond
      [(not artifact?)
       (printf "（~a 不是产物层，不写缓存；耗时 ~a ms）\n" last-stage elapsed)]
      [else
       (write-flow-cache! cache-path (make-cache dump amd64-root names produced))
       (printf "cache: 写入 ~a（流水线 ~a ms）\n" (path->string cache-path) elapsed)])]))
