#lang racket/base

(require racket/path
         racket/string
         "paths.rkt")

(struct build-options (source-path output-dir clean-only?) #:transparent)

(define (default-build-options)
  (build-options default-source-path default-output-dir #f))

(define (usage)
  (string-join
   (list
    "usage: racket binary-build/main.rkt [options]"
    ""
    "  --source FILE   preprocessed NASM insns.dat snapshot"
    "  --output DIR    output directory for generated Racket data"
    "  --clean         only remove generated/gen/"
    "  --help          show this message")
   "\n"))

(define (parse-command-line args)
  (let loop ([args args]
             [opts (default-build-options)])
    (cond
      [(null? args) opts]
      [(string=? (car args) "--help")
       (displayln (usage))
       (exit 0)]
      [(string=? (car args) "--source")
       (when (null? (cdr args))
         (error 'parse-command-line "--source requires a file"))
       (loop (cddr args)
             (struct-copy build-options opts
                          [source-path (path->complete-path (cadr args))]))]
      [(string=? (car args) "--output")
       (when (null? (cdr args))
         (error 'parse-command-line "--output requires a directory"))
       (loop (cddr args)
             (struct-copy build-options opts
                          [output-dir (path->complete-path (cadr args))]))]
      [(string=? (car args) "--clean")
       (loop (cdr args)
             (struct-copy build-options opts [clean-only? #t]))]
      [else
       (error 'parse-command-line "unknown argument: ~a\n~a"
              (car args) (usage))])))

(provide build-options
         build-options?
         build-options-source-path
         build-options-output-dir
         build-options-clean-only?
         default-build-options
         parse-command-line
         usage)
