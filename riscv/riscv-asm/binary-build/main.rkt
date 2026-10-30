#lang racket/base

(require "config.rkt"
         "emit/package.rkt")

(define (main args)
  (define opts (parse-command-line args))
  (if (build-options-clean-only? opts)
      (clean-output! (build-options-output-dir opts))
      (build-all opts))
  0)

(module+ main
  (exit (main (vector->list (current-command-line-arguments)))))

(provide main)
