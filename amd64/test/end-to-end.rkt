#lang racket
;;; amd64/test/end-to-end.rkt

(require rackunit
         "../target.rkt"
         "../layout/layout.rkt"
         "../bind-labels/bind.rkt"
         "../encode/encode.rkt")

(define items
  '((label text)
    (mov rax (b64 (base rbp) (disp -8)))
    (jmp-near (done))
    (add rax 1)
    (label done)
    (ret)
    (label data)
    (value 8 #x1234)))

(define spec
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16))
     (segment (name data) (kind data) (start #x300000) (end #x301000) (align 8)))
    (place text (text))
    (place data (data))))

(define measured (layout-items target-amd64 items spec))
(check-equal? (cdr (assq 'problems measured)) '())

(define bound (bind-labels measured))
(check-equal? (cdr (assq 'symbols bound))
              '((symbol (text) text 0 #x200000)
                (symbol (done) text 13 #x20000d)
                (symbol (data) data 0 #x300000)))

(define build (encode-layout target-amd64 bound))
(check-equal? (cddr (car (cdr build)))
              '((kind code)
                (start #x200000)
                (size 14)
                (bytes #"H\x8bE\xf8\xe9\x04\x00\x00\x00H\x83\xc0\x01\xc3")))
(check-equal? (cddr (cadr (cdr build)))
              '((kind data)
                (start #x300000)
                (size 8)
                (bytes #"\x34\x12\x00\x00\x00\x00\x00\x00")))

(displayln "amd64 end-to-end tests: ok")

;; symbolic memory displacements become fixed disp32 and are resolved at encode
(define sym-items
  '((label text)
    (mov rax (b64 (base rip) (disp (data))))
    (mov rbx (b64 (disp (data))))
    (ret)
    (label data)
    (value 8 #x1234)))
(define sym-measured (layout-items target-amd64 sym-items spec))
(check-equal? (cdr (assq 'requests sym-measured)) '())
(check-equal? (cdr (assq 'problems sym-measured)) '())
(define sym-bound (bind-labels sym-measured))
(define sym-build (encode-layout target-amd64 sym-bound))
(check-equal? (cddr (car (cdr sym-build)))
              '((kind code)
                (start #x200000)
                (size 16)
                (bytes #"H\x8b\x05\xf9\xff\x0f\x00H\x8b\x1c%\x00\x00\x30\x00\xc3")))


;; full unsigned data byte range
(define byte-items '((label data) (value 1 255)))
(define byte-measured (layout-items target-amd64 byte-items spec))
(define byte-bound (bind-labels byte-measured))
(define byte-build (encode-layout target-amd64 byte-bound))
(check-equal? (cddr (car (cdr byte-build)))
              '((kind code) (start #x200000) (size 0) (bytes #"")))
(check-equal? (cddr (cadr (cdr byte-build)))
              '((kind data) (start #x300000) (size 1) (bytes #"\xff")))
