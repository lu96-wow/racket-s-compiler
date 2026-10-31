#lang racket
;;; amd64/compiler/test/end-to-end.rkt

(require rackunit
         "../../amd64-asm/target.rkt"
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

(define measured (layout-flat-items target-amd64 items spec))
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
(define sym-measured (layout-flat-items target-amd64 sym-items spec))
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
(define byte-measured (layout-flat-items target-amd64 byte-items spec))
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
(define prefix-measured (layout-flat-items target-amd64 prefix-items spec))
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
(define sse-measured (layout-flat-items target-amd64 sse-items spec))
(check-equal? (cdr (assq 'problems sse-measured)) '())
(define sse-bound (bind-labels sse-measured))
(check-equal? (cdr (assq 'problems sse-bound)) '())
(define sse-build (encode-layout target-amd64 sse-bound))
(check-equal? (cddr (car (cdr sse-build)))
              '((kind code)
                (start #x200000)
                (size 10)
                (bytes #"\xf3\x0f\x10\xca\x66\x0f\x7f\x04\x24\xc3")))

;; `$` is the current item address in both code and data
(define current-ip-items
  '((label text)
    (mov rax (b64 (disp $)))
    (ret)
    (label data)
    (value 8 $)))
(define current-ip-measured
  (layout-flat-items target-amd64 current-ip-items spec))
(check-equal? (cdr (assq 'problems current-ip-measured)) '())
(define current-ip-bound (bind-labels current-ip-measured))
(define current-ip-build (encode-layout target-amd64 current-ip-bound))
(check-equal? (cddr (car (cdr current-ip-build)))
              '((kind code)
                (start #x200000)
                (size 9)
                (bytes #"H\x8b\x04%\x00\x00 \x00\xc3")))
(check-equal? (cddr (cadr (cdr current-ip-build)))
              '((kind data)
                (start #x300000)
                (size 8)
                (bytes #"\x00\x00\x30\x00\x00\x00\x00\x00")))

;; symbolic bit expressions resolve in data values
(define bits-items
  '((label data)
    (value 8 (bitwise-ior (data) 1))
    (value 8 (ash (data) 1))))
(define bits-measured (layout-flat-items target-amd64 bits-items spec))
(check-equal? (cdr (assq 'problems bits-measured)) '())
(define bits-bound (bind-labels bits-measured))
(define bits-build (encode-layout target-amd64 bits-bound))
(check-equal? (cddr (cadr (cdr bits-build)))
              '((kind data)
                (start #x300000)
                (size 16)
                (bytes #"\x01\x00\x30\x00\x00\x00\x00\x00\x00\x00\x60\x00\x00\x00\x00\x00")))

;; hole: layout assigns addresses, encode emits no file bytes
(define bss-spec
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x200100) (align 16))
     (segment (name bss) (kind hole) (start #x300000) (end #x301000) (align 16)))
    (place text (text))
    (place bss (bss) (common))))
(define bss-items
  '((label text) (ret)
    (label bss) (reserve 3) (align 16)
    (label common) (reserve 32)))
(define bss-measured (layout-flat-items target-amd64 bss-items bss-spec))
(check-equal? (cdr (assq 'problems bss-measured)) '())
(define bss-bound (bind-labels bss-measured))
(check-equal? (cdr (assq 'symbols bss-bound))
              '((symbol (text) text 0 #x200000)
                (symbol (bss) bss 0 #x300000)
                (symbol (common) bss 16 #x300010)))
;; align 在 hole 段里归一化成 reserve: 位置推进, 但没有字节
(define bss-seg (cadr (cdr (assq 'segments bss-measured))))
(check-equal? (map caddr (cdr (assq 'items (cdr bss-seg))))
              '((reserve 3) (reserve 13) (reserve 32)))

(define bss-build (encode-layout target-amd64 bss-bound))
(check-equal? (cddr (cadr (cdr bss-build)))
              '((kind hole)
                (start #x300000)
                (size 48)
                (bytes #"")))

;; hole 段里出现要写字节的 item: layout 和 encode 对"这段是不是洞"理解不一致
(define bad-hole-layout
  (list (list 'phase 'bound)
        (cons 'segments
              (list (list 'segment
                          (list 'name 'bss) (list 'kind 'hole)
                          (list 'start #x300000) (list 'end #x301000) (list 'align 16)
                          (cons 'items '((offset 0 (pad 4))))
                          (list 'size 4))))
        (cons 'anchors '())
        (cons 'symbols '())
        (cons 'requests '())
        (cons 'problems '())))

(check-exn exn:fail? (lambda () (encode-layout target-amd64 bad-hole-layout)))

;; data items are allowed inside a code segment (headers, tables, ...)
(define mixed-items
  '((label text)
    (value 4 #x12345678)
    (ret)))
(define mixed-measured (layout-flat-items target-amd64 mixed-items spec))
(check-equal? (cdr (assq 'problems mixed-measured)) '())
(define mixed-bound (bind-labels mixed-measured))
(define mixed-build (encode-layout target-amd64 mixed-bound))
(check-equal? (cddr (car (cdr mixed-build)))
              '((kind code)
                (start #x200000)
                (size 5)
                (bytes #"\x78\x56\x34\x12\xc3")))

;; bind-labels is the final value-width check
(define bad-value-items '((label data) (value 1 300)))
(define bad-value-measured (layout-flat-items target-amd64 bad-value-items spec))
(define bad-value-bound (bind-labels bad-value-measured))
(check-true
 (for/or ([p (in-list (cdr (assq 'problems bad-value-bound)))])
   (eq? (car p) 'value-out-of-range)))
