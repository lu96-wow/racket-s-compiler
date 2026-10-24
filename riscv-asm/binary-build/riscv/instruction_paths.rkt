#lang racket/base

;; ============================================================
;; 生成包内的路径辅助模块
;;
;; 这个文件会被 build 复制到生成包的 lib/ 目录。它根据自身位置
;; 计算 gen/ 下 raw / rebuilt 指令模块的绝对路径，调用方不需要
;; 知道生成包内部目录布局。
;;
;; 生成包布局：
;;   lib/  复制的手写模块（含本文件）
;;   gen/  生成的指令模块与 metadata
;; ============================================================

(require racket/path
         racket/runtime-path)

(define-runtime-path self-path "instruction_paths.rkt")

;; lib/instruction_paths.rkt -> 生成包根目录
(define package-root
  (simplify-path (build-path (path-only self-path) "..")))

;; 这里的目录布局必须与 binary-build/paths.rkt 的 generated-* 布局一致。
;; generated-test 会检查这些路径对应的文件存在。

(define (extension-module-filename extension)
  (unless (symbol? extension)
    (raise-argument-error 'extension-module-filename "symbol?" extension))
  (string-append (symbol->string extension) ".rkt"))

(define (instruction-path kind extension)
  (path->string
   (build-path package-root
               "gen" "riscv" "instruction" kind
               (extension-module-filename extension))))

(define (raw-instruction-path extension)
  (instruction-path "raw" extension))

(define (rebuilt-instruction-path extension)
  (instruction-path "rebuilt" extension))

(provide raw-instruction-path
         rebuilt-instruction-path)
