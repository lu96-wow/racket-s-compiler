#lang racket/base

;; ============================================================
;; instruction_info 查表辅助
;;
;; 与 instruction_paths.rkt 对应：
;;   instruction_paths.rkt        给 raw / rebuilt 指令模块路径
;;   lookup.rkt（本文件）         给 metadata 模块路径，并把它加载成表
;;
;; 对外统一使用符号：
;;   扩展表 -> 'rv_i
;;   指令名 -> 'add
;;
;; 不提供“所有扩展 append 成一个总表”的接口：
;; 同名指令在不同扩展下可能是不同变体（rv32/rv64），
;; 必须按目标 ISA 选扩展，再查对应扩展的表。
;;
;; 目录布局：
;;   lib/riscv/instruction_info/  本文件 + struct.rkt / query.rkt（复制）
;;   gen/riscv/instruction_info/  <extension>.rkt（生成）
;; 本文件根据自身位置定位 gen/ 目录，调用方不需要知道生成包内部结构。
;; ============================================================

(require racket/path
         racket/runtime-path
         "query.rkt")

(define-runtime-path self-path "lookup.rkt")
(define info-lib-dir (path-only self-path))

;; lib/riscv/instruction_info -> 生成包根 -> gen/riscv/instruction_info
(define info-gen-dir
  (simplify-path
   (build-path info-lib-dir ".." ".." ".." "gen" "riscv" "instruction_info")))

(define (check-extension who extension)
  (unless (symbol? extension)
    (raise-argument-error who "symbol?" extension)))

(define (extension-module-filename extension)
  (string-append (symbol->string extension) ".rkt"))

;; 某个扩展的 metadata 模块路径，例如 'rv_i -> ".../rv_i.rkt"
(define (instruction-info-path extension)
  (check-extension 'instruction-info-path extension)
  (path->string
   (build-path info-gen-dir (extension-module-filename extension))))

;; 每个扩展模块导出 <extension>-instructions，例如 rv_i-instructions
(define (extension-info-variable extension)
  (string->symbol (format "~a-instructions" extension)))

;; 模块本身只会实例化一次，这里再缓存一份表，避免重复查符号。
(define info-cache (make-hash))

;; 'rv_i -> 该扩展的全部 instruction-info
(define (extension-instruction-info extension)
  (check-extension 'extension-instruction-info extension)
  (hash-ref!
   info-cache
   extension
   (lambda ()
     (dynamic-require
      (list 'file (instruction-info-path extension))
      (extension-info-variable extension)))))

;; 生成包里有 metadata 的扩展清单
(define (instruction-info-extensions)
  (dynamic-require (build-path info-gen-dir "extensions.rkt") 'extensions))

;; 在某个扩展的表里按指令名符号查一条；找不到返回 #f。
(define (find-extension-instruction-info extension name)
  (find-instruction-info (extension-instruction-info extension) name))

(provide instruction-info-path
         instruction-info-extensions
         extension-instruction-info
         find-extension-instruction-info)
