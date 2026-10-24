#lang racket/base

(require "config.rkt"
         "emit/package.rkt")

(define (main args)
  (define opts (parse-command-line args))
  (build-all opts)
  0)

(module+ main
  (exit (main (vector->list (current-command-line-arguments)))))

(provide main)
