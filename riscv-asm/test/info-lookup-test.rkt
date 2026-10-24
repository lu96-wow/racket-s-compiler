#lang racket/base

(require rackunit
         racket/list
         racket/set
         racket/string
         "../generated/lib/info/struct.rkt"
         "../generated/lib/info/query.rkt"
         "../generated/lib/info/lookup.rkt"
         "../generated/gen/riscv/info/instruction_extensions.rkt")

(define extensions (instruction-info-extensions))

(check-true (pair? extensions))
(check-true (andmap symbol? extensions))
(check-equal? extensions
              (sort (remove-duplicates extensions) symbol<?)
              "extension list should be sorted and unique")

(define total 0)

(for ([ext (in-list extensions)])
  (define path (instruction-info-path ext))
  (check-true (string? path) (format "~a: path" ext))
  (check-true (file-exists? path) (format "~a: ~a" ext path))
  (check-true (string-suffix? path (format "~a.rkt" ext))
              (format "~a: ~a" ext path))

  (define infos (extension-instruction-info ext))
  (check-not-false infos (format "~a: table" ext))
  (check-true (pair? infos) (format "~a: table not empty" ext))
  (set! total (+ total (length infos)))

  (for ([info (in-list infos)])
    (check-eq? (instruction-info-extension info) ext
               (format "~a: entry extension" ext))
    (check-not-false (memq (info-kind info) '(standard import pseudo))
                (format "~a/~a: origin kind" ext (instruction-info-name info)))
    (check-equal? (info-size info) (quotient (info-width info) 8)))

  (define names (map instruction-info-name infos))
  (check-equal? (length names) (length (remove-duplicates names))
                (format "~a: names unique" ext))

  (for ([name (in-list names)])
    (check-not-false (memq ext (get-extensions name))
                     (format "~a/~a: in instruction->extensions" ext name))))

(for ([(name exts) (in-hash instruction->extensions)])
  (for ([ext (in-list exts)])
    (check-not-false (find-extension-instruction-info ext name)
                     (format "~a/~a: reverse index" ext name))))

(check-true (> total 1000) (format "total entries ~a" total))

(check-eq? (extension-instruction-info 'rv_i)
           (extension-instruction-info 'rv_i))

(check-eq? (instruction-info-name
            (find-extension-instruction-info 'rv_i 'add))
           'add)
(check-false (find-extension-instruction-info 'rv_i 'no-such-instruction))

;; ------------------------------------------------------------
;; basic candidate / resolve
;; ------------------------------------------------------------

(check-equal? (length (instruction-info-candidates '(rv_i) 'add)) 1)
(check-equal? (instruction-info-candidates '(rv_i) 'no-such-instruction) '())

(check-equal? (map instruction-info-extension
                   (instruction-info-candidates '(rv_zbb rv_zbkb) 'andn))
              '(rv_zbb rv_zbkb))

;; Origin priority: standard beats import even if the caller lists import first.
(check-eq? (instruction-info-extension
            (resolve-instruction-info '(rv_zbkb rv_zbb) 'andn))
           'rv_zbb)
(check-eq? (info-kind (resolve-instruction-info '(rv_zbkb rv_zbb) 'andn))
           'standard)

;; Same encoding, pseudo origin: standard beats pseudo.
(check-eq? (instruction-info-extension
            (resolve-instruction-info '(rv32_zk rv32_zbkb) 'zip))
           'rv32_zbkb)
(check-eq? (info-kind (resolve-instruction-info '(rv32_zk rv32_zbkb) 'zip))
           'standard)

;; Pseudo provenance is retained when the pseudo actually wins.
(check-eq? (info-kind (resolve-instruction-info '(rv32_i) 'slli))
           'pseudo)
(check-eq? (info-source-extension (resolve-instruction-info '(rv32_i) 'slli))
           'rv64_i)
(check-eq? (info-source-instruction (resolve-instruction-info '(rv32_i) 'slli))
           'slli)

;; rv32/rv64 mixing is rejected explicitly.
(check-exn exn:fail?
           (lambda () (resolve-instruction-info '(rv32_i rv64_i) 'slli)))

(check-exn exn:fail?
           (lambda () (resolve-instruction-info '(rv_i) 'no-such-instruction)))

;; ------------------------------------------------------------
;; canonical encoding signatures
;; ------------------------------------------------------------

(define (mk-info #:name [name 'x]
                 #:extension [extension 'e1]
                 #:width [width 32]
                 #:operands [operands '("rd")]
                 #:raw-operands [raw-operands '("rd")]
                 #:fixed-fields [fixed-fields '((12 14 1) (2 6 4) (0 1 3))]
                 #:aliases [aliases '()]
                 #:origin [origin (instruction-origin 'standard #f #f)]
                 #:raw-bindings [raw-bindings '(("rd" "rd"))]
                 #:rebuilt-bindings [rebuilt-bindings '(("raw:rd" "rd"))]
                 #:asm [asm "x rd"])
  (instruction-info name extension width (quotient width 8)
                    operands raw-operands fixed-fields aliases origin
                    raw-bindings rebuilt-bindings asm))

(define a (mk-info #:fixed-fields '((31 25 0) (12 14 1) (2 6 4) (0 1 3))))
(define b (mk-info #:fixed-fields '((31 26 0) (25 25 0)
                                    (0 1 3) (2 6 4) (12 14 1))))
(check-equal? (instruction-info-encoding-signature a)
              (instruction-info-encoding-signature b)
              "fixed-field order/splitting must be canonicalized")

(define c (mk-info #:aliases '(("rs2" "rs1") ("rd2" "rd"))
                   #:raw-bindings '(("rd" "rd") ("rs1" "rs1")
                                    ("rs2" "rs1") ("rd2" "rd"))))
(define d (mk-info #:aliases '(("rd2" "rd") ("rs2" "rs1"))
                   #:raw-bindings '(("rd2" "rd") ("rs2" "rs1")
                                    ("rs1" "rs1") ("rd" "rd"))))
(check-equal? (instruction-info-encoding-signature c)
              (instruction-info-encoding-signature d)
              "binding and alias order must not matter")

(check-not-equal? (instruction-info-encoding-signature a)
                  (instruction-info-encoding-signature
                   (mk-info #:fixed-fields '((31 25 1) (12 14 1) (2 6 4) (0 1 3))))
                  "different fixed bits are different encodings")

(check-not-equal? (instruction-info-interface-signature
                   (mk-info #:operands '("rd" "rs1") #:raw-operands '("rd" "rs1")))
                  (instruction-info-interface-signature
                   (mk-info #:operands '("rs1" "rd") #:raw-operands '("rs1" "rd")))
                  "operand order is part of the public interface")

(check-equal? (instruction-info-encoding-signature a)
              (instruction-info-encoding-signature
               (mk-info #:origin (instruction-origin 'pseudo 'rv_i 'addi)))
              "provenance must not affect encoding identity")

;; ------------------------------------------------------------
;; argument checking
;; ------------------------------------------------------------

(check-exn exn:fail:contract? (lambda () (instruction-info-path "rv_i")))
(check-exn exn:fail:contract? (lambda () (extension-instruction-info "rv_i")))
(check-exn exn:fail:contract?
           (lambda () (find-extension-instruction-info 'rv_i "add")))
(check-exn exn:fail:contract?
           (lambda () (instruction-info-candidates 'rv_i 'add)))
(check-exn exn:fail:contract?
           (lambda () (resolve-instruction-info '(rv_i) "add")))
