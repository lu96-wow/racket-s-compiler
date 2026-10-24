#lang racket/base

;; ============================================================
;; Build orchestration
;; ============================================================

(require racket/file
         racket/list
         racket/path
         racket/string
         "../config.rkt"
         "../model.rkt"
         "../parse.rkt"
         "../resolve.rkt"
         "../paths.rkt"
         "../layout/modules.rkt"
         "fields.rkt"
         "instruction.rkt"
         "metadata.rkt")

(define (delete-tree! path)
  (when (directory-exists? path)
    (delete-directory/files path)))

(define (clean-output! root)
  (define complete (simplify-path (path->complete-path root)))
  (define protected
    (list (simplify-path (path->complete-path project-root))
          (simplify-path (path->complete-path binary-build-dir))))
  (when (member complete protected equal?)
    (error 'clean-output! "refusing to clean protected path: ~a" complete))
  (delete-tree! (generated-lib-dir root))
  (delete-tree! (generated-gen-dir root)))

(define (delete-compiled-subdirs! dir)
  (for ([entry (in-list (directory-list dir))])
    (define child (build-path dir entry))
    (cond
      [(and (directory-exists? child)
            (equal? (path->string (file-name-from-path child)) "compiled"))
       (delete-directory/files child)]
      [(directory-exists? child)
       (delete-compiled-subdirs! child)]
      [else (void)])))

(define (copy-runtime-lib! root)
  (make-directory* root)
  (define dest (generated-lib-dir root))
  (delete-tree! dest)
  (copy-directory/files runtime-lib-source-dir dest)
  ;; Never ship bytecode/dependency caches copied from a previous local run.
  (delete-compiled-subdirs! dest))

(define (make-output-dirs! root)
  (make-directory* (raw-instruction-dir root))
  (make-directory* (rebuilt-instruction-dir root))
  (make-directory* (info-dir root))
  (make-directory* (rebuilt-field-dir root)))

(define (raw-field-source-files)
  (define dir (build-path runtime-lib-source-dir "riscv" "raw"))
  (sort
   (for/list ([name (in-list (directory-list dir))]
              #:when (and (file-exists? (build-path dir name))
                          (string-suffix? (path->string name) ".rkt")))
     (path->string name))
   string<?))

(define (validate-field-modules!)
  (define registered (sort field-module-files string<?))
  (define actual (raw-field-source-files))
  (unless (equal? registered actual)
    (error 'validate-field-modules!
           "field module registry mismatch: registered ~a, files ~a"
           registered
           actual)))

(define (write-file! path content)
  (make-directory* (path-only path))
  (display-to-file content path #:exists 'replace))

(define (extension-map-of parsed-files)
  (make-immutable-hash
   (for/list ([parsed (in-list parsed-files)])
     (cons (extension-stem (extension-file-path parsed)) parsed))))

(define (skipped-name s) (skipped-definition-name s))
(define (skipped-reason s) (skipped-definition-reason s))

(define (build-all [opts (default-build-options)])
  (define root (build-options-output-dir opts))
  (define opcodes-dir (build-options-opcodes-dir opts))

  ;; ----------------------------------------------------------
  ;; source -> parse -> resolve
  ;; ----------------------------------------------------------
  (define source-files
    (ratified-extension-source-files opcodes-dir))
  (define parsed-files
    (for/list ([path (in-list source-files)])
      (parse-extension-file path)))
  (define ext-map (extension-map-of parsed-files))
  (define ext->defs (make-hash))

  (define-values (standard-count pseudo-count import-count emitted-count skipped)
    (for/fold ([standard 0]
               [pseudo 0]
               [imports 0]
               [emitted 0]
               [skipped '()])
              ([parsed (in-list parsed-files)])
      (define ext (extension-stem (extension-file-path parsed)))
      (define-values (resolved-defs skipped-here)
        (prepare-extension-defs parsed ext-map))
      (hash-set! ext->defs ext resolved-defs)
      (values (+ standard (length (extension-file-standard parsed)))
              (+ pseudo (length (extension-file-pseudo parsed)))
              (+ imports (length (extension-file-imports parsed)))
              (+ emitted (length resolved-defs))
              (append skipped-here skipped))))

  ;; ----------------------------------------------------------
  ;; output
  ;;
  ;; Nothing is written until every source file has parsed and resolved.
  ;; This keeps the output directory untouched on source errors.
  ;; ----------------------------------------------------------
  (validate-field-modules!)
  (clean-output! root)
  (copy-runtime-lib! root)
  (make-output-dirs! root)
  (gen-rebuilt-field-files! root)

  (for ([parsed (in-list parsed-files)])
    (define ext (extension-stem (extension-file-path parsed)))
    (define resolved-defs (hash-ref ext->defs ext))
    (define idefs
      (for/list ([resolved (in-list resolved-defs)])
        (resolved-def-definition resolved)))

    (define raw-path (raw-output-path root ext))
    (define rebuilt-path (rebuilt-output-path root ext))
    (define info-path (info-output-path root ext))

    (write-file! raw-path
                 (gen-raw-file-content idefs raw-path root))
    (write-file! rebuilt-path
                 (gen-rebuilt-file-content idefs rebuilt-path root))
    (write-file! info-path
                 (gen-info-file-content ext resolved-defs info-path root)))

  (write-file! (extensions-output-path root)
               (gen-extension-list-content ext->defs))
  (write-file! (instruction-extensions-output-path root)
               (gen-extension-map-content ext->defs))

  ;; ----------------------------------------------------------
  ;; summary
  ;; ----------------------------------------------------------
  (define skipped-unique
    (sort (remove-duplicates skipped
                             (lambda (a b)
                               (equal? (list (skipped-name a) (skipped-reason a))
                                       (list (skipped-name b) (skipped-reason b)))))
          string<?
          #:key skipped-name))

  (printf "Generated ~a ratified extensions\n" (length source-files))
  (printf "  standard definitions:  ~a\n" standard-count)
  (printf "  pseudo definitions:    ~a\n" pseudo-count)
  (printf "  import definitions:    ~a\n" import-count)
  (printf "  emitted per extension: ~a\n" emitted-count)
  (printf "  skipped duplicates:    ~a\n" (length skipped-unique))
  (for ([s (in-list skipped-unique)])
    (printf "    ~a: ~a\n" (skipped-name s) (skipped-reason s)))
  (printf "  package root:          ~a\n" (path->string root))
  (void))

(provide build-all
         clean-output!)
