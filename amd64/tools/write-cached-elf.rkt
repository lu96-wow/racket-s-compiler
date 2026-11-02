#lang racket
;;; amd64/tools/write-cached-elf.rkt
;;;
;;; 从一个 `elf` 流水线缓存里取出 ELF 字节写到文件，不重跑编译流水线。
;;;
;;; 用法：
;;;   racket tools/loko-flow.rkt <dump.sexp> <cache-dir> elf    # 先产缓存
;;;   racket tools/write-cached-elf.rkt <cache-dir>/loko-elf.rktd <out.elf>
;;;
;;; 改 ELF writer（amd64-elf/）之后缓存会自动失效，所以这个工具只用于
;;; "产物已经跑过一次、只想重新落盘"的场合（比如换输出路径、做两份对比）。

(require racket/cmdline
         racket/file
         (file "flow-cache.rkt"))

(command-line
 #:program "write-cached-elf"
 #:args (cache-path out-path)
 (define cache (read-flow-cache (string->path cache-path)))
 (unless cache
   (error 'write-cached-elf
          "~a 不是 flow-cache 文件（用 tools/loko-flow.rkt … elf 生成）" cache-path))
 (define image (cache-value cache 'image (lambda () #f)))
 (unless image
   (error 'write-cached-elf "~a 里没有 loko-elf 的产物（image）" cache-path))
 (define (field k) (cadr (assoc k (cdr image))))
 (define bytes (field 'bytes))
 (call-with-output-file out-path #:exists 'replace
   (lambda (out) (write-bytes bytes out)))
 (printf "wrote ~a (~a bytes, entry #x~x)\n"
         out-path (bytes-length bytes) (field 'entry)))
