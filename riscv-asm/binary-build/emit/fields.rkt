#lang racket/base

;; ============================================================
;; Generate rebuilt field modules from the group registry.
;;
;; Grouping knowledge has exactly one source: binary-build/layout/groups.rkt.
;; ============================================================

(require racket/file
         racket/list
         racket/path
         racket/string
         "../layout/groups.rkt"
         "../paths.rkt"
         "render.rkt")

(define (define-combine g)
  (format "(define ~a\n  (combine ~a))"
          (operand-group-name g)
          (string-join
           (for/list ([token (in-list (operand-group-raw-tokens g))])
             (string-append "raw:" token))
           "\n           ")))

(define (module-symbol module)
  (string->symbol
   (path->string (path-replace-suffix (file-name-from-path module) ""))))

(define (module-definitions module)
  (for/list ([g (in-list (groups-for-module (module-symbol module)))])
    (define-combine g)))

(define (module-provides module)
  (for/list ([g (in-list (groups-for-module (module-symbol module)))])
    (operand-group-name g)))

(define (gen-rebuilt-field-file root module)
  (define output-path (rebuilt-field-path root module))
  (define content
    (render-module
     (rebuilt-field-require-specs output-path root module)
     (module-definitions module)
     (module-provides module)))
  (make-directory* (path-only output-path))
  (display-to-file content output-path #:exists 'replace))

(define (gen-rebuilt-field-files! root)
  (for ([module (in-list field-module-names)])
    (gen-rebuilt-field-file root module)))

(provide gen-rebuilt-field-files!)
