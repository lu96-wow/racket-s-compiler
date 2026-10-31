#lang racket
;;; amd64/tools/write-cached-elf.rkt
;;;
;;; 从 cache-loko-build.rkt 的缓存生成 ELF，不重跑编译流水线。
;;;
;;; 用法：
;;;   racket tools/write-cached-elf.rkt <cache.sexp> <out.elf>

(require racket/cmdline
         (file "../amd64-elf/writer.rkt")
         (only-in (file "../loko-compatibility/image/plan.rkt")
                  loko-linux-image-plan-for))

(define (cache-field cache key)
  (cadr (assq key (cdr cache))))

(command-line
 #:program "write-cached-elf"
 #:args (cache-path out-path)
 (define cache (call-with-input-file cache-path read))
 (define build (cache-field cache 'build))
 (define symbols (cache-field cache 'symbols))
 (define declared-plan (cache-field cache 'image-plan))
 (define plan (loko-linux-image-plan-for symbols declared-plan))
 (define image (write-elf build symbols #:plan plan))
 (define bytes (cdr (assoc 'bytes (cdr image))))
 (call-with-output-file out-path #:exists 'replace
   (lambda (out) (write-bytes bytes out)))
 (printf "wrote ~a (~a bytes, entry ~a)\n"
         out-path (bytes-length bytes)
         (cadr (assoc 'entry (cdr image)))))
