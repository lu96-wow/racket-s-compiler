#lang racket/base

(require racket/path
         racket/string
         "struct.rkt"
         "line.rkt")

;; ============================================================
;; 文件级解析
;; ============================================================

(define (parse-extension-file path)
  (with-input-from-file path
    (lambda ()
      (define standard '())
      (define pseudo '())
      (define imports '())

      (for ([line (in-lines)]
            [line-number (in-naturals 1)])
        (define trimmed (string-trim line))
        (cond
          [(comment-or-blank? trimmed) (void)]
          [(string-prefix? trimmed "$pseudo_op")
           (set! pseudo
                 (cons (parse-pseudo-line trimmed line-number) pseudo))]
          [(string-prefix? trimmed "$import")
           (set! imports
                 (cons (parse-import-line trimmed line-number) imports))]
          [(string-prefix? trimmed "$")
           (error 'parse-extension-file
                  "unknown directive on line ~a of ~a: ~a"
                  line-number path trimmed)]
          [else
           (define result (parse-line trimmed line-number))
           (unless result
             (error 'parse-extension-file
                    "unexpected parse failure on line ~a of ~a"
                    line-number path))
           (set! standard (cons result standard))]))

      (extension-file path
                      (reverse standard)
                      (reverse pseudo)
                      (reverse imports)))))

(define (parse-file path)
  (extension-file-standard (parse-extension-file path)))

(define (make-extension-source path)
  (define stem (path-replace-suffix (file-name-from-path path) ""))
  (define type-sym (string->symbol (path->string stem)))
  (extension-source path type-sym))

(provide parse-extension-file
         parse-file
         make-extension-source)
