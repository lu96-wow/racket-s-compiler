#lang racket
;;; amd64/compiler/test/flow-test.rkt

(require rackunit
         "../flow/flow.rkt"
         "../../amd64-asm/target.rkt")

(define spec
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16))
     (segment (name data) (kind data) (start #x300000) (end #x301000) (align 8)))
    (place text (text))
    (place data (data))))

(define build
  (compile
   target-amd64
   (list (cons 'rich-data '((label data) (b64 #x1234)))
         (cons 'program-items
               '((label text)
                 (mov rax rbx)
                 (jmp-near (done))
                 (label done)
                 (ret)))
         (cons 'layout-spec spec))))

(check-equal? build
              '(build
                (segment (name text) (kind code) (start #x200000) (size 4)
                         (bytes #"H\x89\xd8\xc3"))
                (segment (name data) (kind data) (start #x300000) (size 8)
                         (bytes #"\x34\x12\x00\x00\x00\x00\x00\x00"))))

;; %init-bss + reserve/bss flows through loko-compat -> compiler
(define bss-spec
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16))
     (segment (name bss) (kind bss) (start #x300000) (end #x301000) (align 16)))
    (place text (text))
    (place bss (bss) (bss-end))))
(define bss-build
  (compile
   target-amd64
   (list (cons 'loko-source
               '(loko-source
                 (text
                  (%origin #x200000)
                  (%mode 64)
                  (%section text)
                  (%label text)
                  (%init-bss)
                  (ret))
                 (data
                  (%section bss)
                  (%label bss)
                  (reserve 32)
                  (%label bss-end))))
         (cons 'layout-spec bss-spec))
   'loko))
(check-equal? (cddr (cadr (cdr bss-build)))
              '((kind bss) (start #x300000) (size 32) (bytes #"")))

(displayln "amd64 flow tests: ok")

;; short branch promoted by relax when the target is out of rel8 range
(define spec2
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16)))
    (place text (text))))
(define build2
  (compile
   target-amd64
   (list (cons 'rich-data '())
         (cons 'program-items
               '((label text)
                 (jcc e (done))
                 (pad 200)
                 (label done)
                 (ret)))
         (cons 'layout-spec spec2))))
(define text2 (cadr build2))
(check-equal? (cadr (assq 'size (cdr text2))) 207)
(check-equal? (subbytes (cadr (assq 'bytes (cdr text2))) 0 2) (bytes #x0f #x84))

;; li with a label expands to RIP-relative lea
(define build3
  (compile
   target-amd64
   (list (cons 'rich-data '((label data) (b64 #x1234)))
         (cons 'program-items
               '((label text)
                 (li rax (data))
                 (ret)))
         (cons 'layout-spec spec))))
(define text3 (cadr build3))
(check-equal? (cddr text3)
              '((kind code) (start #x200000) (size 8)
                (bytes #"H\x8d\x05\xf9\xff\x0f\x00\xc3")))

;; loko-compat: old Loko spelling -> core items -> the normal backend flow
(define loko-build
  (compile
   target-amd64
   (list (cons 'loko-source
               '(loko-source
                 (text
                  (%label text)
                  (mov rax (mem64+ rbp -8))
                  (jmp done)
                  (%label done)
                  (ret))
                 (data
                  (%label data)
                  (%u64 #x1234))))
         (cons 'layout-spec spec))
   'loko))

(check-equal? loko-build
              '(build
                (segment (name text) (kind code) (start #x200000) (size 5)
                         (bytes #"H\x8bE\xf8\xc3"))
                (segment (name data) (kind data) (start #x300000) (size 8)
                         (bytes #"\x34\x12\x00\x00\x00\x00\x00\x00"))))
