#lang racket/base

;; ============================================================
;; 解析层数据结构
;;
;; 这一层只描述 riscv-opcodes 源文件的结构：
;;   - fixed-field : 固定位段 [lo, hi] = value
;;   - instruction-def : 一条原始指令（原始 token 顺序，不合并 hi/lo）
;; ============================================================

(struct fixed-field (lo hi value)
  #:transparent
  #:guard
  (lambda (lo hi value who)
    (unless (exact-nonnegative-integer? lo)
      (raise-argument-error who "exact-nonnegative-integer?" lo))
    (unless (exact-nonnegative-integer? hi)
      (raise-argument-error who "exact-nonnegative-integer?" hi))
    (unless (<= lo hi)
      (error who "lo (~a) must be <= hi (~a)" lo hi))
    (when (> hi 31)
      (error who "hi (~a) must be <= 31" hi))
    (unless (exact-nonnegative-integer? value)
      (raise-argument-error who "exact-nonnegative-integer?" value))
    (define width (add1 (- hi lo)))
    (unless (< value (arithmetic-shift 1 width))
      (error who
             "value ~a does not fit in ~a bit(s) [~a..~a]"
             value width lo hi))
    (values lo hi value)))

(struct instruction-def (name operands fixed-fields)
  #:transparent
  #:guard
  (lambda (name operands fixed-fields who)
    (unless (string? name)
      (raise-argument-error who "string?" name))
    (unless (and (list? operands) (andmap string? operands))
      (raise-argument-error who "(listof string?)" operands))
    (unless (and (list? fixed-fields) (andmap fixed-field? fixed-fields))
      (raise-argument-error who "(listof fixed-field?)" fixed-fields))
    (values name operands fixed-fields)))


;; 一条 $pseudo_op
;;   source-extension   : 被依赖指令所在扩展，例如 "rv_i"
;;   source-instruction : 被依赖指令名，例如 "fence"
;;   name               : 伪指令名，例如 "fence.tso"
;;   instruction        : 伪指令自身的 operation/fixed 定义
(struct pseudo-def (source-extension source-instruction name instruction)
  #:transparent)

;; 一条 $import
(struct import-def (source-extension instruction-name)
  #:transparent)

;; 一个扩展文件的完整解析结果
(struct extension-file (path standard pseudo imports)
  #:transparent)

(struct extension-source (path type-sym)
  #:transparent)

(struct extension-defs (source defs)
  #:transparent)

(provide fixed-field
         fixed-field?
         fixed-field-lo
         fixed-field-hi
         fixed-field-value
         instruction-def
         instruction-def?
         instruction-def-name
         instruction-def-operands
         instruction-def-fixed-fields
         pseudo-def
         pseudo-def?
         pseudo-def-source-extension
         pseudo-def-source-instruction
         pseudo-def-name
         pseudo-def-instruction
         import-def
         import-def?
         import-def-source-extension
         import-def-instruction-name
         extension-file
         extension-file?
         extension-file-path
         extension-file-standard
         extension-file-pseudo
         extension-file-imports
         extension-source
         extension-source?
         extension-source-path
         extension-source-type-sym
         extension-defs
         extension-defs?
         extension-defs-source
         extension-defs-defs)
