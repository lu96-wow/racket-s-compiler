#lang racket
;;; amd64/loko-compatibility/test-flow.rkt
;;;
;;; Integration tests for the optional Loko stages on top of the core flow.

(require rackunit
         "flow.rkt"
         "../amd64-asm/target.rkt")

(define spec
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16))
     (segment (name data) (kind data) (start #x300000) (end #x301000) (align 8)))
    (place text (text))
    (place data (data))))

;; %init-bss + reserve/bss flows through loko-compat -> compiler
(define bss-spec
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16))
     (segment (name bss) (kind hole) (start #x300000) (end #x301000) (align 16)))
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
   'loko-manual))
(check-equal? (cddr (cadr (cdr bss-build)))
              '((kind hole) (start #x300000) (size 32) (bytes #"")))

;; %comm is expanded into the bss section and respects size ordering/align
(define comm-spec
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16))
     (segment (name bss) (kind hole) (start #x300000) (end #x302000) (align 16)))
    (place text (text))
    (place bss (bss) (small) (large) (bss-end))))
(define comm-build
  (compile
   target-amd64
   (list (cons 'loko-source
               '(loko-source
                 (text
                  (%comm large 4096 4096)
                  (%comm small 8 8)
                  (%section text)
                  (%label text)
                  (ret))
                 (data
                  (%label bss)
                  (%section bss)
                  (%label bss-end))))
         (cons 'layout-spec comm-spec))
   'loko-manual))
(check-equal? (cddr (cadr (cdr comm-build)))
              '((kind hole) (start #x300000) (size 8192) (bytes #"")))

;; automatic loko-ir -> layout-spec (no layout-spec seed)
(define auto-build
  (compile
   target-amd64
   (list (cons 'loko-source
               '(loko-source
                 (text
                  (%origin #x200000)
                  (%mode 64)
                  (%section text)
                  (%label text)
                  (ret))
                 (data
                  (%label data)
                  (%u64 #x1234)))))
   'loko))
(check-equal? auto-build
              '(build
                (segment (name text) (kind code) (start #x200000) (size 1)
                         (bytes #"\xc3"))
                (segment (name data) (kind data) (start #x200001) (size 8)
                         (bytes #"\x34\x12\x00\x00\x00\x00\x00\x00"))))

;; automatic layout keeps an empty data section and a real bss segment
(define auto-bss-build
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
                  (%label bss)
                  (%section bss)
                  (reserve 32)
                  (%label bss-end)))))
   'loko))
(check-equal? (cddr (cadddr auto-bss-build))
              '((kind hole) (start #x200017) (size 32) (bytes #"")))

;; loko-lower is part of the automatic loko flow
(define reg-build
  (compile
   target-amd64
   (list (cons 'loko-source
               '(loko-source
                 (text
                  (%origin #x200000)
                  (%mode 64)
                  (%section text)
                  (%label text)
                  (mov (reg 0) 1)
                  (add (reg 0) 1)
                  (ret))
                 (data))))
   'loko))
(check-equal? (cddr (car (cdr reg-build)))
              '((kind code)
                (start #x200000)
                (size 12)
                (bytes #"H\xc7\xc0\x01\x00\x00\x00H\x83\xc0\x01\xc3")))

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
   'loko-manual))

(check-equal? loko-build
              '(build
                (segment (name text) (kind code) (start #x200000) (size 5)
                         (bytes #"H\x8bE\xf8\xc3"))
                (segment (name data) (kind data) (start #x300000) (size 8)
                         (bytes #"\x34\x12\x00\x00\x00\x00\x00\x00"))))

(displayln "amd64 loko flow tests: ok")
