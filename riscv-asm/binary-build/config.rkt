#lang racket/base

(require racket/path
         racket/string
         "paths.rkt")

(struct build-options (opcodes-dir output-dir clean-only?) #:transparent)

(define (default-build-options)
  (build-options default-opcodes-dir default-output-dir #f))

(define (usage)
  (string-join
   (list
    "usage: racket binary-build/main.rkt [options]"
    ""
    "  --opcodes DIR   directory containing riscv-opcodes extension files"
    "  --output DIR    output package directory"
    "  --clean          only remove the generated lib/ and gen/ directories"
    "  --help           show this message")
   "\n"))

(define (parse-command-line args)
  (let loop ([args args]
             [opts (default-build-options)])
    (cond
      [(null? args) opts]
      [(string=? (car args) "--help")
       (displayln (usage))
       (exit 0)]
      [(string=? (car args) "--opcodes")
       (when (null? (cdr args))
         (error 'parse-command-line "--opcodes requires a directory"))
       (loop (cddr args)
             (struct-copy build-options opts
                          [opcodes-dir (path->complete-path (cadr args))]))]
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
         build-options-opcodes-dir
         build-options-output-dir
         build-options-clean-only?
         default-build-options
         parse-command-line
         usage)
