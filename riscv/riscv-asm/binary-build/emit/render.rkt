#lang racket/base

(require racket/string)

(define (render-header require-specs)
  (if (null? require-specs)
      "#lang racket/base"
      (string-join
       (list "#lang racket/base"
             ""
             (format "(require ~a)" (string-join require-specs "\n         ")))
       "\n")))

(define (render-definitions definitions)
  (string-join definitions "\n"))

(define (render-provide names)
  (cond
    [(null? names) "(provide)"]
    [else (format "(provide\n ~a)" (string-join names "\n "))]))

(define (render-module require-specs definitions provide-names)
  (string-append
   (string-join
    (list (render-header require-specs)
          (render-definitions definitions)
          (render-provide provide-names))
    "\n\n")
   "\n"))

(provide render-module)
