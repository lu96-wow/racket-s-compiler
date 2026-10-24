#lang racket/base

;; ============================================================
;; Import / pseudo / duplicate resolution
;;
;; Winner priority:
;;   1. standard definition in this extension
;;   2. imported standard definition
;;   3. pseudo whose fixed fields are compatible with its source
;;   4. any other pseudo (fallback)
;;
;; Also ties at the highest priority are an error.  Silently choosing one
;; of two different same-priority definitions makes builds irreproducible.
;; ============================================================

(require racket/list
         "fixed.rkt"
         "model.rkt")

;; ------------------------------------------------------------
;; imports and pseudo sources
;; ------------------------------------------------------------

(define (find-definition defs name)
  (for/first ([idef (in-list defs)]
              #:when (equal? (instruction-def-name idef) name))
    idef))

;; Returns ((import-def . instruction-def) ...).
(define (resolve-imports extension-file extension-map)
  (for/list ([im (in-list (extension-file-imports extension-file))])
    (define source-extension (import-def-source-extension im))
    (define instruction-name (import-def-instruction-name im))
    (define source-file (hash-ref extension-map source-extension #f))
    (unless source-file
      (error 'resolve-imports
             "cannot resolve import ~a::~a from ~a"
             source-extension instruction-name (extension-file-path extension-file)))
    (define idef
      (find-definition (extension-file-standard source-file) instruction-name))
    (unless idef
      (error 'resolve-imports
             "instruction ~a::~a not found in ~a"
             source-extension instruction-name (extension-file-path source-file)))
    (cons im idef)))

(define (validate-pseudo-source! pseudo extension-map)
  (define source-extension (pseudo-def-source-extension pseudo))
  (define source-instruction (pseudo-def-source-instruction pseudo))
  (define source-file (hash-ref extension-map source-extension #f))
  (unless source-file
    (error 'validate-pseudo-source!
           "pseudo ~a references unknown extension ~a"
           (pseudo-def-name pseudo) source-extension))
  (unless (find-definition (extension-file-standard source-file)
                           source-instruction)
    (error 'validate-pseudo-source!
           "pseudo ~a references unknown instruction ~a::~a"
           (pseudo-def-name pseudo) source-extension source-instruction)))

;; ------------------------------------------------------------
;; fixed-field compatibility
;; ------------------------------------------------------------

(define (fixed-field-bit-map fixed-fields)
  (for*/fold ([bits (hash)]) ([ff (in-list fixed-fields)]
                              [bit (in-range (fixed-field-lo ff)
                                             (add1 (fixed-field-hi ff)))])
    (hash-set bits bit (fixed-field-bit-value ff bit))))

(define (fixed-fields-compatible? source-fixed candidate-fixed)
  (define candidate-bits (fixed-field-bit-map candidate-fixed))
  (for*/and ([ff (in-list source-fixed)]
             [bit (in-range (fixed-field-lo ff)
                            (add1 (fixed-field-hi ff)))])
    (equal? (hash-ref candidate-bits bit #f)
            (fixed-field-bit-value ff bit))))

(define (pseudo-standard-form? pseudo extension-map)
  (define source-extension (pseudo-def-source-extension pseudo))
  (define source-instruction (pseudo-def-source-instruction pseudo))
  (define source-file (hash-ref extension-map source-extension #f))
  (define source-def
    (and source-file
         (find-definition (extension-file-standard source-file)
                          source-instruction)))
  (and source-def
       (fixed-fields-compatible?
        (instruction-def-fixed-fields source-def)
        (instruction-def-fixed-fields (pseudo-def-instruction pseudo)))))

;; ------------------------------------------------------------
;; candidate construction
;; ------------------------------------------------------------

(define (standard-origin)
  (definition-origin 'standard #f #f))

(define (reference-origin kind source-extension source-instruction)
  (definition-origin kind
                      (string->symbol source-extension)
                      (string->symbol source-instruction)))

(define (candidate-priority c)
  (case (candidate-kind c)
    [(standard) 3]
    [(import) 2]
    [(pseudo) (if (candidate-standard-form? c) 1 0)]
    [else 0]))

(define (choose-winner candidates)
  (define max-priority
    (for/fold ([p -1]) ([c (in-list candidates)])
      (max p (candidate-priority c))))
  (define winners
    (filter (lambda (c) (= (candidate-priority c) max-priority))
            candidates))
  (cond
    [(null? winners)
     (error 'choose-winner "no candidate to choose from")]
    [(null? (cdr winners))
     (car winners)]
    [else
     (error 'choose-winner
            "ambiguous definitions for ~a: ~a"
            (instruction-def-name
             (candidate-definition (car winners)))
            (for/list ([c (in-list winners)])
              (candidate-kind c)))]))

(define (skip-reason winner loser)
  (case (candidate-kind loser)
    [(standard) "duplicate-standard-definition"]
    [(import)
     (if (eq? (candidate-kind winner) 'standard)
         "overridden-by-standard-definition"
         "duplicate-import-definition")]
    [(pseudo)
     (cond
       [(eq? (candidate-kind winner) 'standard)
        "overridden-by-standard-definition"]
       [(eq? (candidate-kind winner) 'import)
        "overridden-by-imported-standard-definition"]
       [(candidate-standard-form? winner) "not-a-standard-form"]
       [else "ambiguous-pseudo"])]
    [else "duplicate-definition"]))

(define (prepare-extension-defs extension-file extension-map)
  (for ([pseudo (in-list (extension-file-pseudo extension-file))])
    (validate-pseudo-source! pseudo extension-map))

  (define candidates
    (append
     (for/list ([idef (in-list (extension-file-standard extension-file))])
       (candidate idef 'standard (standard-origin) #t))
     (for/list ([pair (in-list (resolve-imports extension-file extension-map))])
       (define im (car pair))
       (define idef (cdr pair))
       (candidate
        idef
        'import
        (reference-origin 'import
                          (import-def-source-extension im)
                          (import-def-instruction-name im))
        #t))
     (for/list ([pseudo (in-list (extension-file-pseudo extension-file))])
       (candidate
        (pseudo-def-instruction pseudo)
        'pseudo
        (reference-origin 'pseudo
                          (pseudo-def-source-extension pseudo)
                          (pseudo-def-source-instruction pseudo))
        (pseudo-standard-form? pseudo extension-map)))))

  (define by-name (make-hash))
  (define order '())
  (for ([c (in-list candidates)])
    (define name (instruction-def-name (candidate-definition c)))
    (unless (hash-has-key? by-name name)
      (set! order (cons name order)))
    (hash-update! by-name name (lambda (cs) (cons c cs)) '()))

  (define chosen '())
  (define skipped '())
  (for ([name (in-list (reverse order))])
    (define group (reverse (hash-ref by-name name)))
    (define winner (choose-winner group))
    (define losers (filter (lambda (c) (not (eq? c winner))) group))
    (set! chosen
          (cons (resolved-def (candidate-definition winner)
                              (candidate-origin winner))
                chosen))
    (for ([loser (in-list losers)])
      (set! skipped
            (cons (skipped-definition name (skip-reason winner loser))
                  skipped))))

  (values (reverse chosen) (reverse skipped)))

(provide find-definition
         resolve-imports
         validate-pseudo-source!
         fixed-field-bit-map
         fixed-fields-compatible?
         pseudo-standard-form?
         prepare-extension-defs)
