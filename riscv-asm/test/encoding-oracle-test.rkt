#lang racket/base

(require rackunit
         json
         racket/file
         racket/list
         racket/string
         "../binary-build/paths.rkt"
         "../binary-build/riscv/parse/main.rkt"
         "../binary-build/riscv/codegen.rkt")

;; ============================================================
;; 最终编码测试
;;
;; 对比数据来自 riscv-opcodes 自己的 instr_dict.json：
;;   match/mask 是上游独立实现算出的固定位。
;;
;; 对每条 standard 指令：
;;   - raw 函数用全 0 参数编码
;;   - 检查 (word & mask) == match
;;
;; 操作数位布局由 field 测试覆盖；这里负责 fixed bits / opcode /
;; funct3 / funct7 等最终编码常量。
;; ============================================================

(define oracle-path
  (build-path project-root "riscv-opcodes" "instr_dict.json"))

(unless (file-exists? oracle-path)
  (error 'encoding-oracle-test
         "missing comparison data: ~a\nrun: test/generate-oracle.sh"
         oracle-path))

(define oracle
  (call-with-input-file oracle-path read-json))

(define (normalize-name name)
  (string-replace name "." "_"))

(define (oracle-entry name)
  (hash-ref oracle (string->symbol (normalize-name name)) #f))

(define (hex-string->integer s)
  (unless (and (string? s) (string-prefix? s "0x"))
    (error 'hex-string->integer "expected 0x-prefixed string, got ~e" s))
  (string->number (substring s 2) 16))

(define (raw-module-path extension)
  (raw-output-path extension))

(define (raw-procedure extension name)
  (dynamic-require
   (list 'file (path->string (raw-module-path extension)))
   (string->symbol name)))

(define compressed-register-operands
  '("rd_p" "rs1_p" "rs2_p" "rd_rs1_p"
    "c_sreg1" "c_sreg2"
    "rd_p_e" "rs2_p_e"))

(define (sample-raw-value operand)
  (if (member operand compressed-register-operands)
      8
      0))

(define compared 0)
(define checked-names '())

(for ([parsed (in-list (map parse-extension-file
                            (ratified-extension-source-files)))])
  (define extension (extension-stem (extension-file-path parsed)))
  (for ([idef (in-list (extension-file-standard parsed))])
    (define name (instruction-def-name idef))
    (define entry (oracle-entry name))
    (unless entry
      (error 'encoding-oracle-test
             "no oracle entry for ~a::~a"
             extension name))

    (define oracle-extensions (hash-ref entry 'extension))
    (unless (member extension oracle-extensions)
      (error 'encoding-oracle-test
             "oracle entry ~a::~a has extensions ~a"
             extension name oracle-extensions))

    (define oracle-fields (hash-ref entry 'variable_fields))
    (define raw-fields (operand-plan-args (raw-operand-plan idef)))
    ;; upstream instr_dict 对 segmented vector 指令做了 nf 展开，raw 层仍保留
    ;; 源 token nf；比较时忽略 nf，fixed-bit 比较仍然完整。
    (define comparable-fields
      (if (member "nf" raw-fields)
          (remove "nf" raw-fields)
          raw-fields))
    (check-equal? comparable-fields oracle-fields
                  (format "operand order mismatch for ~a::~a" extension name))

    (define match (hex-string->integer (hash-ref entry 'match)))
    (define mask (hex-string->integer (hash-ref entry 'mask)))
    (define func (raw-procedure extension name))
    (define word (apply func (map sample-raw-value raw-fields)))

    (check-equal? (bitwise-and word mask) match
                  (format "fixed-bit mismatch for ~a::~a" extension name))

    (set! compared (add1 compared))
    (set! checked-names (cons (cons extension name) checked-names))))

(check-true (> compared 800))
(displayln (format "encoding oracle test: ~a standard instructions compared"
                   compared))
