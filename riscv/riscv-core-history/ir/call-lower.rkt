#lang racket
;;; ir/call-lower.rkt
;;;
;;; call / return lowering。
;;;
;;; 第一版约定（见 CALL.md）：
;;;   - 参数全部写 caller 的 outgoing stack area；
;;;   - 返回值最多 1 个，放 x10；
;;;   - x1 RA，x2 SP，x8 FP；
;;;   - 第一版无 callee-saved；
;;;   - call 变 (call-target (global ...))；
;;;   - return 插 epilogue，term 变 (term (return))。
;;;
;;; 最终 jal / jalr / far call 由 layout-relax 选。

(require racket/list
         "../../riscv-help/ranges.rkt"
         "../core/sexp.rkt"
         "shape.rkt"
         "frame.rkt"
         "li.rkt"
         "scratch.rkt")

(provide lower-calls)

(define ra '(native x1))
(define sp '(native x2))
(define fp '(native x8))
(define ret '(native x10))

(define (lower-calls func frame
                     #:xlen [xlen 64]
                     #:scratch [scratch #f])
  (unless (and (tagged? func 'func) (>= (length func) 2))
    (error 'call-lower "expected a func: ~e" func))
  (unless (frame-form? frame)
    (error 'call-lower "malformed frame: ~e" frame))
  (unless (memq xlen '(32 64))
    (error 'call-lower "xlen must be 32 or 64: ~e" xlen))

  (define scratch-regs
    (if scratch (normalize-scratch scratch 'call-lower)
        (func-scratch func 'call-lower)))
  (check-scratch! scratch-regs)

  (define name (cadr func))
  (define body (cddr func))
  (define entry-form
    (findf (lambda (x) (and (form? x) (eq? (car x) 'entry))) body))
  (unless entry-form
    (error 'call-lower "func ~a: missing entry" (chain->string name)))
  (define entry-name (cadr entry-form))

  (define block-forms
    (filter (lambda (x) (and (form? x) (eq? (car x) 'block))) body))
  (unless (ormap (lambda (b) (eq? (cadr b) entry-name)) block-forms)
    (error 'call-lower "func ~a: entry block ~a is not declared"
           (chain->string name) entry-name))

  (define prologue (make-prologue frame xlen scratch-regs))
  (define lowered-blocks
    (for/list ([block (in-list block-forms)])
      (lower-block block
                   (eq? (cadr block) entry-name)
                   prologue
                   frame xlen scratch-regs)))

  (define scratch-form
    (if (null? scratch-regs)
        '()
        (list (cons 'scratch scratch-regs))))

  (cons 'func
        (cons name
              (append (list frame)
                      scratch-form
                      (list entry-form)
                      lowered-blocks))))

;; ---------------------------------------------------------------------------
;; prologue / epilogue
;; ---------------------------------------------------------------------------

(define (make-prologue frame xlen scratch-regs)
  (define pool (make-scratch-pool scratch-regs))
  (define t (take-scratch! pool 'call-lower))
  (define size (frame-size frame))
  (define frame-adjust
    (cond
      [(fits-s12? (- size))
       (list (list 'addi sp sp (- size)))]
      [else
       (define t2 (take-scratch! pool 'call-lower))
       (append (emit-li t2 size xlen)
               (list (list 'sub sp sp t2)))]))
  (append
   (list (list 'addi t fp 0)       ; save old FP
         (list 'addi fp sp 0))     ; FP = caller SP
   frame-adjust
   (list (store-word -8 fp ra xlen)
         (store-word -16 fp t xlen))))

(define (make-epilogue _frame xlen scratch-regs)
  (define pool (make-scratch-pool scratch-regs))
  (define t (take-scratch! pool 'call-lower))
  (list (load-word ra fp -8 xlen)
        (load-word t fp -16 xlen)
        (list 'addi sp fp 0)
        (list 'addi fp t 0)))

;; ---------------------------------------------------------------------------
;; block
;; ---------------------------------------------------------------------------

(define (lower-block block entry? prologue frame xlen scratch-regs)
  (define name (cadr block))
  (define forms (cddr block))
  (define term (last forms))
  (define ops (drop-right forms 1))

  (define lowered-ops
    (append* (for/list ([op (in-list ops)])
               (lower-op op frame xlen scratch-regs))))
  (define-values (term-ops lowered-term)
    (lower-term term frame xlen scratch-regs))

  (define body-ops
    (append (if entry? prologue '())
            lowered-ops
            term-ops))

  (cons 'block (cons name (append body-ops (list lowered-term)))))

(define (lower-op op frame xlen scratch-regs)
  (define head (car op))
  (case head
    [(call) (lower-call op frame xlen scratch-regs)]
    [(call-target)
     (error 'call-lower "call lowering appears to run twice: ~e" op)]
    [else (list op)]))

(define (lower-term term frame xlen scratch-regs)
  (define expr (cadr term))
  (match expr
    [(list 'return operands ...)
     (when (> (length operands) 1)
       (error 'call-lower
              "first version supports at most one return value: ~e"
              operands))
     (define ret-ops
       (cond
         [(null? operands) '()]
         [else
          (define operand (car operands))
          (cond
            [(and (physical-register? operand) (equal? operand ret))
             '()]
            [(physical-register? operand)
             (list (list 'addi ret operand 0))]
            [(exact-integer? operand)
             (emit-li ret operand xlen)]
            [else
             (error 'call-lower "unsupported return operand: ~e" operand)])]))
     (values (append ret-ops (make-epilogue frame xlen scratch-regs))
             (list 'term (list 'return)))]
    [_ (values '() term)]))

;; ---------------------------------------------------------------------------
;; call
;; ---------------------------------------------------------------------------

(define (lower-call op frame xlen scratch-regs)
  (define dst (cadr op))
  (define target (caddr op))
  (define args (cdddr op))
  (unless (physical-register? dst)
    (error 'call-lower "call destination must be a physical register: ~e" dst))
  (unless (global-ref? target)
    (error 'call-lower "call target must be (global chain): ~e" target))

  (define word (quotient xlen 8))
  (define outgoing (frame-outgoing frame))
  (define needed (* (length args) word))
  (when (> needed outgoing)
    (error 'call-lower
           "call needs ~a outgoing bytes, frame only reserves ~a"
           needed outgoing))

  (define pool (make-scratch-pool scratch-regs))
  ;; 参数可能已经由 materialize load 到 scratch 里了。
  ;; call-lower 自己选 scratch 时不能覆盖这些寄存器。
  (define arg-registers
    (for/list ([arg (in-list args)] #:when (physical-register? arg)) arg))
  (define int-scratch #f)
  (define addr-scratch #f)

  (define (get-int-scratch!)
    (or int-scratch
        (let ([s (take-scratch-avoiding! pool arg-registers 'call-lower)])
          (set! int-scratch s)
          s)))

  (define (get-addr-scratch!)
    (or addr-scratch
        (let ([s (take-scratch-avoiding! pool arg-registers 'call-lower)])
          (set! addr-scratch s)
          s)))

  (define arg-ops
    (append*
     (for/list ([arg (in-list args)]
                [index (in-naturals)])
       (define offset (* index word))
       (define-values (arg-reg pre-ops)
         (cond
           [(physical-register? arg) (values arg '())]
           [(exact-integer? arg)
            (define s (get-int-scratch!))
            (values s (emit-li s arg xlen))]
           [else
            (error 'call-lower "unsupported call argument: ~e" arg)]))
       (cond
         [(fits-s12? offset)
          (append pre-ops
                  (list (store-word offset sp arg-reg xlen)))]
         [else
          (define a (get-addr-scratch!))
          (append pre-ops
                  (emit-li a offset xlen)
                  (list (list 'add a sp a)
                        (store-word 0 a arg-reg xlen))) ]))))

  (define move-result
    (if (equal? dst ret)
        '()
        (list (list 'addi dst ret 0))))

  (append arg-ops
          (list (list 'call-target target))
          move-result))

;; ---------------------------------------------------------------------------
;; word load/store
;; ---------------------------------------------------------------------------

(define (store-word offset base src xlen)
  (define word (quotient xlen 8))
  (define mnemonic (if (= word 8) 'sd 'sw))
  (list mnemonic offset base src))

(define (load-word dst base offset xlen)
  (define word (quotient xlen 8))
  (define mnemonic (if (= word 8) 'ld 'lw))
  (list mnemonic dst base offset))

;; ---------------------------------------------------------------------------
;; scratch
;; ---------------------------------------------------------------------------

(define (check-scratch! scratch-regs)
  (define forbidden (list '(native x0) '(native x1) '(native x2)
                          '(native x8) '(native x10) '(native x11)))
  (for ([reg (in-list scratch-regs)])
    (when (member reg forbidden)
      (error 'call-lower "scratch register ~e is reserved by the runtime contract" reg))))


