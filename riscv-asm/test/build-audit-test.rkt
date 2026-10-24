#lang racket/base

;; ============================================================
;; Build output audit
;;
;; Re-parses and re-resolves the source, then checks that generated
;; metadata and instruction modules agree with that resolution.
;; ============================================================

(require rackunit
         racket/list
         racket/string
         "../binary-build/model.rkt"
         "../binary-build/parse.rkt"
         "../binary-build/resolve.rkt"
         "../binary-build/paths.rkt"
         "../binary-build/layout/plan.rkt"
         "../generated/lib/info/struct.rkt"
         "../generated/lib/info/query.rkt"
         "../generated/lib/info/lookup.rkt"
         "../generated/lib/instruction_paths.rkt")
(require "../generated/gen/riscv/info/instruction_extensions.rkt")

(define source-files
  (ratified-extension-source-files default-opcodes-dir))
(define parsed-files
  (for/list ([path (in-list source-files)])
    (parse-extension-file path)))
(define ext-map
  (for/hash ([parsed (in-list parsed-files)])
    (values (extension-stem (extension-file-path parsed)) parsed)))

(define (phase-export-names groups)
  (append*
   (for/list ([group (in-list groups)])
     (map car (cdr group)))))

(define (module-export-names path)
  (define module-path (list 'file path))
  (dynamic-require module-path #f)
  (define-values (vars stxs) (module->exports module-path))
  (sort (remove-duplicates
         (append (phase-export-names vars) (phase-export-names stxs)))
        symbol<?))

(define (definition-name-symbol resolved)
  (string->symbol
   (instruction-def-name (resolved-def-definition resolved))))

(define (origin= expected actual name)
  (check-eq? (definition-origin-kind expected)
             (instruction-origin-kind actual)
             (format "~a: origin kind" name))
  (check-eq? (definition-origin-source-extension expected)
             (instruction-origin-source-extension actual)
             (format "~a: origin source extension" name))
  (check-eq? (definition-origin-source-instruction expected)
             (instruction-origin-source-instruction actual)
             (format "~a: origin source instruction" name)))

(define all-skipped '())
(define total-names 0)

(for ([parsed (in-list parsed-files)])
  (define ext (extension-stem (extension-file-path parsed)))
  (define-values (resolved-defs skipped)
    (prepare-extension-defs parsed ext-map))
  (set! all-skipped (append skipped all-skipped))
  (set! total-names (+ total-names (length resolved-defs)))

  (define generated (extension-instruction-info (string->symbol ext)))
  (define resolved-names (sort (map definition-name-symbol resolved-defs) symbol<?))
  (define generated-names (sort (map instruction-info-name generated) symbol<?))
  (check-equal? generated-names resolved-names
                (format "~a: info names match resolution" ext))

  (define raw-names
    (module-export-names (raw-instruction-path (string->symbol ext))))
  (define rebuilt-names
    (module-export-names (rebuilt-instruction-path (string->symbol ext))))
  (check-equal? raw-names generated-names
                (format "~a: raw exports match info" ext))
  (check-equal? rebuilt-names generated-names
                (format "~a: rebuilt exports match info" ext))

  (for ([resolved (in-list resolved-defs)])
    (define idef (resolved-def-definition resolved))
    (define name (string->symbol (instruction-def-name idef)))
    (define info (find-extension-instruction-info (string->symbol ext) name))
    (check-not-false info (format "~a/~a: info exists" ext name))
    (when info
      (define raw-plan (raw-operand-plan idef))
      (define rebuilt-plan (rebuilt-operand-plan idef))
      (check-equal? (instruction-info-operands info)
                    (operand-plan-args rebuilt-plan)
                    (format "~a/~a: rebuilt operands" ext name))
      (check-equal? (instruction-info-raw-operands info)
                    (operand-plan-args raw-plan)
                    (format "~a/~a: raw operands" ext name))
      (check-equal? (instruction-info-raw-bindings info)
                    (plan-bindings raw-plan)
                    (format "~a/~a: raw bindings" ext name))
      (check-equal? (instruction-info-rebuilt-bindings info)
                    (plan-bindings rebuilt-plan)
                    (format "~a/~a: rebuilt bindings" ext name))
      (check-equal? (instruction-info-fixed-fields info)
                    (for/list ([ff (in-list (instruction-def-fixed-fields idef))])
                      (list (fixed-field-lo ff)
                            (fixed-field-hi ff)
                            (fixed-field-value ff)))
                    (format "~a/~a: fixed fields" ext name))
      (origin= (resolved-def-origin resolved)
               (info-origin info)
               (format "~a/~a" ext name)))))

(check-equal? (instruction-info-extensions)
              (sort (map (lambda (p)
                           (string->symbol (extension-stem (extension-file-path p))))
                         parsed-files)
                    symbol<?)
              "generated extension list matches source files")

(check-true (> total-names 1000))

(define skipped-summary
  (sort (remove-duplicates
         (for/list ([s (in-list all-skipped)])
           (format "~a:~a"
                   (skipped-definition-name s)
                   (skipped-definition-reason s))))
        string<?))
(check-equal? skipped-summary
              '("jal:overridden-by-standard-definition"
                "jalr:overridden-by-standard-definition"
                "ld:not-a-standard-form")
              "known skipped definitions")
