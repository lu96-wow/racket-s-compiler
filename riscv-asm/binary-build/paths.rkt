#lang racket/base

;; ============================================================
;; 路径与资源布局的唯一配置点
;;
;; 这里统一管理：
;;   1. 源文件/源模块路径
;;   2. 生成包根目录与目录布局
;;   3. 生成文件内部的 require 相对路径计算
;;
;; 生成器不再写死 "../../raw/scalar.rkt" 这类字符串。
;; ============================================================

(require racket/file
         racket/path
         racket/string
         racket/runtime-path)

;; -------- 源码根目录 --------
(define-runtime-path self-path "paths.rkt")
(define binary-build-dir (path-only self-path))
(define project-root (simplify-path (build-path binary-build-dir "..")))

(define source-dir
  (build-path project-root "riscv-opcodes" "extensions"))

(define source-base-path
  (build-path binary-build-dir "base.rkt"))
(define source-bit-path
  (build-path binary-build-dir "bit.rkt"))

(define source-riscv-dir
  (build-path binary-build-dir "riscv"))

(define source-info-dir
  (build-path binary-build-dir "riscv" "instruction_info"))
(define source-info-struct-path
  (build-path source-info-dir "struct.rkt"))
(define source-info-query-path
  (build-path source-info-dir "query.rkt"))
(define source-info-lookup-path
  (build-path source-info-dir "lookup.rkt"))

(define source-instruction-paths-path
  (build-path binary-build-dir "riscv" "instruction_paths.rkt"))

;; -------- 动态生成根目录 --------
(define default-generated-root
  (build-path project-root "generated"))

(define generated-root
  (make-parameter default-generated-root))

(define (generated-path . parts)
  (apply build-path (generated-root) parts))

;; 生成包分两个顶层目录，避免“复制的文件”和“生成的文件”混在一起：
;;   lib/  从 binary-build 原样复制的手写模块（运行期实现）
;;   gen/  build 生成的模块（指令、metadata）
(define (generated-lib-dir)
  (generated-path "lib"))
(define (generated-gen-dir)
  (generated-path "gen"))

(define (generated-base-path)
  (build-path (generated-lib-dir) "base.rkt"))
(define (generated-bit-path)
  (build-path (generated-lib-dir) "bit.rkt"))

(define (check-field-kind who kind)
  (unless (member kind '("raw" "rebuilt"))
    (error who "expected field kind \"raw\" or \"rebuilt\", got ~a" kind)))

;; 字段函数属于复制区：lib/riscv/<kind>/
(define (generated-field-dir kind)
  (check-field-kind 'generated-field-dir kind)
  (build-path (generated-lib-dir) "riscv" kind))

;; 指令模块 / metadata 属于生成区：gen/riscv/...
(define (generated-instruction-dir kind)
  (check-field-kind 'generated-instruction-dir kind)
  (build-path (generated-gen-dir) "riscv" "instruction" kind))

(define (generated-info-dir)
  (build-path (generated-gen-dir) "riscv" "instruction_info"))

;; metadata 的结构/查询/查表也是手写模块，放在复制区
(define (generated-info-lib-dir)
  (build-path (generated-lib-dir) "riscv" "instruction_info"))
(define (generated-info-struct-path)
  (build-path (generated-info-lib-dir) "struct.rkt"))
(define (generated-info-query-path)
  (build-path (generated-info-lib-dir) "query.rkt"))
(define (generated-info-lookup-path)
  (build-path (generated-info-lib-dir) "lookup.rkt"))

(define (generated-instruction-paths-path)
  (build-path (generated-lib-dir) "instruction_paths.rkt"))

;; -------- 文件名 --------
(define (extension-module-file extension)
  (string-append extension ".rkt"))

(define field-module-filenames
  '("scalar.rkt"
    "compressed.rkt"
    "vector.rkt"
    "mop.rkt"))

;; -------- 输入扩展发现 --------
;; 当前只扫描 extensions/ 顶层的 ratified 扩展；unratified/ 不在生成范围内。
(define (ratified-extension-source-files)
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

;; -------- 输出路径 --------
(define (raw-output-path extension)
  (build-path (generated-instruction-dir "raw")
              (extension-module-file extension)))

(define (rebuilt-output-path extension)
  (build-path (generated-instruction-dir "rebuilt")
              (extension-module-file extension)))

(define (info-output-path extension)
  (build-path (generated-info-dir)
              (extension-module-file extension)))

(define (extensions-output-path)
  (build-path (generated-info-dir) "extensions.rkt"))

(define (instruction-extensions-output-path)
  (build-path (generated-info-dir) "instruction_extensions.rkt"))

;; -------- require 相对路径 --------
(define (relative-module-path from-file to-file)
  (find-relative-path
   (path-only (path->complete-path from-file))
   (path->complete-path to-file)))

(define (require-spec from-file to-file)
  (format "~s" (path->string
                (relative-module-path from-file to-file))))

(define (prefix-require-spec prefix from-file to-file)
  (format "(prefix-in ~a ~s)"
          prefix
          (path->string
           (relative-module-path from-file to-file))))

(define (raw-require-specs output-path)
  (append
   (list (require-spec output-path (generated-base-path)))
   (for/list ([file (in-list field-module-filenames)])
     (require-spec output-path
                   (build-path (generated-field-dir "raw") file)))))

(define (rebuilt-require-specs output-path)
  (append
   (list (require-spec output-path (generated-base-path)))
   (for/list ([file (in-list field-module-filenames)])
     (prefix-require-spec "raw:" output-path
                          (build-path (generated-field-dir "raw") file)))
   (for/list ([file (in-list field-module-filenames)])
     (prefix-require-spec "rebuilt:" output-path
                          (build-path (generated-field-dir "rebuilt") file)))))

(define (info-require-specs output-path)
  (list (require-spec output-path (generated-info-struct-path))))

(provide source-dir
         binary-build-dir
         project-root
         source-base-path
         source-bit-path
         source-riscv-dir
         source-info-dir
         source-info-struct-path
         source-info-query-path
         source-info-lookup-path
         source-instruction-paths-path
         default-generated-root
         generated-root
         generated-path
         generated-lib-dir
         generated-gen-dir
         generated-base-path
         generated-bit-path
         generated-field-dir
         generated-instruction-dir
         generated-info-dir
         generated-info-lib-dir
         generated-info-struct-path
         generated-info-query-path
         generated-info-lookup-path
         generated-instruction-paths-path
         field-module-filenames
         ratified-extension-source-files
         extension-stem
         raw-output-path
         rebuilt-output-path
         info-output-path
         extensions-output-path
         instruction-extensions-output-path
         relative-module-path
         require-spec
         prefix-require-spec
         raw-require-specs
         rebuilt-require-specs
         info-require-specs)
