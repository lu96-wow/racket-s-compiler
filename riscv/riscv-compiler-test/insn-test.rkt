#lang racket
;;; insn-test.rkt -- 指令分类 / 目标位置 / 显式形式 arity

(require rackunit
         "helpers.rkt"
         (only-in "../riscv-compiler/code/insn.rkt"
                  label-form? label-path
                  branch-instruction? jump-instruction? indirect-instruction?
                  trap-instruction? ends-block? falls-through?
                  unconditional-jump? jump-target jump-target-position
                  jump-register check-transfer-arity!
                  zero-register?))

;; ---------------------------------------------------------------------------
;; 分类
;; ---------------------------------------------------------------------------

(for ([it (in-list '((beq a b L) (bne a b L) (c.beqz a L) (c.bnez a L)
                     (branch-jal beq a b L)
                     (branch-auipc-jalr s beq a b L)))])
  (check-true (branch-instruction? it) (format "branch ~s" it)))

(for ([it (in-list '((jal x0 L) (jal ra L) (c.j L) (c.jal L) (jump-auipc-jalr ra ra L)))])
  (check-true (jump-instruction? it) (format "jump ~s" it)))

(for ([it (in-list '((jalr x0 ra 0) (c.jr a0) (c.jalr a0)))])
  (check-true (indirect-instruction? it) (format "indirect ~s" it)))

(for ([it (in-list '((ecall) (ebreak) (c.ebreak)))])
  (check-true (trap-instruction? it) (format "trap ~s" it)))

(check-false (branch-instruction? '(add a b c)))
(check-false (jump-instruction? '(add a b c)))
(check-false (indirect-instruction? '(add a b c)))
(check-false (trap-instruction? '(add a b c)))

;; falls-through? / ends-block?
(check-true  (falls-through? '(beq a b L)))
(check-true  (falls-through? '(jal ra L)))
(check-false (falls-through? '(jal x0 L)))
(check-true  (falls-through? '(c.jal L)))
(check-false (falls-through? '(c.j L)))
(check-true  (falls-through? '(jalr ra ra 0)))
(check-false (falls-through? '(jalr x0 ra 0)))
(check-false (falls-through? '(c.jr a0)))
(check-true  (falls-through? '(c.jalr a0)))
(check-true  (falls-through? '(ecall)))
(check-false (falls-through? '(ebreak)))
(check-false (falls-through? '(c.ebreak)))
(check-true  (falls-through? '(add a b c)))

(for ([it (in-list '((beq a b L) (jal x0 L) (jalr x0 ra 0) (ecall)))])
  (check-true (ends-block? it) (format "ends-block ~s" it)))
(check-false (ends-block? '(add a b c)))

;; 无条件跳转 / 链接寄存器
(check-true  (unconditional-jump? '(jal x0 L)))
(check-true  (unconditional-jump? '(jal zero L)))
(check-false (unconditional-jump? '(jal ra L)))
(check-true  (unconditional-jump? '(c.j L)))
(check-false (unconditional-jump? '(c.jal L)))
(check-true  (unconditional-jump? '(jump-auipc-jalr x0 t0 L)))
(check-false (unconditional-jump? '(jump-auipc-jalr ra ra L)))

;; 目标位置
(check-equal? (jump-target '(beq (L) a b)) '(L))
(check-equal? (jump-target '(jal x0 (lib f))) '(lib f))
(check-equal? (jump-target '(c.j L)) 'L)
(check-equal? (jump-target-position '(beq (L) a b)) 0)
(check-equal? (jump-target-position '(c.beqz a (L))) 1)
(check-equal? (jump-target-position '(jal ra (L))) 1)
(check-equal? (jump-target-position '(j (L))) 0)

(check-equal? (jump-register '(jal x1 L)) 'x1)
(check-false (jump-register '(jal L)))
(check-equal? (jump-register '(jal x0 L)) 'x0)
(check-equal? (jump-register '(jalr a0 a1 0)) 'a0)
(check-equal? (jump-register '(jump-auipc-jalr x0 t0 L)) 'x0)
(check-equal? (jump-register '(c.j L)) 'x0)
(check-equal? (jump-register '(c.jal L)) 'x1)
(check-equal? (jump-register '(c.jr a0)) 'x0)
(check-equal? (jump-register '(c.jalr a0)) 'x1)

(check-true  (zero-register? 'x0))
(check-true  (zero-register? 'zero))
(check-true  (zero-register? 0))
(check-false (zero-register? 'ra))

;; label
(check-true  (label-form? '(label a f)))
(check-false (label-form? '(label)))
(check-equal? (label-path '(label a f)) '(a f))

;; ---------------------------------------------------------------------------
;; 显式形式 arity
;; ---------------------------------------------------------------------------

(check-error "jal 必须显式写 link"
             (lambda () (check-transfer-arity! '(jal g))))
(check-error "branch-jal 固定 arity"
             (lambda () (check-transfer-arity! '(branch-jal beq a b))))
(check-error "branch-auipc-jalr 固定 arity"
             (lambda () (check-transfer-arity! '(branch-auipc-jalr x5 beq a b))))
(check-error "jump-auipc-jalr 固定 arity"
             (lambda () (check-transfer-arity! '(jump-auipc-jalr x0 t0))))
(check-error "la-pcrel 固定 arity"
             (lambda () (check-transfer-arity! '(la-pcrel a0 x t0))))
(check-error "la-pcrel-li-add 固定 arity"
             (lambda () (check-transfer-arity! '(la-pcrel-li-add a0 t0))))

;; 显式写就合法
(check-transfer-arity! '(jal x0 g))
(check-transfer-arity! '(branch-jal beq a b g))
(check-transfer-arity! '(branch-auipc-jalr x5 beq a b g))
(check-transfer-arity! '(jump-auipc-jalr x0 t0 g))
(check-transfer-arity! '(la-pcrel a0 (g)))
(check-transfer-arity! '(la-pcrel-li-add a0 t0 (g)))

(finish-tests "insn")
