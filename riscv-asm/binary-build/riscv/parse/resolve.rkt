#lang racket/base

(require racket/list
         "struct.rkt")

;; ============================================================
;; 扩展依赖解析
;;
;; 最终定义按以下优先级合并同名项：
;;   1. 当前扩展的 standard 定义
;;   2. import 进来的 standard 定义
;;   3. 与所依赖 standard 指令 fixed fields 兼容的 pseudo
;;   4. 其他 pseudo（仅作为兜底，并记录 ambiguous-pseudo）
;;
;; 不再使用“源文件里谁先出现就用谁”的隐式规则。
;; ============================================================

(struct candidate (definition kind pseudo standard-form?)
  #:transparent)

(struct skipped-definition (name reason)
  #:transparent)

(define (find-instruction defs name)
  (for/first ([idef (in-list defs)]
              #:when (equal? (instruction-def-name idef) name))
    idef))

(define (resolve-imports extension-file extension-map)
  (for/list ([im (in-list (extension-file-imports extension-file))])
    (define source-extension (import-def-source-extension im))
    (define instruction-name (import-def-instruction-name im))
    (define source-file (hash-ref extension-map source-extension #f))
    (unless source-file
      (error 'resolve-imports
             "cannot resolve import ~a::~a"
             source-extension instruction-name))
    (define idef
      (find-instruction (extension-file-standard source-file)
                        instruction-name))
    (unless idef
      (error 'resolve-imports
             "instruction ~a::~a not found in ~a"
             source-extension
             instruction-name
             (extension-file-path source-file)))
    idef))

(define (validate-pseudo-source! pseudo extension-map)
  (define source-extension (pseudo-def-source-extension pseudo))
  (define source-instruction (pseudo-def-source-instruction pseudo))
  (define source-file (hash-ref extension-map source-extension #f))
  (unless source-file
    (error 'validate-pseudo-source!
           "pseudo ~a references unknown extension ~a"
           (pseudo-def-name pseudo)
           source-extension))
  (unless (find-instruction (extension-file-standard source-file)
                            source-instruction)
    (error 'validate-pseudo-source!
           "pseudo ~a references unknown instruction ~a::~a"
           (pseudo-def-name pseudo)
           source-extension
           source-instruction)))

;; ------------------------------------------------------------
;; fixed fields 兼容性
;; ------------------------------------------------------------

(define (fixed-field-bit-map fixed-fields)
  (for*/fold ([bits (hash)])
             ([ff (in-list fixed-fields)]
              [bit (in-range (fixed-field-lo ff)
                             (add1 (fixed-field-hi ff)))])
    (hash-set bits
              bit
              (bitwise-and
               (arithmetic-shift (fixed-field-value ff)
                                 (- bit (fixed-field-lo ff)))
               1))))

;; 候选定义必须固定住 source 指令的每一个 fixed bit，且值相同。
;; 候选额外固定更多 bit 是允许的。
(define (fixed-fields-compatible? source-fixed candidate-fixed)
  (define candidate-bits (fixed-field-bit-map candidate-fixed))
  (for*/and ([ff (in-list source-fixed)]
             [bit (in-range (fixed-field-lo ff)
                            (add1 (fixed-field-hi ff)))])
    (equal? (hash-ref candidate-bits bit #f)
            (bitwise-and
             (arithmetic-shift (fixed-field-value ff)
                               (- bit (fixed-field-lo ff)))
             1))))

(define (pseudo-standard-form? pseudo extension-map)
  (define source-extension (pseudo-def-source-extension pseudo))
  (define source-instruction (pseudo-def-source-instruction pseudo))
  (define source-file (hash-ref extension-map source-extension #f))
  (define source-def
    (and source-file
         (find-instruction (extension-file-standard source-file)
                           source-instruction)))
  (and source-def
       (fixed-fields-compatible?
        (instruction-def-fixed-fields source-def)
        (instruction-def-fixed-fields
         (pseudo-def-instruction pseudo)))))

;; ------------------------------------------------------------
;; 同名定义合并
;; ------------------------------------------------------------

(define (predictable-priority candidate)
  (case (candidate-kind candidate)
    [(standard) 3]
    [(import) 2]
    [(pseudo) (if (candidate-standard-form? candidate) 1 0)]
    [else 0]))

(define (choose-winner candidates extension-map)
  (define winner
    (argmax (lambda (c) (predictable-priority c)) candidates))
  (define losers (remove winner candidates))
  (values winner losers))

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
       [(candidate-standard-form? winner)
        "not-a-standard-form"]
       [else
        "ambiguous-pseudo"])]
    [else "duplicate-definition"]))

(define (prepare-extension-defs extension-file extension-map)
  (for ([pseudo (in-list (extension-file-pseudo extension-file))])
    (validate-pseudo-source! pseudo extension-map))

  (define candidates
    (append
     (for/list ([idef (in-list (extension-file-standard extension-file))])
       (candidate idef 'standard #f #t))
     (for/list ([idef (in-list (resolve-imports extension-file extension-map))])
       (candidate idef 'import #f #t))
     (for/list ([pseudo (in-list (extension-file-pseudo extension-file))])
       (candidate (pseudo-def-instruction pseudo)
                  'pseudo
                  pseudo
                  (pseudo-standard-form? pseudo extension-map)))))

  (define by-name (make-hash))
  (define order '())
  (for ([candidate (in-list candidates)])
    (define name (instruction-def-name (candidate-definition candidate)))
    (unless (hash-has-key? by-name name)
      (set! order (cons name order)))
    (hash-update! by-name name (lambda (cs) (cons candidate cs)) '()))

  (define chosen '())
  (define skipped '())
  (for ([name (in-list (reverse order))])
    (define group (reverse (hash-ref by-name name)))
    (define-values (winner losers) (choose-winner group extension-map))
    (set! chosen (cons (candidate-definition winner) chosen))
    (for ([loser (in-list losers)])
      (set! skipped
            (cons (skipped-definition name (skip-reason winner loser))
                  skipped))))

  (values (reverse chosen)
          (reverse skipped)))

(provide find-instruction
         resolve-imports
         validate-pseudo-source!
         prepare-extension-defs
         skipped-definition
         skipped-definition?
         skipped-definition-name
         skipped-definition-reason)
