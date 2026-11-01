#lang racket
;;; amd64/tools/write-flat-image.rkt
;;;
;;; 把 encode 层的缓存写成一个**平铺镜像**（裸机 multiboot 用，没有 ELF 头）。
;;;
;;; 用法：
;;;   racket tools/write-flat-image.rkt <encode 缓存> <输出镜像>
;;;
;;; 缓存由 tools/loko-flow.rkt 产出（<cache-dir>/encode.rktd）。
;;;
;;; 布局规则：段自带地址；按地址顺序把有字节的段摊平，段之间的空隙填 0
;;; （multiboot 加载器加载的是文件里的连续字节，空隙必须真的存在）。
;;; hole 段（bss）不产生文件字节。
(require racket/cmdline
         racket/serialize)

(define (field s k)
  (define p (assq k (cdr s)))
  (and p (cadr p)))

(define (load-build cache-path)
  (define entries
    (call-with-input-file cache-path (lambda (in) (deserialize (read in)))))
  (define p (assq 'build (for/list ([e (in-list entries)]) (cons (car e) (cadr (cdr e))))))
  (unless p (error 'write-flat-image "cache has no encode output: ~a" cache-path))
  (cdr p))

(command-line
 #:program "write-flat-image"
 #:args (cache-path out-path)
 (define build (load-build cache-path))
 (define segments (cdr build))
 (for ([s (in-list segments)])
   (printf "  ~a kind=~a start=#x~x size=~a bytes=~a\n"
           (field s 'name) (field s 'kind) (field s 'start) (field s 'size)
           (bytes-length (field s 'bytes))))

 ;; 只有带字节的段进文件；hole 只在内存里占位。
 (define placed (sort (filter (lambda (s) (positive? (bytes-length (field s 'bytes)))) segments)
                      < #:key (lambda (s) (field s 'start))))
 (unless (pair? placed) (error 'write-flat-image "no materialized segments"))
 (define origin (field (car placed) 'start))
 (define end (for/fold ([e 0]) ([s (in-list placed)])
               (max e (+ (field s 'start) (bytes-length (field s 'bytes))))))
 (define buf (make-bytes (- end origin) 0))
 (for ([s (in-list placed)])
   (bytes-copy! buf (- (field s 'start) origin) (field s 'bytes)))
 (call-with-output-file out-path #:exists 'replace
   (lambda (o) (write-bytes buf o)))
 (printf "wrote ~a: ~a bytes (origin #x~x, end #x~x)\n"
         out-path (bytes-length buf) origin end))
