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

;; prefix forms must resolve symbolic memory operands inside the inner instruction
(define prefix-items
  '((label text)
    (prefix lock (xadd (b64 (disp (data))) rbx))
    (ret)
    (label data)
    (value 8 0)))
(define prefix-measured (layout-items target-amd64 prefix-items spec))
(check-equal? (cdr (assq 'problems prefix-measured)) '())
(define prefix-bound (bind-labels prefix-measured))
(check-equal? (cdr (assq 'problems prefix-bound)) '())
(define prefix-build (encode-layout target-amd64 prefix-bound))
(check-equal? (cddr (car (cdr prefix-build)))
              '((kind code)
                (start #x200000)
                (size 11)
                (bytes #"\xf0H\x0f\xc1\x1c%\x00\x00\x30\x00\xc3")))

;; SSE / XMM and b128 memory in the layout -> encode path
(define sse-items
  '((label text)
    (movss xmm1 xmm2)
    (movdqa (b128 (base rsp) (disp 0)) xmm0)
    (ret)))
(define sse-measured (layout-items target-amd64 sse-items spec))
(check-equal? (cdr (assq 'problems sse-measured)) '())
(define sse-bound (bind-labels sse-measured))
(check-equal? (cdr (assq 'problems sse-bound)) '())
(define sse-build (encode-layout target-amd64 sse-bound))
(check-equal? (cddr (car (cdr sse-build)))
              '((kind code)
                (start #x200000)
                (size 10)
                (bytes #"\xf3\x0f\x10\xca\x66\x0f\x7f\x04\x24\xc3")))

;; bind-labels is the final value-width check
(define bad-value-items '((label data) (value 1 300)))
(define bad-value-measured (layout-items target-amd64 bad-value-items spec))
(define bad-value-bound (bind-labels bad-value-measured))
(check-true
 (for/or ([p (in-list (cdr (assq 'problems bad-value-bound)))])
   (eq? (car p) 'value-out-of-range)))
