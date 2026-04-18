#lang racket

(define-syntax-rule (wow a b)
  (+ a b)
  )

(define-syntax wowa
  (syntax-rules ()
    [(_ a b) (+ a b)]
    )
  )

(define-syntax (wowb stx)
  (syntax-case stx ()
    [(_ a b) (syntax (+ a b))]
    )
  )

(define-syntax wowc
  (lambda (stx)
    (syntax-case stx ()
      [(_ a b) (syntax (+ a b))]
      )
    )
  )

(define-syntax my-define-syntax-rule
  (syntax-rules ()
    [(_ (name . pattern) template)
     (define-syntax name
       (syntax-rules ()
         [(_ . pattern) template]
         )
       )
     ]
    )
  )

(my-define-syntax-rule (my-add x y)

                       (+ x y))


(my-add 3 4) ; => 7