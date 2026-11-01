#lang racket
;;; amd64/amd64-asm/insn-generic.rkt
;;;
;;; Interpreter for the NASM-derived instruction table emitted by
;;; binary-build/.  The runtime has the same split as the build pipeline:
;;;
;;;   operands -> try-plan-entry / generic-plan-instruction  (constraints+policy)
;;;            -> instruction-plan                          (chosen form+size)
;;;            -> encode-plan                               (bytes only)
;;;
;;; Layout can consume generic-instruction-size/plan-size without asking for
;;; bytes; encoding only consumes the already-resolved plan.  It is separate
;;; from insn.rkt's handwritten special encoders: generated forms are the
;;; fallback (and the future primary path) for instructions without a special
;;; case.

(require racket/list
         "sexp.rkt"
         "registers.rkt"
         "ranges.rkt"
         "insn-core.rkt"
         "generated/gen/insn/nasm.rkt")

(provide generic-instruction?
         generic-instruction-arity
         generic-plan-instruction
         generic-instruction-size
         generic-encode-instruction
         (rename-out [plan-size generic-plan-size]
                     [encode-plan generic-encode-plan])
         generic-form-count
         generic-mnemonic-count
         generic-source)

;; ---------------------------------------------------------------------------
;; parsed generated data
;; ---------------------------------------------------------------------------

(struct op-spec (kind width fixed) #:transparent)
(struct imm-spec (kind width range index) #:transparent)
(struct enc-spec
  (prefixes opcode plus-r modrm-rm modrm-reg imm size-mode nw?
            force-rex-w? rex-b? rex-x? rex-r? wait?)
  #:transparent)
(struct entry (mnemonic operands encoding flags line) #:transparent)

;; A resolved instruction form: the constraint-checking/selection stage has
;; already chosen an entry and fixed every policy decision (operand-width
;; prefix, REX, ModR/M roles, immediate width/value).  Emission consumes this
;; plan only; it never re-matches operands or re-selects a form.
(struct instruction-plan
  (mnemonic entry operands width wait? segment-prefix prefixes rex
            opcode rm-enc imm-width imm-value)
  #:transparent)

(define (field key alist)
  (cond [(assq key alist) => cadr]
        [else #f]))

(define (parse-generated-entry raw)
  (match raw
    [(list mnemonic ops enc flags line)
     (entry mnemonic
            (for/list ([op (in-list ops)])
              (match op
                [(list _text kind width fixed)
                 (op-spec kind width fixed)]))
            (enc-spec (field 'prefixes enc)
                      (field 'opcode enc)
                      (field 'plus-r enc)
                      (field 'modrm-rm enc)
                      (field 'modrm-reg enc)
                      (field 'imm enc)
                      (field 'size-mode enc)
                      (field 'nw? enc)
                      (field 'force-rex-w? enc)
                      (field 'rex-b? enc)
                      (field 'rex-x? enc)
                      (field 'rex-r? enc)
                      (field 'wait? enc))
            flags line)]))

(define all-entries
  (for/list ([raw (in-list forms)])
    (parse-generated-entry raw)))

(define entries-by-name
  (let ([h (make-hash)])
    (for ([e (in-list all-entries)])
      (hash-update! h (entry-mnemonic e)
                    (lambda (xs) (cons e xs))
                    '()))
    (for ([(k v) (in-hash h)])
      (hash-set! h k (reverse v)))
    h))

(define (generic-instruction? name)
  (and (symbol? name) (hash-has-key? entries-by-name name) #t))

(define (generic-form-count) (length all-entries))
(define (generic-mnemonic-count) (hash-count entries-by-name))
(define generic-source source-label)

;; ---------------------------------------------------------------------------
;; operand normalization and matching
;; ---------------------------------------------------------------------------

(define (normalize-operand op)
  (cond
    [(mem? op) op]
    [(mem-form? op) (parse-mem op)]
    [(reg? op) op]
    [(symbol? op) (lookup-register op #f)]
    [else #f]))

(define (reg-width-of op)
  (cond [(reg? op) (reg-width op)]
        [(mem? op) (mem-width op)]
        [else #f]))

(define (gpr-op? op)
  (and (reg? op) (gpr-register? op)))

(define (xmm-op? op)
  (and (reg? op) (xmm-register? op)))

;; Returns (values present? value forced-width).
(define (immediate-operand op)
  (cond
    [(exact-integer? op) (values #t op #f)]
    [(and (form? op)
          (memq (car op) '(imm8 imm16 imm32 imm64))
          (= 2 (length op)))
     (values #t (cadr op)
             (case (car op)
               [(imm8) 1] [(imm16) 2] [(imm32) 4] [(imm64) 8]))]
    [(and (address-expr? op) (not (exact-integer? op)))
     (values #t op #f)]
    [else (values #f #f #f)]))

(define (operand-matches? spec op)
  (define kind (op-spec-kind spec))
  (define width (op-spec-width spec))
  (case kind
    [(gpr)
     (and (gpr-op? op) (= width (reg-width op)))]
    [(gpr-fixed)
     (and (gpr-op? op)
          (eq? (op-spec-fixed spec) (reg-name op))
          (= width (reg-width op)))]
    [(rm)
     (cond
       [(gpr-op? op) (= width (reg-width op))]
       [(mem? op) (= width (mem-width op))]
       [else #f])]
    [(mem)
     (and (mem? op) (or (not width) (= width (mem-width op))))]
    [(xmm)
     (and (xmm-op? op) (= 128 (reg-width op)))]
    [(xmm-rm)
     (cond
       [(xmm-op? op) #t]
       [(mem? op) (or (not width) (= width (mem-width op)))]
       [else #f])]
    [(imm)
     (call-with-values (lambda () (immediate-operand op))
       (lambda (present? value forced)
         (and present?
              (or (not width) (not forced) (= width (* 8 forced)))
              #t)))]
    [else #f]))

(define (match-operands specs operands)
  (and (= (length specs) (length operands))
       (for/and ([spec (in-list specs)]
                 [op (in-list operands)])
         (operand-matches? spec op))))

;; ---------------------------------------------------------------------------
;; encoding helpers
;; ---------------------------------------------------------------------------

(define (effective-width enc ops)
  (define mode (enc-spec-size-mode enc))
  (define nw? (enc-spec-nw? enc))
  (define (first-rm-width)
    (for/first ([op (in-list ops)]
                #:when (or (gpr-op? op) (mem? op)))
      (reg-width-of op)))
  (case mode
    [(o8) 8]
    [(o16) 16]
    [(o32) (if nw? 64 32)]
    [(o64) 64]
    [(osz osm odf #f) (or (first-rm-width) 0)]
    [else (or (first-rm-width) 0)]))

(define (need-66? enc width)
  (define mode (enc-spec-size-mode enc))
  (and (= width 16)
       (or (eq? mode 'o16)
           (and (enc-spec-nw? enc) (memq mode '(osz osm odf #f))))))

(define (need-rex-w? enc)
  (define mode (enc-spec-size-mode enc))
  (or (enc-spec-force-rex-w? enc)
      (and (eq? mode 'o64) (not (enc-spec-nw? enc)))))

(define (imm-fits? range value)
  (and (exact-integer? value)
       (case range
         [(uint8) (fits-u8? value)]
         [(int8) (fits-s8? value)]
         [(any16) (fits-any16? value)]
         [(any32) (fits-any32? value)]
         [(int32) (fits-s32? value)]
         [(uint32) (fits-u32? value)]
         [(any64) (fits-any64? value)]
         [else #t])))

(define (imm-bytes width value)
  (case width
    [(1) (u8 value)]
    [(2) (u16 value)]
    [(4) (u32 value)]
    [(8) (u64 value)]
    [else (error 'imm-bytes "bad immediate width: ~e" width)]))

(define (normalized-operands operands)
  (for/list ([op (in-list operands)])
    ;; Integers and prepared (immN ...) wrappers are not register/memory
    ;; operands, but they still flow through matching and emission.
    (or (normalize-operand op) op)))

;; ---------------------------------------------------------------------------
;; constraint checking / form selection -> instruction-plan
;; ---------------------------------------------------------------------------

;; Returns a plan or #f.  This stage owns arity/kinds/widths, immediate range,
;; operand-size/REX policy and ModR/M addressing validation.  It does not emit
;; instruction bytes.
(define (try-plan-entry entry operands)
  (define enc (entry-encoding entry))
  (define opspecs (entry-operands entry))
  (and (match-operands opspecs operands)
       (let* ([width (effective-width enc operands)]
              [imm-specs (enc-spec-imm enc)]
              [imm (and (pair? imm-specs) (car imm-specs))]
              [imm-index (and imm (list-ref imm 3))]
              [imm-op (and imm-index (list-ref operands imm-index))]
              [imm-width (and imm (cadr imm))]
              [imm-range (and imm (caddr imm))]
              [imm-present? (if imm-op
                                (call-with-values
                                    (lambda () (immediate-operand imm-op))
                                  (lambda (present? value forced) present?))
                                #f)]
              [imm-value (if imm-op
                             (call-with-values
                                 (lambda () (immediate-operand imm-op))
                               (lambda (present? value forced) value))
                             #f)]
              [imm-forced (if imm-op
                              (call-with-values
                                  (lambda () (immediate-operand imm-op))
                                (lambda (present? value forced) forced))
                              #f)])
         (and (or (not imm) imm-present?)
              (or (not imm) (not imm-forced) (= imm-forced imm-width))
              (or (not imm) (not (exact-integer? imm-value))
                  (imm-fits? imm-range imm-value))
              (let* ([mandatory (enc-spec-prefixes enc)]
                     [prefixes (if (and (need-66? enc width)
                                        (not (memq #x66 mandatory)))
                                   (cons #x66 mandatory)
                                   mandatory)]
                     [rm-enc
                      (if (enc-spec-modrm-rm enc)
                          (let* ([rm-op (list-ref operands
                                                  (enc-spec-modrm-rm enc))]
                                 [reg-field-spec (enc-spec-modrm-reg enc)]
                                 [reg-field
                                  (if (eq? (car reg-field-spec) 'r)
                                      (list-ref operands (cadr reg-field-spec))
                                      (cadr reg-field-spec))])
                            (encode-rm rm-op reg-field))
                          #f)]
                     [regs
                      (append*
                       (for/list ([op (in-list operands)])
                         (regs-in-op op)))]
                     [opcode
                      (if (enc-spec-plus-r enc)
                          (let* ([r (list-ref operands (enc-spec-plus-r enc))]
                                 [idx (and (reg? r) (reg-index r))])
                            (unless idx
                              (error 'plan-instruction
                                     "generated +r operand is not a register: ~e"
                                     (entry-mnemonic entry)))
                            (add-opcode-register (enc-spec-opcode enc) idx))
                          (enc-spec-opcode enc))]
                     [rex-w? (need-rex-w? enc)]
                     [rex-r (or (and rm-enc (rm-encoding-rex-r rm-enc)) 0
                                (if (enc-spec-rex-r? enc) 1 0))]
                     [rex-x (or (and rm-enc (rm-encoding-rex-x rm-enc)) 0
                                (if (enc-spec-rex-x? enc) 1 0))]
                     [rex-b (or (and rm-enc (rm-encoding-rex-b rm-enc)) 0
                                (if (enc-spec-rex-b? enc) 1 0))]
                     [rex (make-rex rex-w? regs rex-r rex-x rex-b)])
                (instruction-plan (entry-mnemonic entry)
                                  entry
                                  operands
                                  width
                                  (enc-spec-wait? enc)
                                  (and rm-enc (rm-encoding-seg rm-enc))
                                  prefixes
                                  rex
                                  opcode
                                  rm-enc
                                  imm-width
                                  imm-value))))))

(define (add-opcode-register opcode index)
  (cond
    [(null? opcode) (error 'add-opcode-register "empty opcode")]
    [else
     (define rev (reverse opcode))
     (reverse (cons (+ (car rev) (bitwise-and index #b111))
                    (cdr rev)))]))

(define (generic-plan-instruction name operands)
  (define candidates (hash-ref entries-by-name name '()))
  (define normalized (normalized-operands operands))
  (define plans
    (for/list ([e (in-list candidates)])
      (try-plan-entry e normalized)))
  (define valid (filter values plans))
  (cond
    [(null? valid)
     (error 'plan-instruction
            "no NASM form matches ~a with operands ~e"
            name operands)]
    [else
     (argmin plan-size valid)]))

;; Size is derived from the plan fields; it is the same computation layout uses
;; before the encoder is asked for bytes.
(define (plan-size plan)
  (define rm-enc (instruction-plan-rm-enc plan))
  (+ (if (instruction-plan-wait? plan) 1 0)
     (if (instruction-plan-segment-prefix plan) 1 0)
     (length (instruction-plan-prefixes plan))
     (if (instruction-plan-rex plan) 1 0)
     (length (instruction-plan-opcode plan))
     (if rm-enc 1 0)
     (if (and rm-enc (rm-encoding-sib rm-enc)) 1 0)
     (if rm-enc (length (rm-encoding-disp rm-enc)) 0)
     (or (instruction-plan-imm-width plan) 0)))

;; ---------------------------------------------------------------------------
;; plan -> bytes
;; ---------------------------------------------------------------------------

;; This stage is deliberately policy-free: it only concatenates the choices
;; already fixed by try-plan-entry / generic-plan-instruction.
(define (encode-plan plan)
  (define rm-enc (instruction-plan-rm-enc plan))
  (define imm-width (instruction-plan-imm-width plan))
  (bytes*
   (if (instruction-plan-wait? plan) (list #x9b) '())
   (if (instruction-plan-segment-prefix plan)
       (list (instruction-plan-segment-prefix plan))
       '())
   (instruction-plan-prefixes plan)
   (let ([rex (instruction-plan-rex plan)])
     (if rex (list rex) '()))
   (instruction-plan-opcode plan)
   (if rm-enc (list (rm-encoding-modrm rm-enc)) '())
   (if (and rm-enc (rm-encoding-sib rm-enc))
       (list (rm-encoding-sib rm-enc))
       '())
   (if rm-enc (rm-encoding-disp rm-enc) '())
   (if imm-width
       (imm-bytes imm-width (instruction-plan-imm-value plan))
       '())))

(define (generic-instruction-size name operands)
  (plan-size (generic-plan-instruction name operands)))

(define (generic-encode-instruction name operands)
  (encode-plan (generic-plan-instruction name operands)))

(define (generic-instruction-arity name)
  (define es (hash-ref entries-by-name name '()))
  (define ns (remove-duplicates (map (lambda (e) (length (entry-operands e))) es)))
  (and (= 1 (length ns)) (car ns)))
