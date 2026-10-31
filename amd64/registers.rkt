#lang racket
;;; amd64/registers.rkt
;;;
;;; 寄存器名、class（GPR/XMM）、宽度和编码编号。只放事实，不做分配。

(provide (struct-out reg)
         lookup-register
         register-name?
         gpr-register?
         xmm-register?
         reg-class
         reg-width
         reg-index
         reg-rex8?
         reg-high8?
         reg-name)

;; class = 'gpr | 'xmm.  Width is the natural register width; XMM registers
;; have width 128 but SSE encoders do not treat that as an operand-size prefix.
(struct reg (name width index rex8? high8? class) #:transparent)

(define register-list
  '(
    ;; 8-bit, no REX
    (al   8  0 #f #f)
    (cl   8  1 #f #f)
    (dl   8  2 #f #f)
    (bl   8  3 #f #f)
    ;; 8-bit, high-byte; cannot be used with REX
    (ah   8  4 #f #t)
    (ch   8  5 #f #t)
    (dh   8  6 #f #t)
    (bh   8  7 #f #t)
    ;; 8-bit, require REX
    (spl  8  4 #t #f)
    (bpl  8  5 #t #f)
    (sil  8  6 #t #f)
    (dil  8  7 #t #f)
    (r8b  8  8 #t #f)
    (r9b  8  9 #t #f)
    (r10b 8 10 #t #f)
    (r11b 8 11 #t #f)
    (r12b 8 12 #t #f)
    (r13b 8 13 #t #f)
    (r14b 8 14 #t #f)
    (r15b 8 15 #t #f)

    ;; 16-bit
    (ax   16 0 #f #f)
    (cx   16 1 #f #f)
    (dx   16 2 #f #f)
    (bx   16 3 #f #f)
    (sp   16 4 #f #f)
    (bp   16 5 #f #f)
    (si   16 6 #f #f)
    (di   16 7 #f #f)
    (r8w  16 8 #f #f)
    (r9w  16 9 #f #f)
    (r10w 16 10 #f #f)
    (r11w 16 11 #f #f)
    (r12w 16 12 #f #f)
    (r13w 16 13 #f #f)
    (r14w 16 14 #f #f)
    (r15w 16 15 #f #f)

    ;; 32-bit
    (eax  32 0 #f #f)
    (ecx  32 1 #f #f)
    (edx  32 2 #f #f)
    (ebx  32 3 #f #f)
    (esp  32 4 #f #f)
    (ebp  32 5 #f #f)
    (esi  32 6 #f #f)
    (edi  32 7 #f #f)
    (r8d  32 8 #f #f)
    (r9d  32 9 #f #f)
    (r10d 32 10 #f #f)
    (r11d 32 11 #f #f)
    (r12d 32 12 #f #f)
    (r13d 32 13 #f #f)
    (r14d 32 14 #f #f)
    (r15d 32 15 #f #f)

    ;; 64-bit
    (rax  64 0 #f #f)
    (rcx  64 1 #f #f)
    (rdx  64 2 #f #f)
    (rbx  64 3 #f #f)
    (rsp  64 4 #f #f)
    (rbp  64 5 #f #f)
    (rsi  64 6 #f #f)
    (rdi  64 7 #f #f)
    (r8   64 8 #f #f)
    (r9   64 9 #f #f)
    (r10  64 10 #f #f)
    (r11  64 11 #f #f)
    (r12  64 12 #f #f)
    (r13  64 13 #f #f)
    (r14  64 14 #f #f)
    (r15  64 15 #f #f)))

(define xmm-register-list
  (for/list ([i (in-range 16)])
    (list (string->symbol (format "xmm~a" i)) 128 i #f #f 'xmm)))

(define control-register-list
  '((cr0 0) (cr2 2) (cr3 3) (cr4 4) (cr8 8)))

(define debug-register-list
  (for/list ([i (in-range 8)])
    (list (string->symbol (format "dr~a" i)) i)))

(define registers
  (let ([h (make-hash)])
    (for ([r (in-list register-list)])
      (hash-set! h (car r) (apply reg (append r (list 'gpr)))))
    (for ([r (in-list xmm-register-list)])
      (hash-set! h (car r) (apply reg r)))
    (for ([r (in-list control-register-list)])
      (hash-set! h (car r) (reg (car r) 64 (cadr r) #f #f 'control)))
    (for ([r (in-list debug-register-list)])
      (hash-set! h (car r) (reg (car r) 64 (cadr r) #f #f 'debug)))
    h))

(define missing (gensym 'missing-register))

(define (lookup-register name [default missing])
  (cond
    [(hash-ref registers name #f)]
    [(eq? default missing)
     (error 'lookup-register "unknown amd64 register: ~e" name)]
    [else default]))

(define (register-name? name) (and (hash-ref registers name #f) #t))
(define (gpr-register? r) (and (reg? r) (eq? (reg-class r) 'gpr)))
(define (xmm-register? r) (and (reg? r) (eq? (reg-class r) 'xmm)))
