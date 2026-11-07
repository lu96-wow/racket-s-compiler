#lang racket/base

;; ============================================================
;; 跳转：形式 + 落点回归
;;
;; 光比指令形状不够 —— jump*/branch* 的错都是"形状看着对、落点差几字节"。
;; 所以这里带一个迷你解释器，把展开结果真的走一遍，验证落点。
;; ============================================================

(require rackunit
         racket/string
         "../jump.rkt"
         "../branch.rkt"
         "../registers.rkt")

;; ------------------------------------------------------------
;; 迷你解释器
;; ------------------------------------------------------------

(define XLEN 64)
(define MASK (sub1 (arithmetic-shift 1 XLEN)))

(define (sx bits value)
  (define modulus (arithmetic-shift 1 bits))
  (define u (bitwise-and value (sub1 modulus)))
  (if (>= u (arithmetic-shift 1 (sub1 bits))) (- u modulus) u))

(define (instruction-size insn)
  (if (string-prefix? (symbol->string (car insn)) "c.") 2 4))

;; 执行 insns（从 pc0 开始），返回控制流第一次离开这段代码时的目标地址。
;; 只支持这些展开器会生成的指令。
(define (run-to-landing insns pc0)
  (define regs (make-hash))
  (define (read-reg reg)
    (if (zero-register? reg) 0 (hash-ref regs (register->number reg) 0)))
  (define (write-reg reg value)
    (unless (zero-register? reg)
      (hash-set! regs (register->number reg) (bitwise-and value MASK))))
  (let loop ([rest insns] [pc pc0])
    (cond
      [(null? rest) pc]
      [else
       (define insn (car rest))
       (define op (car insn))
       (define args (cdr insn))
       (define next (+ pc (instruction-size insn)))
       (case op
         [(auipc) (write-reg (car args)
                             (+ pc (arithmetic-shift (sx 20 (cadr args)) 12)))
                  (loop (cdr rest) next)]
         [(lui) (write-reg (car args) (arithmetic-shift (sx 20 (cadr args)) 12))
                (loop (cdr rest) next)]
         [(addi) (write-reg (car args)
                            (+ (read-reg (cadr args)) (sx 12 (caddr args))))
                  (loop (cdr rest) next)]
         ;; addiw 把 32 位结果重新符号扩展。
         [(addiw) (write-reg (car args)
                             (sx 32 (+ (read-reg (cadr args)) (sx 12 (caddr args)))))
                   (loop (cdr rest) next)]
         [(add) (write-reg (car args) (+ (read-reg (cadr args)) (read-reg (caddr args))))
                (loop (cdr rest) next)]
         [(slli) (write-reg (car args) (arithmetic-shift (read-reg (cadr args)) (caddr args)))
                 (loop (cdr rest) next)]
         [(srli) (write-reg (car args) (arithmetic-shift (read-reg (cadr args)) (- (caddr args))))
                 (loop (cdr rest) next)]
         [(jal) (write-reg (car args) next)
                (+ pc (cadr args))]
         [(jalr) (define target
                   (bitwise-and (+ (read-reg (cadr args)) (sx 12 (caddr args)))
                                MASK -2))
                 (write-reg (car args) next)
                 target]
         [(c.j) (+ pc (car args))]
         [else (error 'run-to-landing "unsupported instruction: ~a" insn)])])))

(define (check-landing who insns pc0 expected)
  (check-equal? (bitwise-and (run-to-landing insns pc0) MASK)
                (bitwise-and expected MASK)
                who))

;; ------------------------------------------------------------
;; jump-auipc-jalr：零寄存器的三种写法必须走同一条路
;;
;; 用 (eq? link 'zero) 时, 'x0 / 0 会掉进 else 分支, 生成
;;   (auipc x0 hi) (jalr x0 x0 lo)   —— 静默跳到 lo。
;; ------------------------------------------------------------

(for ([link (in-list (list 'zero 'x0 0))])
  (check-equal? (jump-auipc-jalr link 4096 #:scratch '(t0))
                '((auipc t0 1) (jalr zero t0 0))
                (format "link=~a 应借 scratch 当 base" link)))

;; link 非零：它自己就是 auipc 的落点，不需要 scratch。
(check-equal? (jump-auipc-jalr 'ra 4096) '((auipc ra 1) (jalr ra ra 0)))
(check-equal? (jump-auipc-jalr 'x1 4096) '((auipc x1 1) (jalr x1 x1 0)))
;; 非得给 scratch 也不影响形状。
(check-equal? (jump-auipc-jalr 'ra 4096 #:scratch '(t0))
              '((auipc ra 1) (jalr ra ra 0)))

(check-landing "jump-auipc-jalr link=zero" 
               (jump-auipc-jalr 'zero 4096 #:scratch '(t0)) 0 4096)
(check-landing "jump-auipc-jalr link=ra"
               (jump-auipc-jalr 'ra 4096) 0 4096)

;; 负偏移也要对：auipc 的 hi 是补码。
(check-landing "jump-auipc-jalr 负偏移"
               (jump-auipc-jalr 'ra -4096) 0 -4096)

;; ------------------------------------------------------------
;; jump-pcrel-far：auipc 必须是第一条
;;
;; 它的 offset 基准是 auipc 自己。li 放在 auipc 前面会整体差 li-size。
;; ------------------------------------------------------------

(check-equal? (jump-pcrel-far 'zero 1000 #:scratch '(t0 t1))
              '((auipc t0 0) (addi t1 x0 1000) (add t0 t0 t1) (jalr zero t0 0)))

(check-equal? (car (jump-pcrel-far 'ra #x100000000 #:scratch '(t0)))
              '(auipc ra 0))

(for ([offset (in-list (list 8 1000 4096 #x7ffffffe #x100000000))])
  (check-landing (format "jump-pcrel-far(~x) link=zero" offset)
                 (jump-pcrel-far 'zero offset #:scratch '(t0 t1))
                 0 offset)
  (check-landing (format "jump-pcrel-far(~x) link=ra" offset)
                 (jump-pcrel-far 'ra offset #:scratch '(t0))
                 0 offset))

(check-landing "jump-pcrel-far 负偏移"
               (jump-pcrel-far 'ra -4096 #:scratch '(t0)) 0 -4096)

;; 序列长度和 li-size 无关的旧 bug 会在这里暴露：li 有几条，落点就该一样。
(check-landing "jump-pcrel-far 小 offset 与 大 offset 落点都精确"
               (jump-pcrel-far 'zero 1000 #:scratch '(t0 t1)) 0 1000)

;; ------------------------------------------------------------
;; branch-long：反向分支跳过的长度 = 4 + jump 序列长度
;;
;; 反向分支在 0，jump 序列在 4；pc 相对偏移从分支自身算起，
;; 所以 skip = 4 + |jump|，落点 = 0 + skip = 序列末尾。
;; ------------------------------------------------------------

(define (check-branch-long who mnemonic offset expander)
  (define insns (branch-long mnemonic 'a0 'a1 offset expander))
  (define skip (cadddr (car insns)))
  (define jump (cdr insns))
  (define jump-size (for/sum ([i (in-list jump)]) (instruction-size i)))
  (check-equal? skip (+ 4 jump-size)
                (format "~a: 反向分支的 skip" who))
  (check-true (and (even? skip) (>= skip 0)))
  ;; 条件为假 -> 反向分支跳过 jump 序列
  (check-equal? skip (+ 4 jump-size))
  ;; 条件为真 -> jump 序列从 +4 起飞，落点必须是 offset
  (check-landing (format "~a: jump 序列落点" who) jump 4 offset))

(check-branch-long "branch-far" 'beq 1000
                   (lambda (offset) (jump-jal 'zero offset)))

(check-branch-long "branch-indirect" 'beq 1000
                   (lambda (offset) (jump-auipc-jalr 'zero offset #:scratch '(t0))))

;; jump-pcrel-far 当 expander（以前的基准错位会在这里变成 1004）
(check-branch-long "branch-long + jump-pcrel-far" 'beq 1000
                   (lambda (offset) (jump-pcrel-far 'zero offset #:scratch '(t0 t1))))

;; 反向分支的助记符要对调。
(check-equal? (car (branch-long 'blt 'a0 'a1 8 (lambda (o) (jump-jal 'zero o))))
              '(bge a0 a1 8))

;; 形状固定：branch-far 8 字节、branch-indirect 12 字节（layout/forms.rkt 依赖）。
(define (expanded-size insns)
  (for/sum ([i (in-list insns)]) (instruction-size i)))
(check-equal? (expanded-size
               (branch-long 'beq 'a0 'a1 1000 (lambda (o) (jump-jal 'zero o))))
              8)
(check-equal? (expanded-size
               (branch-long 'beq 'a0 'a1 1000
                            (lambda (o) (jump-auipc-jalr 'zero o #:scratch '(t0)))))
              12)

;; ------------------------------------------------------------
;; 参数校验
;; ------------------------------------------------------------

;; scratch 不能是零寄存器, 不能重复。
(check-exn exn:fail?
           (lambda () (jump-auipc-jalr 'zero 4096 #:scratch '(x0))))
(check-exn exn:fail?
           (lambda () (jump-pcrel-far 'zero 4096 #:scratch '(t0 x0))))
(check-exn exn:fail?
           (lambda () (jump-pcrel-far 'zero 4096 #:scratch '(t0 t0))))
(check-exn exn:fail?
           (lambda () (jump-pcrel-far 'zero 4096 #:scratch '(t0))))
(check-exn exn:fail?
           (lambda () (jump-pcrel-far 'ra 4096 #:scratch '(ra))))
;; 奇数偏移编不出来（jalr 会清 bit0），必须拒绝而不是静默取整。
(check-exn exn:fail?
           (lambda () (jump-auipc-jalr 'ra 4097)))
(check-exn exn:fail?
           (lambda () (jump-pcrel-far 'ra 4097 #:scratch '(t0))))
