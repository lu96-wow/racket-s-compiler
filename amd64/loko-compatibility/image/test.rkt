#lang racket
;;; amd64/loko-compatibility/image/test.rkt

(require rackunit
         "../translate.rkt"
         "layout-spec.rkt")

(define (loko-ir-of src)
  (define fields (cdr (translate-loko-source src)))
  (list 'loko-ir
        (assq 'origin fields)
        (assq 'symbols fields)
        (assq 'comms fields)
        (assq 'sections fields)))

(define-values (spec program-items data-items problems)
  (build-layout-spec
   (loko-ir-of
    '(loko-source
      (text
       (%origin #x200000)
       (%mode 64)
       (%section text)
       (%label text)
       (ret))
      (data
       (%label bss)
       (%section bss)
       (reserve 32)
       (%label bss-end))))))

(check-equal? problems '())
(check-equal? spec
              '((segments
                 (segment (name text) (kind code) (start #x200000) (end #x200001) (align 1))
                 (segment (name data) (kind data) (start #x200001) (end #x200001) (align 1))
                 (segment (name bss) (kind bss) (start #x200001) (end #x200021) (align 1)))
                (place text (text))
                (place data (bss))
                (place bss (loko-image-start-bss) (bss-end))))
(check-equal? program-items '((label text) (ret)))
(check-equal? data-items
              '((label bss)
                (comment section-boundary bss)
                (label loko-image-start-bss)
                (reserve 32)
                (label bss-end)))

;; non-64-bit code sections are reported, not silently measured as 64-bit
(define-values (_spec2 _p2 _d2 problems2)
  (build-layout-spec
   (loko-ir-of
    '(loko-source
      (text (%origin 0) (%mode 32) (%section text) (%label text) (ret))
      (data)))))
(check-true
 (for/or ([p (in-list problems2)])
   (equal? p '(problem mode-unsupported text 32))))

(displayln "amd64 loko-image tests: ok")
