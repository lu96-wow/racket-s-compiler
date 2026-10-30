#lang racket/base

;; ============================================================
;; Extension-scoped metadata lookup and disambiguation
;;
;; There is intentionally no cross-extension aggregate table.
;; Callers name the extension set first, then resolve a mnemonic.
;; ============================================================

(require racket/list
         racket/string
         "../layout-spec.rkt"
         "../layout.rkt"
         "struct.rkt"
         "query.rkt")

(define (check-extension who extension)
  (unless (symbol? extension)
    (raise-argument-error who "symbol?" extension)))

(define (check-extensions who extensions)
  (unless (and (list? extensions) (andmap symbol? extensions))
    (raise-argument-error who "(listof symbol?)" extensions)))

(define (check-name who name)
  (unless (symbol? name)
    (raise-argument-error who "symbol?" name)))

(define info-cache (make-hash))

(define (extension-instruction-info extension)
  (check-extension 'extension-instruction-info extension)
  (hash-ref!
   info-cache extension
   (lambda ()
     (dynamic-require (list 'file (instruction-info-path extension))
                      (extension-info-variable extension)))))

(define (instruction-info-extensions)
  (dynamic-require (extensions-path) 'extensions))

(define (find-extension-instruction-info extension name)
  (find-instruction-info (extension-instruction-info extension) name))

(define (instruction-info-candidates extensions name)
  (check-extensions 'instruction-info-candidates extensions)
  (check-name 'instruction-info-candidates name)
  (for/list ([ext (in-list extensions)]
             #:do [(define info (find-extension-instruction-info ext name))]
             #:when info)
    info))

;; ------------------------------------------------------------
;; ISA consistency and candidate choice
;; ------------------------------------------------------------

(define rv32-extension-prefix "rv32_")
(define rv64-extension-prefix "rv64_")

(define (rv32-extension? ext)
  (string-prefix? (symbol->string ext) rv32-extension-prefix))

(define (rv64-extension? ext)
  (string-prefix? (symbol->string ext) rv64-extension-prefix))

(define (mixed-xlen? extensions)
  (and (ormap rv32-extension? extensions)
       (ormap rv64-extension? extensions)))

(define (origin-priority info)
  (case (info-kind info)
    [(standard) 2]
    [(import) 1]
    [(pseudo) 0]
    [else 0]))

(define (choose-candidate candidates)
  (define best
    (for/fold ([best #f]) ([c (in-list candidates)])
      (cond
        [(not best) c]
        [(> (origin-priority c) (origin-priority best)) c]
        [else best])))
  best)

(define (all-encoding-equal? candidates)
  (or (null? candidates)
      (for/and ([c (in-list (cdr candidates))])
        (instruction-info-encoding=? (car candidates) c))))

(define (all-interface-equal? candidates)
  (or (null? candidates)
      (for/and ([c (in-list (cdr candidates))])
        (instruction-info-interface=? (car candidates) c))))

(define (resolve-instruction-info extensions name)
  (check-extensions 'resolve-instruction-info extensions)
  (check-name 'resolve-instruction-info name)
  (when (mixed-xlen? extensions)
    (error 'resolve-instruction-info
           "rv32 and rv64 extensions cannot be mixed: ~a"
           extensions))
  (define candidates (instruction-info-candidates extensions name))
  (cond
    [(null? candidates)
     (error 'resolve-instruction-info
            "instruction ~a not found in extensions ~a"
            name extensions)]
    [(null? (cdr candidates))
     (car candidates)]
    [(not (all-encoding-equal? candidates))
     (error 'resolve-instruction-info
            "instruction ~a has different encodings in extensions ~a: ~a"
            name extensions
            (for/list ([c (in-list candidates)])
              (instruction-info-extension c)))]
    [(not (all-interface-equal? candidates))
     (error 'resolve-instruction-info
            "instruction ~a has the same encoding but incompatible operand interfaces in ~a"
            name extensions)]
    [else
     (choose-candidate candidates)]))

(provide instruction-info-path
         instruction-info-extensions
         extension-instruction-info
         find-extension-instruction-info
         instruction-info-candidates
         resolve-instruction-info)
