#lang racket/base

;; ============================================================
;; instruction_info 查表辅助测试
;;
;; 不生成总表，查表按扩展进行：
;;   - instruction-info-extensions 列出有 metadata 的扩展
;;   - extension-instruction-info 取该扩展的表
;;   - find-extension-instruction-info 在表内按名字查
;;   - instruction->extensions 是反向索引，必须与各扩展表一致
;; ============================================================

(require rackunit
         racket/list
         racket/set
         racket/string
         "../generated/lib/riscv/instruction_info/struct.rkt"
         "../generated/lib/riscv/instruction_info/query.rkt"
         "../generated/lib/riscv/instruction_info/lookup.rkt"
         "../generated/gen/riscv/instruction_info/instruction_extensions.rkt")

(define extensions (instruction-info-extensions))

(check-true (pair? extensions))
(check-true (andmap symbol? extensions))
(check-equal? extensions
              (sort (remove-duplicates extensions) symbol<?)
              "扩展清单应无重复且有序")

(define total 0)

(for ([ext (in-list extensions)])
  (define path (instruction-info-path ext))
  (check-true (string? path) (format "~a: path" ext))
  (check-true (file-exists? path) (format "~a: ~a" ext path))
  (check-true (string-suffix? path (format "~a.rkt" ext))
              (format "~a: ~a" ext path))

  (define infos (extension-instruction-info ext))
  (check-not-false infos (format "~a: table" ext))
  (check-true (pair? infos) (format "~a: table not empty" ext))
  (set! total (+ total (length infos)))

  ;; 表内：扩展名正确、名字唯一
  (for ([info (in-list infos)])
    (check-eq? (instruction-info-extension info) ext
               (format "~a: entry extension" ext)))
  (define names (map instruction-info-name infos))
  (check-equal? (length names) (length (remove-duplicates names))
                (format "~a: names unique" ext))

  ;; 反向索引必须包含本扩展
  (for ([name (in-list names)])
    (check-not-false (memq ext (get-extensions name))
                     (format "~a/~a: in instruction->extensions" ext name))))

;; 反向索引里的每个 (name, ext) 都必须真的能在该扩展表里查到
(for ([(name exts) (in-hash instruction->extensions)])
  (for ([ext (in-list exts)])
    (check-not-false (find-extension-instruction-info ext name)
                     (format "~a/~a: reverse index" ext name))))

(check-true (> total 1000) (format "总条目数 ~a" total))

;; 同一扩展重复查表应命中缓存（同一个 list 对象）
(check-eq? (extension-instruction-info 'rv_i)
           (extension-instruction-info 'rv_i))

;; 按指令名符号查一条
(check-eq? (instruction-info-name
            (find-extension-instruction-info 'rv_i 'add))
           'add)
(check-false (find-extension-instruction-info 'rv_i 'no-such-instruction))

;; 参数类型检查：扩展与指令名都必须是符号
(check-exn exn:fail:contract? (lambda () (instruction-info-path "rv_i")))
(check-exn exn:fail:contract? (lambda () (extension-instruction-info "rv_i")))
(check-exn exn:fail:contract?
           (lambda () (find-extension-instruction-info 'rv_i "add")))
