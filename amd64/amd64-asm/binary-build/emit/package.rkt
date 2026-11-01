#lang racket/base

(require racket/file
         racket/list
         racket/path
         racket/string
         "../config.rkt"
         "../model.rkt"
         "../parse.rkt"
         "../paths.rkt"
         "../resolve.rkt"
         "table.rkt")

(define upstream-commit "fbdc88565ccccfa0e8c69b21b1953d1eded02e89")

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
  (delete-tree! (generated-gen-dir root)))

(define (write-file! path content)
  (make-directory* (path-only path))
  ;; Write a sibling first so a failure never leaves a truncated table.
  (define tmp (string->path (format "~a.tmp" (path->string path))))
  (display-to-file content tmp #:exists 'replace)
  (rename-file-or-directory tmp path #t))

(define (skip-summary skipped)
  (define grouped
    (group-by skipped-reason skipped))
  (sort grouped > #:key length))

(define (build-all [opts (default-build-options)])
  (define source (build-options-source-path opts))
  (define root (build-options-output-dir opts))
  (unless (file-exists? source)
    (error 'build-all "NASM source snapshot does not exist: ~a" source))

  (define-values (raws parse-skipped) (parse-source-file source))
  (define-values (forms resolve-skipped) (resolve-source raws))

  (when (null? forms)
    (error 'build-all "no supported forms generated from ~a" source))

  (clean-output! root)
  (define table-path (generated-table-path root))
  (write-file! table-path
               (table-content forms
                              (path->string (find-relative-path project-root source))
                              upstream-commit))

  (printf "NASM instruction table\n")
  (printf "  source:               ~a\n" (path->string source))
  (printf "  parsed source lines:  ~a\n" (length raws))
  (printf "  emitted forms:        ~a\n" (length forms))
  (printf "  resolved mnemonics:   ~a\n"
          (length (remove-duplicates (map form-mnemonic forms) eq?)))
  (printf "  rejected parse lines: ~a\n" (length (filter values parse-skipped)))
  (printf "  rejected forms:       ~a\n" (length resolve-skipped))
  (for ([group (in-list (skip-summary resolve-skipped))])
    (printf "    ~a: ~a\n" (length group) (skipped-reason (car group))))
  (printf "  generated:            ~a\n" (path->string table-path))
  (void))

(provide build-all
         clean-output!)
