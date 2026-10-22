#lang racket/base

;; ============================================================
;; 生成包内的路径辅助模块
;;
;; 这个文件会被 build 复制到生成包根目录。它根据自身位置
;; 计算 raw / rebuilt 指令模块的绝对路径，调用方不需要知道
;; 生成包内部目录布局。
;; ============================================================

(require racket/path
         racket/runtime-path)

(define-runtime-path self-path "instruction_paths.rkt")
(define package-root (path-only self-path))

(define (extension-file extension)
  (unless (symbol? extension)
    (raise-argument-error 'extension-file "symbol?" extension))
  (string-append (symbol->string extension) ".rkt"))

(define (raw-instruction-path extension)
  (path->string
   (build-path package-root
               "riscv" "instruction" "raw"
               (extension-file extension))))

(define (rebuilt-instruction-path extension)
  (path->string
   (build-path package-root
               "riscv" "instruction" "rebuilt"
               (extension-file extension))))

(provide raw-instruction-path
         rebuilt-instruction-path)
