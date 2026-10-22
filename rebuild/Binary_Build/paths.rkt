#lang racket/base

;; ============================================================
;; 生成路径与模块依赖路径的唯一配置点
;;
;; 这里同时管理两类路径：
;;   1. 磁盘上的输入/输出目录
;;   2. 生成文件内部的 require 字符串
;; ============================================================

(require racket/file
         racket/path
         racket/string
         racket/runtime-path)

;; -------- 磁盘目录 --------
(define-runtime-path source-dir "../riscv-opcodes/extensions")
(define-runtime-path raw-out-dir "riscv/instruction/raw")
(define-runtime-path rebuilt-out-dir "riscv/instruction/rebuilt")
(define-runtime-path info-out-dir "riscv/instruction_info")

;; -------- 输出文件名 --------
(define (extension-module-file extension)
  (string-append extension ".rkt"))

(define (raw-output-path extension)
  (build-path raw-out-dir (extension-module-file extension)))

(define (rebuilt-output-path extension)
  (build-path rebuilt-out-dir (extension-module-file extension)))

(define (info-output-path extension)
  (build-path info-out-dir (extension-module-file extension)))

(define (all-info-output-path)
  (build-path info-out-dir "all.rkt"))

(define (extension-map-output-path)
  (build-path info-out-dir "instruction_extensions.rkt"))

;; -------- 输入扩展发现 --------
(define (extension-files)
  (sort
   (for/list ([name (in-list (directory-list source-dir))]
              #:when (let ([p (build-path source-dir name)])
                       (and (file-exists? p)
                            (not (directory-exists? p))
                            (string-prefix? (path->string name) "rv"))))
     (build-path source-dir name))
   (lambda (a b)
     (string<? (path->string a) (path->string b)))))

(define (extension-stem path)
  (path->string (path-replace-suffix (file-name-from-path path) "")))

;; -------- 生成文件内部的 require 字符串 --------
(define raw-require-specs
  '("\"../../../base.rkt\""
    "\"../../raw/scalar.rkt\""
    "\"../../raw/compressed.rkt\""
    "\"../../raw/vector.rkt\""
    "\"../../raw/mop.rkt\""))

(define rebuilt-require-specs
  '("\"../../../base.rkt\""
    "(prefix-in raw: \"../../raw/scalar.rkt\")"
    "(prefix-in raw: \"../../raw/compressed.rkt\")"
    "(prefix-in raw: \"../../raw/vector.rkt\")"
    "(prefix-in raw: \"../../raw/mop.rkt\")"
    "(prefix-in rebuilt: \"../../rebuilt/scalar.rkt\")"
    "(prefix-in rebuilt: \"../../rebuilt/compressed.rkt\")"
    "(prefix-in rebuilt: \"../../rebuilt/vector.rkt\")"
    "(prefix-in rebuilt: \"../../rebuilt/mop.rkt\")"))

(define info-require-specs
  '("\"struct.rkt\""))

(define (info-module-require-spec extension)
  (format "\"~a.rkt\"" extension))

(provide source-dir
         raw-out-dir
         rebuilt-out-dir
         info-out-dir
         extension-files
         extension-stem
         raw-output-path
         rebuilt-output-path
         info-output-path
         all-info-output-path
         extension-map-output-path
         raw-require-specs
         rebuilt-require-specs
         info-require-specs
         info-module-require-spec)
