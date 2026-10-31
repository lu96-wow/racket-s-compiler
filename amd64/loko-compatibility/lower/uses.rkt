#lang racket
;;; amd64/loko-compatibility/lower/uses.rkt
;;;
;;; 一条 Loko/核心指令读了哪些伪寄存器、写了哪些伪寄存器。
;;;
;;; 这是 lower 自己的分析，不是编码器：它只关心 (reg N) 的出现位置。
;;; 目标是给 liveness.rkt 和 allocate.rkt 一个可用的近似。
;;;
;;; 规则：
;;;   - 普通双操作数算术：读两个操作数，写第一个（如果是伪寄存器）。
;;;   - mov/movzx/movsx/lea：读源/地址，写目的。
;;;   - cmp/test/comiss/ucomiss：只读。
;;;   - push/pop：push 读操作数，pop 写目的。
;;;   - call 本身不读写伪寄存器；跨调用的值由调用点的
;;;     save-live-registers / restore-live-registers 注记表达。
;;;   - 不认识的指令保守处理：读所有操作数，写其中的直接伪寄存器。
;;;
;;; 返回值中的下标没有重复，顺序按首次出现。

(require racket/match
         "../../amd64-asm/sexp.rkt"
         "pseudo.rkt")

(provide instruction-uses/sets
         operand-pseudos
         direct-pseudos)

(define (uniq xs) (remove-duplicates xs))

(define (direct-pseudos op)
  (if (pseudo-register? op)
      (list (pseudo-register-index op))
      '()))

(define (operand-pseudos op)
  (pseudo-registers-in op))

(define (pseudos-in ops)
  (uniq (append* (for/list ([op (in-list ops)]) (operand-pseudos op)))))

;; 直接写成 (reg N) 的操作数表示“这个值本身”；不是地址里的寄存器。
(define (non-direct-pseudos op)
  (if (pseudo-register? op) '() (operand-pseudos op)))

(define (directs-in ops)
  (uniq (append* (for/list ([op (in-list ops)]) (direct-pseudos op)))))

(define (two-op inst)
  (match (cdr inst)
    [(list dst src) (values dst src)]
    [_ (values #f #f)]))

(define (set-head? h)
  (and (symbol? h)
       (let ([s (symbol->string h)])
         (and (> (string-length s) 3)
              (string=? (substring s 0 3) "set")))))

(define (cmov-head? h)
  (and (symbol? h)
       (let ([s (symbol->string h)])
         (and (> (string-length s) 4)
              (string=? (substring s 0 4) "cmov")))))

(define (instruction-uses/sets inst)
  (cond
    [(not (form? inst)) (values '() '())]
    [else
     (define h (car inst))
     (define ops (cdr inst))
     (case h
       [(label comment align pad bytes fill value) (values '() '())]

       [(prefix)
        (match ops
          [(list _ inner) (instruction-uses/sets inner)]
          [_ (values (pseudos-in ops) (directs-in ops))])]

       [(mov movzx movsx movsxd movq movd movdqa movss movsd)
        (define-values (dst src) (two-op inst))
        (if dst
            (values (uniq (append (operand-pseudos src)
                                  ;; A store still reads its address, but a
                                  ;; direct pseudo-register destination is a
                                  ;; pure write.
                                  (non-direct-pseudos dst)))
                    (direct-pseudos dst))
            (values (pseudos-in ops) '()))]

       [(lea)
        (define-values (dst src) (two-op inst))
        (if dst
            (values (operand-pseudos src) (direct-pseudos dst))
            (values (pseudos-in ops) '()))]

       [(add sub and or xor adc sbb)
        (define-values (dst src) (two-op inst))
        (if dst
            (values (uniq (append (operand-pseudos dst)
                                  (operand-pseudos src)))
                    (direct-pseudos dst))
            (values (pseudos-in ops) '()))]

       [(cmp test comiss ucomiss)
        (values (pseudos-in ops) '())]

       [(inc dec neg not bswap)
        (values (pseudos-in ops) (directs-in ops))]

       [(shl shr sar sal)
        (define-values (dst src) (two-op inst))
        (if dst
            (values (uniq (append (operand-pseudos dst)
                                  (operand-pseudos src)))
                    (direct-pseudos dst))
            (values (pseudos-in ops) '()))]

       [(shrd shld)
        (match ops
          [(list dst src count)
           (values (uniq (append (operand-pseudos dst)
                                 (operand-pseudos src)
                                 (operand-pseudos count)))
                   (direct-pseudos dst))]
          [_ (values (pseudos-in ops) (directs-in ops))])]

       [(imul)
        (match ops
          [(list src)
           (values (operand-pseudos src) '())]
          [(list dst src)
           (values (uniq (append (operand-pseudos dst)
                                 (operand-pseudos src)))
                   (direct-pseudos dst))]
          [(list dst src imm)
           (values (uniq (append (operand-pseudos src)
                                 (operand-pseudos imm)))
                   (direct-pseudos dst))]
          [_ (values (pseudos-in ops) (directs-in ops))])]

       [(div idiv)
        (values (pseudos-in ops) '())]

       [(cmovcc)
        (match ops
          [(list _cc dst src)
           (values (uniq (append (operand-pseudos dst)
                                 (operand-pseudos src)))
                   (direct-pseudos dst))]
          [_ (values (pseudos-in ops) (directs-in ops))])]

       [(setcc)
        (match ops
          [(list _cc dst)
           (values (uniq (append (operand-pseudos dst)
                                 ;; partial write, keep the old value live
                                 (direct-pseudos dst)))
                   (direct-pseudos dst))]
          [_ (values (pseudos-in ops) (directs-in ops))])]

       [(push) (values (pseudos-in ops) '())]
       [(pop)
        (match ops
          [(list dst) (values (non-direct-pseudos dst) (direct-pseudos dst))]
          [_ (values (pseudos-in ops) (directs-in ops))])]
       [(xchg xadd) (values (pseudos-in ops) (directs-in ops))]

       [(call call-near call-indirect)
        ;; The target may be an indirect pseudo-register.  The call's
        ;; clobbers are not pseudo registers; call-point save/restore
        ;; annotations are the caller's responsibility.
        (values (pseudos-in ops) '())]

       [(jmp jmp-short jmp-near jmp-indirect jcc jcc-short jcc-near)
        (values (pseudos-in ops) '())]

       [(ret ud2 hlt nop syscall sysretq iretq cpuid rdtsc rdtscp)
        (values '() '())]

       [(movs stos ins outs)
        (values (pseudos-in ops) '())]

       [(in)
        (match ops
          [(list dst src)
           (values (operand-pseudos src) (direct-pseudos dst))]
          [_ (values (pseudos-in ops) (directs-in ops))])]

       [(out)
        (values (pseudos-in ops) '())]

       [(ldmxcsr stmxcsr)
        (values (pseudos-in ops) '())]

       [(rdrand rdseed)
        (values (pseudos-in ops) (directs-in ops))]

       [(cdqe cqo cdq cwd)
        (values '() '())]

       [else
        (cond
          [(set-head? h)
           (values (pseudos-in ops) (directs-in ops))]
          [(cmov-head? h)
           (values (pseudos-in ops) (directs-in ops))]
          [else
           ;; Be conservative for instructions we have not modeled yet.
           (values (pseudos-in ops) (directs-in ops))])])]))
