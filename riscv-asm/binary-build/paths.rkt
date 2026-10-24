#lang racket/base

;; ============================================================
;; Path and output-layout policy
;;
;; All generated layout knowledge lives here. Emitters ask this module
;; for output paths and for the require specs placed in generated files.
;; ============================================================

(require racket/file
         racket/list
         racket/path
         racket/string
         racket/runtime-path
         "layout/modules.rkt"
         "runtime/lib/layout-spec.rkt")

(define-runtime-path self-path "paths.rkt")
(define binary-build-dir (path-only self-path))
(define project-root (simplify-path (build-path binary-build-dir "..")))

(define default-opcodes-dir
  (build-path project-root "riscv-opcodes" "extensions"))
(define default-output-dir
  (build-path project-root "generated"))

(define source-extension-file-prefix "rv")

(define runtime-lib-source-dir
  (build-path binary-build-dir "runtime" "lib"))

;; ------------------------------------------------------------
;; output layout
;; ------------------------------------------------------------

(define (path-under-root root parts)
  (apply build-path root parts))

(define (generated-lib-dir root)
  (path-under-root root lib-dir-parts))

(define (generated-gen-dir root)
  (path-under-root root gen-dir-parts))

(define (generated-base-path root)
  (build-path (generated-lib-dir root) base-filename))

(define (raw-field-dir root)
  (path-under-root root raw-field-dir-parts))

(define (rebuilt-field-dir root)
  (path-under-root root rebuilt-field-dir-parts))

(define (raw-instruction-dir root)
  (path-under-root root raw-instruction-dir-parts))

(define (rebuilt-instruction-dir root)
  (path-under-root root rebuilt-instruction-dir-parts))

(define (info-dir root)
  (path-under-root root info-dir-parts))

(define (info-lib-dir root)
  (path-under-root root info-lib-dir-parts))

(define (raw-field-path root module-file)
  (build-path (raw-field-dir root) module-file))

(define (rebuilt-field-path root module-file)
  (build-path (rebuilt-field-dir root) module-file))

(define (raw-output-path root extension)
  (build-path (raw-instruction-dir root)
              (extension-module-filename (string->symbol extension))))

(define (rebuilt-output-path root extension)
  (build-path (rebuilt-instruction-dir root)
              (extension-module-filename (string->symbol extension))))

(define (info-output-path root extension)
  (build-path (info-dir root)
              (extension-module-filename (string->symbol extension))))

(define (extensions-output-path root)
  (build-path (info-dir root) extensions-filename))

(define (instruction-extensions-output-path root)
  (build-path (info-dir root) instruction-extensions-filename))

;; ------------------------------------------------------------
;; input discovery
;; ------------------------------------------------------------

(define (extension-stem path)
  (path->string (path-replace-suffix (file-name-from-path path) "")))

(define (ratified-extension-source-files opcodes-dir)
  (define dir (path->complete-path opcodes-dir))
  (unless (directory-exists? dir)
    (error 'ratified-extension-source-files
           "opcodes extension directory does not exist: ~a" dir))
  (sort
   (for/list ([name (in-list (directory-list dir))]
              #:when (let ([p (build-path dir name)])
                       (and (file-exists? p)
                            (not (directory-exists? p))
                            (string-prefix? (path->string name) source-extension-file-prefix))))
     (build-path dir name))
   (lambda (a b) (string<? (path->string a) (path->string b)))))

;; ------------------------------------------------------------
;; require-spec construction
;; ------------------------------------------------------------

(define (relative-module-path from-file to-file)
  (find-relative-path
   (path-only (path->complete-path from-file))
   (path->complete-path to-file)))

(define (require-spec from-file to-file)
  (format "~s" (path->string (relative-module-path from-file to-file))))

(define (prefix-require-spec prefix from-file to-file)
  (format "(prefix-in ~a ~s)"
          prefix
          (path->string (relative-module-path from-file to-file))))

(define (raw-require-specs output-path root)
  (append
   (list (require-spec output-path (generated-base-path root)))
   (for/list ([module-file (in-list field-module-files)])
     (require-spec output-path (raw-field-path root module-file)))))

(define (rebuilt-require-specs output-path root)
  (append
   (list (require-spec output-path (generated-base-path root)))
   (for/list ([module-file (in-list field-module-files)])
     (prefix-require-spec "raw:" output-path
                          (raw-field-path root module-file)))
   (for/list ([module-file (in-list field-module-files)])
     (prefix-require-spec "rebuilt:" output-path
                          (rebuilt-field-path root module-file)))))

(define (rebuilt-field-require-specs output-path root module-file)
  (list
   (require-spec output-path (generated-base-path root))
   (prefix-require-spec "raw:" output-path
                        (raw-field-path root module-file))))

(define (info-require-specs output-path root)
  (list (require-spec output-path
                      (build-path (info-lib-dir root) "struct.rkt"))))

(provide project-root
         binary-build-dir
         runtime-lib-source-dir
         default-opcodes-dir
         default-output-dir
         generated-lib-dir
         generated-gen-dir
         generated-base-path
         raw-field-dir
         rebuilt-field-dir
         raw-instruction-dir
         rebuilt-instruction-dir
         info-dir
         info-lib-dir
         raw-field-path
         rebuilt-field-path
         raw-output-path
         rebuilt-output-path
         info-output-path
         extensions-output-path
         instruction-extensions-output-path

         extension-stem
         ratified-extension-source-files
         relative-module-path
         require-spec
         prefix-require-spec
         raw-require-specs
         rebuilt-require-specs
         rebuilt-field-require-specs
         info-require-specs)
