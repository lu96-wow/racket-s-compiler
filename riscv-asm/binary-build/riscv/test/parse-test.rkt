#lang racket/base

(require rackunit
         racket/list
         racket/string
         "../../paths.rkt"
         "../parse/main.rkt")

(define (ff->list ff)
  (list (fixed-field-lo ff)
        (fixed-field-hi ff)
        (fixed-field-value ff)))

;; ------------------------------------------------------------
;; 原始 token 顺序不能被合并
;; ------------------------------------------------------------

(define sb
  (parse-line "sb imm12hi rs1 rs2 imm12lo 14..12=0 6..2=0x08 1..0=3" 1))

(check-equal? (instruction-def-name sb) "sb")
(check-equal? (instruction-def-operands sb)
              '("imm12hi" "rs1" "rs2" "imm12lo"))
(check-equal? (map ff->list (instruction-def-fixed-fields sb))
              '((12 14 0) (2 6 8) (0 1 3)))

(define addi
  (parse-line "addi rd rs1 imm12 14..12=0 6..2=0x04 1..0=3" 2))

(check-equal? (instruction-def-name addi) "addi")
(check-equal? (instruction-def-operands addi)
              '("rd" "rs1" "imm12"))
(check-equal? (map ff->list (instruction-def-fixed-fields addi))
              '((12 14 0) (2 6 4) (0 1 3)))

(define c-lw
  (parse-line "c.lw rd_p rs1_p c_uimm7lo c_uimm7hi 1..0=0 15..13=2" 3))

(check-equal? (instruction-def-operands c-lw)
              '("rd_p" "rs1_p" "c_uimm7lo" "c_uimm7hi"))
(check-equal? (map ff->list (instruction-def-fixed-fields c-lw))
              '((0 1 0) (13 15 2)))

;; ------------------------------------------------------------
;; alias token 不是 fixed field
;; ------------------------------------------------------------

(define fmv-d
  (parse-line "fmv.d rd rs1 rs2=rs1 31..27=0x04 14..12=0 26..25=1 6..2=0x14 1..0=3" 4))

(check-equal? (instruction-def-operands fmv-d)
              '("rd" "rs1" "rs2=rs1"))
(check-equal? (length (instruction-def-fixed-fields fmv-d)) 5)

;; ------------------------------------------------------------
;; 非法 fixed field
;; ------------------------------------------------------------

(check-exn exn:fail?
           (lambda ()
             (parse-line "foo 1..0=3 0=1" 5)))

(check-exn exn:fail?
           (lambda ()
             (parse-line "foo 3..0=0x10" 6)))

(check-exn exn:fail?
           (lambda ()
             (parse-line "foo 0..1=0" 7)))


;; ------------------------------------------------------------
;; $pseudo_op / $import
;; ------------------------------------------------------------

(define pseudo
  (parse-pseudo-line
   "$pseudo_op rv_i::fence fence.tso 31..28=8 27..24=3 23..20=3 rs1 14..12=0 rd 6..2=0x03 1..0=3"
   10))

(check-equal? (pseudo-def-source-extension pseudo) "rv_i")
(check-equal? (pseudo-def-source-instruction pseudo) "fence")
(check-equal? (pseudo-def-name pseudo) "fence.tso")
(check-equal? (instruction-def-operands (pseudo-def-instruction pseudo))
              '("rs1" "rd"))

(define imported
  (parse-import-line "$import rv32_zkne::aes32esmi" 11))

(check-equal? (import-def-source-extension imported) "rv32_zkne")
(check-equal? (import-def-instruction-name imported) "aes32esmi")

;; alias 在 pseudo 行里仍然保留为 operand token
(define fmv-pseudo
  (parse-pseudo-line
   "$pseudo_op rv_d::fsgnj.d fmv.d rd rs1 rs2=rs1 31..27=0x04 14..12=0 26..25=1 6..2=0x14 1..0=3"
   12))

(check-equal? (instruction-def-operands (pseudo-def-instruction fmv-pseudo))
              '("rd" "rs1" "rs2=rs1"))

;; ------------------------------------------------------------
;; 解析全部顶层扩展文件
;; ------------------------------------------------------------

(define extension-paths
  (sort
   (for/list ([name (in-list (directory-list source-dir))]
              #:when (let ([p (build-path source-dir name)])
                       (and (file-exists? p)
                            (string-prefix? (path->string name) "rv"))))
     (build-path source-dir name))
   (lambda (a b)
     (string<? (path->string a) (path->string b)))))

(define parsed-files
  (for/list ([path (in-list extension-paths)])
    (parse-extension-file path)))


;; ------------------------------------------------------------
;; 同名定义优先级：standard 必须胜过 pseudo
;; ------------------------------------------------------------

(define extension-map
  (make-immutable-hash
   (for/list ([parsed (in-list parsed-files)])
     (cons (extension-stem (extension-file-path parsed)) parsed))))

(define-values (rv-i-defs rv-i-skipped)
  (prepare-extension-defs (hash-ref extension-map "rv_i") extension-map))

(check-not-false (find-instruction rv-i-defs "jal"))
(check-equal? (map skipped-definition-name rv-i-skipped)
              '("jal" "jalr"))
(check-equal? (map skipped-definition-reason rv-i-skipped)
              '("overridden-by-standard-definition"
                "overridden-by-standard-definition"))

(define-values (zilsd-defs zilsd-skipped)
  (prepare-extension-defs (hash-ref extension-map "rv32_zilsd") extension-map))

;; 两个 pseudo ld 中，保留与 rv64_i::ld fixed fields 兼容的 load 形式
(define zilsd-ld (find-instruction zilsd-defs "ld"))
(check-equal? (instruction-def-operands zilsd-ld)
              '("rd_e" "rs1" "imm12"))
(check-equal? (map skipped-definition-name zilsd-skipped)
              '("ld"))
(check-equal? (map skipped-definition-reason zilsd-skipped)
              '("not-a-standard-form"))

(define total-standard
  (for/sum ([parsed (in-list parsed-files)])
    (length (extension-file-standard parsed))))
(define total-pseudo
  (for/sum ([parsed (in-list parsed-files)])
    (length (extension-file-pseudo parsed))))
(define total-imports
  (for/sum ([parsed (in-list parsed-files)])
    (length (extension-file-imports parsed))))

(check-true (> total-standard 800))
(check-true (> total-pseudo 150))
(check-true (> total-imports 100))
(displayln (format "parsed ~a standard, ~a pseudo, ~a imports from ~a extensions"
                   total-standard total-pseudo total-imports
                   (length extension-paths)))
