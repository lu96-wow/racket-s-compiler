#lang racket
;;; test/external-test.rkt
;;;
;;; interface source -> externs -> relocation -> link(address data)。

(require rackunit
         racket/list
         "../driver/compile.rkt"
         "../encode/encode.rkt"
         "../layout/program.rkt"
         "../link/link.rkt"
         "../link/reloc.rkt")

(define (build-call)
  '((file main
      (module (m)
        (provide (main))
        (require (lib))
        (func (main)
          (vregs (($ r) (b64)))
          (entry b0)
          (block b0
            (call ($ r) (global (f)))
            (term (return ($ r)))))))))

(define (interface-func)
  '((file iface
      (module (lib)
        (provide (f))
        (func (f)
          (vregs (($ r) (b64)))
          (entry b0)
          (block b0
            (const ($ r) 1)
            (term (return ($ r)))))))))

(define (build-addr+data)
  '((file main
      (module (m)
        (provide (main))
        (require (lib))
        (data (local)
          (align 8)
          (value 8 (global (d))))
        (func (main)
          (vregs (($ p) (ptr)))
          (entry b0)
          (block b0
            (addr ($ p) (global (d)))
            (term (return ($ p)))))))))

(define (interface-data)
  '((file iface
      (module (lib)
        (provide (d))
        (data (d)
          (bytes 1))))))

(define (words bs)
  (for/list ([i (in-range 0 (bytes-length bs) 4)])
    (for/fold ([w 0]) ([j (in-range 4)])
      (bitwise-ior w
                   (arithmetic-shift (bytes-ref bs (+ i j)) (* 8 j))))))

(test-case "external call becomes a call-pcrel relocation"
  (define c (compile-files (build-call) #:interface-files (interface-func)))
  (define layout (compiled-program-layout c))
  (check-equal? (program-layout-externs layout)
                '((extern (lib f) (kind func))))
  (define relocs (encoded-program-relocations
                  (compiled-program-encoded c)))
  (check-equal? (length relocs) 1)
  (define reloc (car relocs))
  (check-equal? (relocation-kind reloc) 'call-pcrel)
  (check-equal? (relocation-symbol reloc) '(lib f))
  (check-equal? (relocation-section reloc) '(m main))

  (define linked (link-encoded (compiled-program-encoded c)
                               #:addresses '((address (lib f) #x2000))))
  (check-equal? (bytes-length (linked-program-bytes linked))
                (bytes-length (compiled-program-bytes c))))

(test-case "external addr and data value become relocations"
  (define c (compile-files (build-addr+data) #:interface-files (interface-data)))
  (define relocs (encoded-program-relocations
                  (compiled-program-encoded c)))
  (check-equal? (map relocation-kind relocs)
                '(addr-pcrel abs))
  (check-equal? (map relocation-symbol relocs)
                '((lib d) (lib d)))

  (define layout (compiled-program-layout c))
  (define data-section
    (findf data-section? (program-layout-sections layout)))
  (define linked (link-encoded (compiled-program-encoded c)
                               #:addresses '((address (lib d) #x3000))))
  (define at (data-section-base data-section))
  (define value
    (for/fold ([w 0]) ([i (in-range 8)])
      (bitwise-ior w
                   (arithmetic-shift
                    (bytes-ref (linked-program-bytes linked) (+ at i))
                    (* 8 i)))))
  (check-equal? value #x3000))

(test-case "unresolved external is an error"
  (define c (compile-files (build-call) #:interface-files (interface-func)))
  (check-exn #rx"unresolved external symbol"
             (lambda ()
               (link-encoded (compiled-program-encoded c)))))

(test-case "address data must refer to an extern"
  (define c (compile-files (build-call) #:interface-files (interface-func)))
  (check-exn #rx"address for non-extern symbol"
             (lambda ()
               (link-encoded (compiled-program-encoded c)
                             #:addresses '((address (other x) 0))))))

(test-case "external data cannot be called as a function"
  (define build
    '((file main
        (module (m)
          (provide (main))
          (require (lib))
          (func (main)
            (vregs (($ r) (b64)))
            (entry b0)
            (block b0
              (call ($ r) (global (d)))
              (term (return ($ r)))))))))
  (check-exn #rx"call refers to undefined function"
             (lambda ()
               (compile-files build #:interface-files (interface-data)))))
