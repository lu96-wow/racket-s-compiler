#lang racket
;;; amd64/amd64-asm/insn-generic.rkt
;;;
;;; Interpreter for the NASM-derived instruction table emitted by
;;; binary-build/.  The table is data; this module owns the matching and
;;; byte emission rules.  It is intentionally separate from insn.rkt's
;;; handwritten special encoders: generated forms are the fallback (and
;;; the future primary path) for instructions without a special case.

(require racket/list
         "sexp.rkt"
         "registers.rkt"
         "insn-core.rkt"
         "generated/gen/insn/nasm.rkt")

(provide generic-instruction?
         generic-instruction-arity
         generic-encode-instruction
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
         [(uint8) (<= 0 value 255)]
         [(int8) (<= -128 value 127)]
         [(any16) (<= (- (expt 2 15)) value (sub1 (expt 2 16)))]
         [(any32) (<= (- (expt 2 31)) value (sub1 (expt 2 32)))]
         [(int32) (<= (- (expt 2 31)) value (sub1 (expt 2 31)))]
         [(uint32) (<= 0 value (sub1 (expt 2 32)))]
         [(any64) (<= (- (expt 2 63)) value (sub1 (expt 2 64)))]
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

(define (encode-entry entry ns)
  (define enc (entry-encoding entry))
  (define opspecs (entry-operands entry))
  (define operands (normalized-operands ns))
  (and (match-operands opspecs operands)
       (let* ([width (effective-width enc operands)]
              [size-mode (enc-spec-size-mode enc)])
         (let* ([imm-specs (enc-spec-imm enc)]
                     [imm (and (pair? imm-specs) (car imm-specs))]
                     [imm-index (and imm (list-ref imm 3))]
                     [imm-op (and imm-index (list-ref operands imm-index))]
                     [imm-width (and imm (cadr imm))]
                     [imm-range (and imm (caddr imm))]
                     [imm-present? (if imm-op
                                       (call-with-values
                                           (lambda () (immediate-operand imm-op))
                                         (lambda (present? value forced)
                                           present?))
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
                            [wait-prefix (if (enc-spec-wait? enc) (list #x9b) '())]
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
                                     (error 'encode-instruction
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
                       (bytes*
                        wait-prefix
                        (if (and rm-enc (rm-encoding-seg rm-enc))
                            (list (rm-encoding-seg rm-enc))
                            '())
                        prefixes
                        (if rex (list rex) '())
                        opcode
                        (if rm-enc (list (rm-encoding-modrm rm-enc)) '())
                        (if (and rm-enc (rm-encoding-sib rm-enc))
                            (list (rm-encoding-sib rm-enc))
                            '())
                        (if rm-enc (rm-encoding-disp rm-enc) '())
                        (if imm
                            (imm-bytes imm-width imm-value)
                            '()))))))))

(define (add-opcode-register opcode index)
  (cond
    [(null? opcode) (error 'add-opcode-register "empty opcode")]
    [else
     (define rev (reverse opcode))
     (reverse (cons (+ (car rev) (bitwise-and index #b111))
                    (cdr rev)))]))

(define (generic-encode-instruction name operands)
  (define candidates (hash-ref entries-by-name name '()))
  (define encoded
    (for/list ([e (in-list candidates)]
               #:when (match-operands (entry-operands e)
                                      (normalized-operands operands)))
      (define bs (encode-entry e operands))
      (and bs (list bs e))))
  (define valid (filter values encoded))
  (cond
    [(null? valid)
     (error 'encode-instruction
            "no NASM form matches ~a with operands ~e"
            name operands)]
    [else
     (car (argmin (lambda (p) (length (car p))) valid))]))

(define (generic-instruction-arity name)
  (define es (hash-ref entries-by-name name '()))
  (define ns (remove-duplicates (map (lambda (e) (length (entry-operands e))) es)))
  (and (= 1 (length ns)) (car ns)))
