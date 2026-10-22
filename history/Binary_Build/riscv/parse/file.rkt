#lang racket

(require "struct.rkt"
         "line.rkt")

;; ============================================================
;; 文件级操作
;; ============================================================

;; 读取一个源文件，返回解析后的指令列表
(define (parse-file path)
  (with-input-from-file path
    (λ ()
      (for/list ([line (in-lines)]
                 [n (in-naturals 1)]
                 #:when (not (skip-line? line)))
        (let ([result (parse-line (string-trim line) n)])
          (or result
              (error 'parse-file "Unexpected parse failure on line ~a of ~a" n path)))))))

;; 获取源文件路径并关联类型符号
(define (make-extension-source path)
  (define type-sym
    (string->symbol
     (path->string (path-replace-suffix (file-name-from-path path) ""))))
  (extension-source path type-sym))

(provide
 parse-file
 make-extension-source)
