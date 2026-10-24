#lang racket/base

;; ============================================================
;; Single source of truth for logical operand groups
;;
;; Raw field modules live in binary-build/runtime/lib/riscv/raw/*.rkt.
;; A group says which raw tokens form one rebuilt/logical operand.
;; The same registry is used by:
;;   - binary-build/layout/plan.rkt       (raw/rebuilt operand plans)
;;   - binary-build/emit/fields.rkt       (generated rebuilt field modules)
;;   - metadata generation       (through the operand plans)
;;
;; Group names are plain strings because source operand tokens are strings.
;; Module names are symbols naming the raw/rebuilt module in which the
;; field lives: scalar, compressed, vector, mop.
;; ============================================================

(require racket/list)

(struct operand-group (name module raw-tokens)
  #:transparent)

(define group-modules
  '(scalar compressed vector mop))

(define operand-groups
  (list
   ;; scalar
   (operand-group "simm12" 'scalar '("imm12hi" "imm12lo"))
   (operand-group "bimm12" 'scalar '("bimm12hi" "bimm12lo"))

   ;; compressed
   (operand-group "c_uimm7" 'compressed '("c_uimm7lo" "c_uimm7hi"))
   (operand-group "c_uimm8" 'compressed '("c_uimm8lo" "c_uimm8hi"))
   (operand-group "c_uimm9" 'compressed '("c_uimm9lo" "c_uimm9hi"))
   (operand-group "c_imm6" 'compressed '("c_imm6lo" "c_imm6hi"))
   (operand-group "c_nzimm6" 'compressed '("c_nzimm6lo" "c_nzimm6hi"))
   (operand-group "c_nzimm10" 'compressed '("c_nzimm10lo" "c_nzimm10hi"))
   (operand-group "c_nzimm18" 'compressed '("c_nzimm18lo" "c_nzimm18hi"))
   (operand-group "c_bimm9" 'compressed '("c_bimm9lo" "c_bimm9hi"))
   (operand-group "c_nzuimm6" 'compressed '("c_nzuimm6lo" "c_nzuimm6hi"))
   (operand-group "c_uimm8sp" 'compressed '("c_uimm8splo" "c_uimm8sphi"))
   (operand-group "c_uimm9sp" 'compressed '("c_uimm9splo" "c_uimm9sphi"))
   (operand-group "c_uimm10sp" 'compressed '("c_uimm10splo" "c_uimm10sphi"))

   ;; vector
   (operand-group "zimm6" 'vector '("zimm6lo" "zimm6hi"))

   ;; Zimop
   (operand-group "mop_r_t" 'mop
                  '("mop_r_t_30" "mop_r_t_27_26" "mop_r_t_21_20"))
   (operand-group "mop_rr_t" 'mop
                  '("mop_rr_t_30" "mop_rr_t_27_26"))))

(define token->group
  (make-immutable-hash
   (for*/list ([g (in-list operand-groups)]
               [token (in-list (operand-group-raw-tokens g))])
     (cons token g))))

(define (groups-for-module module)
  (for/list ([g (in-list operand-groups)]
             #:when (eq? (operand-group-module g) module))
    g))

(define (group-complete? group operands)
  (for/and ([token (in-list (operand-group-raw-tokens group))])
    (and (member token operands) #t)))

(provide operand-group
         operand-group?
         operand-group-name
         operand-group-module
         operand-group-raw-tokens
         group-modules
         operand-groups
         token->group
         groups-for-module
         group-complete?)
