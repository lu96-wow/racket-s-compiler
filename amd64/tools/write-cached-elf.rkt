#lang racket
;;; amd64/tools/write-cached-elf.rkt
;;;
;;; 从 cache-loko-layout.rkt 的缓存生成 ELF，不重跑编译流水线。
;;;
;;; 用法：
;;;   racket tools/write-cached-elf.rkt <cache.sexp> <out.elf>

(require racket/cmdline
         (file "../compiler/encode/encode.rkt")
         (file "../amd64-asm/target.rkt")
         (file "../amd64-elf/writer.rkt")
         (only-in (file "../loko-compatibility/image/plan.rkt")
                  choose-loko-linux-image-plan))

(define (cache-field cache key)
  (cadr (assq key (cdr cache))))

(command-line
 #:program "write-cached-elf"
 #:args (cache-path out-path)
 (define cache (call-with-input-file cache-path read))
 (define bound (cache-field cache 'bound-layout))
 (define symbols (cdr (assq 'symbols bound)))
 (define declared-plan (cache-field cache 'image-plan))
 (define plan (choose-loko-linux-image-plan symbols declared-plan))
 (define build (encode-layout target-amd64 bound))
 (define image (write-elf build symbols #:plan plan))
 (define bytes (cadr (assoc 'bytes (cdr image))))
 (call-with-output-file out-path #:exists 'replace
   (lambda (out) (write-bytes bytes out)))
 (printf "wrote ~a (~a bytes, entry ~a)\n"
         out-path (bytes-length bytes)
         (cadr (assoc 'entry (cdr image)))))
