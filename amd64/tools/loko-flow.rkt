#lang racket
;;; amd64/tools/loko-flow.rkt
;;;
;;; 跑 Loko dump 的流水线，但把每一层的输出缓存到磁盘：已经算过（且比 dump
;;; 新）的层直接读回来，只跑缺的层。
;;;
;;; 为什么需要：pc-repl 这种裸机镜像的 dump 有 160 万个 item，
;;; `loko-lower`（寄存器分配）要 10 分钟，`analyze` 也要几分钟。改 encoder /
;;; ELF writer 的时候没必要每次重跑前面那些纯函数层。
;;;
;;; 用法：
;;;   racket tools/loko-flow.rkt <dump.sexp> <cache-dir> [层或层组 ...]
;;;
;;; 默认层组是 loko-near（short 起步不 relax，只 layout 一次）。
;;; 缓存文件是 <cache-dir>/<层名>.sexp，内容是这一层产出的 (名字 . 值) 表；
;;; 二进制段用 #"..."> 打印，Racket 可以直接读回。
;;;
;;; 环境变量 AMD64_FLOW_TIMING=1 时每层打印耗时（和 run-flow 一致）。

(require racket/cmdline
         (file "../loko-compatibility/flow.rkt")
         (file "../amd64-asm/target.rkt"))

(define (read-items path)
  (call-with-input-file path
    (lambda (in)
      (let loop ([items '()])
        (define x (read in))
        (if (eof-object? x) (reverse items) (loop (cons x items)))))))

(define (cache-path dir stage)
  (build-path dir (string-append (symbol->string stage) ".sexp")))

(define (fresh? cache dump)
  (and (file-exists? cache)
       (>= (file-or-directory-modify-seconds cache)
           (file-or-directory-modify-seconds dump))))

(define (save! path produced)
  (define tmp (string->path (format "~a.tmp" path)))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out)
      (parameterize ([print-graph #t] [print-struct #t])
        (write (for/list ([(k v) (in-hash produced)]) (cons k v)) out))))
  (rename-file-or-directory tmp path #t))

(define (load-into! ctx path)
  (call-with-input-file path
    (lambda (in)
      (for ([p (in-list (read in))]) (hash-set! ctx (car p) (cdr p))))))

(command-line
 #:program "loko-flow"
 #:args (dump-path cache-dir . stages)
 (define dump (string->path dump-path))
 (define dir (string->path cache-dir))
 (unless (directory-exists? dir) (make-directory* dir))
 (define selector (if (null? stages)
                      '(loko-near)
                      (for/list ([s (in-list stages)]) (string->symbol s))))
 (define names (select-stages selector))
 (printf "stages: ~a\n" names)

 (define ctx (make-hash))
 ;; 源: 先把 dump 变成 (loko-source …)，它是 loko-compat 的输入
 (hash-set! ctx 'loko-source (list 'loko-source (cons 'text (read-items dump)) '(data)))

 (for ([stage (in-list names)])
   (define cache (cache-path dir stage))
   (cond
     [(and (not (eq? stage 'loko-compat)) (fresh? cache dump))
      (load-into! ctx cache)
      (printf "  ~a: cached\n" stage)]
     [else
      (define out (run-stage target-amd64 stage (for/list ([(k v) (in-hash ctx)]) (cons k v))))
      (for ([(k v) (in-hash out)]) (hash-set! ctx k v))
      (save! cache out)
      (printf "  ~a: ran\n" stage)]))

 (define image (hash-ref ctx 'image (lambda () #f)))
 (cond
   [image
    (define segments (cdr (assq 'segments (cdr image))))
    (printf "image: ~a segment(s)\n" (length segments))
    (for ([s (in-list segments)])
      (printf "  ~a kind=~a start=~a size=~a bytes=~a\n"
              (cadr (assq 'name (cdr s))) (cadr (assq 'kind (cdr s)))
              (cadr (assq 'start (cdr s))) (cadr (assq 'size (cdr s)))
              (bytes-length (cadr (assq 'bytes (cdr s))))))]
   [else (printf "no image (selector stops before encode)\n")]))
