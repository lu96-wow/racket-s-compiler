#lang racket

(require "riscv/parse/main.rkt"
         "riscv/codegen.rkt")

;; ============================================================
;; 配置
;; ============================================================

(define input-dir "riscv-opcodes/extensions/")
(define output-dir "riscv/instruction/")
(define output-info-dir "riscv/instruction_info/")

;; ============================================================
;; 第1步: 路径发现 → 源文件路径列表
;; ============================================================

(define (discover-source-files dir)
  (define all-entries (directory-list dir))
  (define file-entries
    (filter (λ (name)
              (let ([p (build-path dir name)])
                (file-exists? p)))
            all-entries))
  (sort file-entries (λ (a b) (string<? (path->string a) (path->string b)))))

;; ============================================================
;; 第2步: 构造 extension-source 列表
;; ============================================================

(define (make-extension-sources dir files)
  (for/list ([f (in-list files)])
    (make-extension-source (build-path dir f))))

;; ============================================================
;; 第3步: 计算输出路径
;; ============================================================

(define (output-paths esrc)
  (define base (path-replace-suffix (file-name-from-path (extension-source-path esrc)) ""))
  (define base-str (path->string base))
  (values (build-path output-dir (string-append base-str ".rkt"))
          (build-path output-info-dir (string-append base-str ".rkt"))))

;; ============================================================
;; 第4步: 处理单个扩展: 解析 → 生成 → 写入
;; ============================================================

(define (process-extension esrc)
  (define src-path (extension-source-path esrc))
  (define type-sym (extension-source-type-sym esrc))
  (define-values (instr-path info-path) (output-paths esrc))

  ;; 解析
  (define defs (parse-file src-path))

  ;; 生成
  (define instr-content (gen-instruction-file-content defs))
  (define info-content (gen-instruction-info-file-content type-sym defs))

  ;; 写入
  (display-to-file instr-content instr-path #:exists 'replace)
  (display-to-file info-content info-path #:exists 'replace)

  ;; 日志
  (printf "Built ~a (~a instructions)\n" src-path (length defs))

  ;; 返回用于后续全局处理的数据
  (extension-defs esrc defs))

;; ============================================================
;; 第5步: 处理全局文件
;; ============================================================

(define (process-global-files ext-sources)
  (define global-map-out (build-path output-info-dir "instruction_info.rkt"))
  (define stats-out (build-path output-info-dir "instruction_counts.rkt"))
  (define meta-out (build-path output-info-dir "instruction_meta.rkt"))

  (printf "Building global instruction map -> ~a\n" global-map-out)
  (define global-map-content (gen-global-extension-map-content ext-sources))
  (display-to-file global-map-content global-map-out #:exists 'replace)

  (printf "Generating instruction statistics -> ~a\n" stats-out)
  (define stats-content (gen-instruction-counts-content ext-sources))
  (display-to-file stats-content stats-out #:exists 'replace)

  (printf "Building global instruction metadata -> ~a\n" meta-out)
  (define meta-content (gen-global-instruction-meta-content ext-sources))
  (display-to-file meta-content meta-out #:exists 'replace))

;; ============================================================
;; 主入口
;; ============================================================

(define (build-all)
  ;; 准备输出目录
  (for ([dir (list output-dir output-info-dir)])
    (unless (directory-exists? dir)
      (make-directory* dir)))

  ;; 管道: 发现 → 解析 → 生成 → 写入
  (define source-files (discover-source-files input-dir))
  (define ext-sources (make-extension-sources input-dir source-files))

  (printf "Found ~a extension files\n" (length ext-sources))
  (newline)

  ;; 处理每个扩展
  (for ([esrc (in-list ext-sources)])
    (process-extension esrc))

  (newline)

  ;; 处理全局文件
  (process-global-files ext-sources)

  ;; 打印统计
  (newline)
  (printf "Build Summary:\n")
  (printf "  Extensions processed: ~a\n" (length ext-sources)))

(build-all)
