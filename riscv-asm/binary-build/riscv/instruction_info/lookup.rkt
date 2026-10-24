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
;; 设计约束（本模块与所有使用方遵守）：
;;   1. 不生成、不提供跨扩展总表；查表必须点名扩展
;;   2. 不隐式全包搜索；扩展列表由调用方（ISA 配置）给出
;;   3. 同一个名字可能在多个扩展里都命中，用
;;      resolve-instruction-info 统一消歧：
;;        签名相同 -> 同一编码，取第一个（re-export / pseudo 同编码）
;;        签名不同 -> 报错（通常是 rv32/rv64 配置混用）
;;   4. ISA 配置必须自洽：rv32_* 与 rv64_* 不能同时出现在一个集合里
;;
;; 目录布局：
;;   lib/riscv/instruction_info/  本文件 + struct.rkt / query.rkt（复制）
;;   gen/riscv/instruction_info/  <extension>.rkt（生成）
;; 本文件根据自身位置定位 gen/ 目录，调用方不需要知道生成包内部结构。
;; ============================================================

(require racket/list
         racket/path
         racket/runtime-path
         "struct.rkt"
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

;; ------------------------------------------------------------
;; 多扩展消歧
;; ------------------------------------------------------------

(define (check-extensions who extensions)
  (unless (and (list? extensions) (andmap symbol? extensions))
    (raise-argument-error who "(listof symbol?)" extensions)))

(define (check-name who name)
  (unless (symbol? name)
    (raise-argument-error who "symbol?" name)))

;; 给定扩展列表和指令名，按列表顺序返回所有命中的 info。
(define (instruction-info-candidates extensions name)
  (check-extensions 'instruction-info-candidates extensions)
  (check-name 'instruction-info-candidates name)
  (for/list ([ext (in-list extensions)]
             #:when (find-extension-instruction-info ext name))
    (find-extension-instruction-info ext name)))

;; 判断两条 info 是否描述同一个编码（忽略 name / extension / kind）。
(define (instruction-info-signature info)
  (list (info-width info)
        (info-size info)
        (info-operands info)
        (info-raw-operands info)
        (info-fixed-fields info)
        (info-aliases info)
        (info-asm-format info)))

;; 在给定扩展集合里解析一个指令名：
;;   命中 0 条 -> 报错
;;   命中 1 条 -> 返回它
;;   命中多条且签名相同 -> 返回第一条（编码一致，safe dedupe）
;;   命中多条且签名不同 -> 报错（ISA 集合自身冲突）
(define (resolve-instruction-info extensions name)
  (define candidates (instruction-info-candidates extensions name))
  (cond
    [(null? candidates)
     (error 'resolve-instruction-info
            "instruction ~a not found in extensions ~a"
            name extensions)]
    [(null? (cdr candidates))
     (car candidates)]
    [else
     (define signatures
       (remove-duplicates
        (for/list ([info (in-list candidates)])
          (instruction-info-signature info))))
     (if (null? (cdr signatures))
         ;; 同一编码被多个扩展提供（import / pseudo 同编码），取第一个
         (car candidates)
         (error 'resolve-instruction-info
                "instruction ~a is ambiguous in extensions ~a: ~a"
                name
                extensions
                (for/list ([info (in-list candidates)])
                  (instruction-info-extension info))))]))

(provide instruction-info-path
         instruction-info-extensions
         extension-instruction-info
         find-extension-instruction-info
         instruction-info-candidates
         resolve-instruction-info)
