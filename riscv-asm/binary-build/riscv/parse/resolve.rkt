#lang racket/base

(require racket/list
         "struct.rkt")

;; ============================================================
;; 扩展依赖解析
;;
;; 把一个扩展文件展开成最终要生成的 instruction-def 列表：
;;   standard → imports → pseudo
;; 同模块内同名时保留第一次出现的定义。
;; ============================================================

(define (find-instruction defs name)
  (for/first ([idef (in-list defs)]
              #:when (equal? (instruction-def-name idef) name))
    idef))

(define (resolve-imports extension-file extension-map)
  (for/list ([im (in-list (extension-file-imports extension-file))])
    (define source-extension (import-def-source-extension im))
    (define instruction-name (import-def-instruction-name im))
    (define source-file (hash-ref extension-map source-extension #f))
    (unless source-file
      (error 'resolve-imports
             "cannot resolve import ~a::~a"
             source-extension instruction-name))
    (define idef
      (find-instruction (extension-file-standard source-file)
                        instruction-name))
    (unless idef
      (error 'resolve-imports
             "instruction ~a::~a not found in ~a"
             source-extension
             instruction-name
             (extension-file-path source-file)))
    idef))

(define (add-unique defs seen idef)
  (define name (instruction-def-name idef))
  (cond
    [(hash-has-key? seen name) (values defs seen)]
    [else
     (hash-set! seen name #t)
     (values (cons idef defs) seen)]))

(define (prepare-extension-defs extension-file extension-map)
  (define seen (make-hash))
  (define-values (with-standard seen*)
    (for/fold ([defs '()] [seen seen])
              ([idef (in-list (extension-file-standard extension-file))])
      (add-unique defs seen idef)))
  (define-values (with-imports seen**)
    (for/fold ([defs with-standard] [seen seen*])
              ([idef (in-list (resolve-imports extension-file extension-map))])
      (add-unique defs seen idef)))
  (define-values (all _seen)
    (for/fold ([defs with-imports] [seen seen**])
              ([pseudo (in-list (extension-file-pseudo extension-file))])
      (add-unique defs seen (pseudo-def-instruction pseudo))))
  (reverse all))

(provide find-instruction
         resolve-imports
         prepare-extension-defs)
