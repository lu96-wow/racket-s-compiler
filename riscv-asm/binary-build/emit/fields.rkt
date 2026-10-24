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

(define (module-file->symbol module-file)
  (string->symbol
   (path->string
    (path-replace-suffix (file-name-from-path module-file) ""))))

(define (module-definitions module-file)
  (for/list ([g (in-list (groups-for-module
                           (module-file->symbol module-file)))])
    (define-combine g)))

(define (module-provides module-file)
  (for/list ([g (in-list (groups-for-module
                           (module-file->symbol module-file)))])
    (operand-group-name g)))

(define (gen-rebuilt-field-file root module-file)
  (define output-path (rebuilt-field-path root module-file))
  (define content
    (render-module
     (rebuilt-field-require-specs output-path root module-file)
     (module-definitions module-file)
     (module-provides module-file)))
  (make-directory* (path-only output-path))
  (display-to-file content output-path #:exists 'replace))

(define (gen-rebuilt-field-files! root)
  (for ([module-file (in-list field-module-files)])
    (gen-rebuilt-field-file root module-file)))

(provide gen-rebuilt-field-files!)
