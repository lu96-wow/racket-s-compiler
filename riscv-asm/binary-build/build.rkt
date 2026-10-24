#lang racket/base

(require racket/file
         racket/list
         racket/path
         "paths.rkt"
         "riscv/parse/main.rkt"
         "riscv/codegen.rkt"
         "riscv/info-codegen.rkt")

;; ============================================================
;; 把依赖模块和生成产物打包到 generated-root
;; ============================================================

(define (clean-generated-output!)
  (define root (simplify-path (path->complete-path (generated-root))))
  (define protected-roots
    (list (simplify-path project-root)
          (simplify-path binary-build-dir)))
  (when (member root protected-roots equal?)
    (error 'build-all
           "generated root overlaps source tree: ~a"
           root))
  ;; lib/ 和 gen/ 是生成包的全部所有权范围，直接整个删掉重建。
  ;; 后面四项是旧布局（单目录）的遗留，用于迁移时清理，可以以后删。
  (for ([path (in-list (list (generated-lib-dir)
                             (generated-gen-dir)
                             (generated-path "riscv")
                             (generated-path "base.rkt")
                             (generated-path "bit.rkt")
                             (generated-path "instruction_paths.rkt")))])
    (delete-file-or-directory path)))

(define (delete-file-or-directory path)
  ;; 注意 file-exists? 对目录返回 #f，这里必须区分文件/目录。
  (case (file-or-directory-type path #f)
    [(file directory link) (delete-directory/files path)]
    [else (void)]))

(define (copy-dependencies!)
  (make-directory* (generated-root))
  (make-directory* (generated-lib-dir))

  (copy-file source-base-path (generated-base-path) #t)
  (copy-file source-bit-path (generated-bit-path) #t)
  (copy-file source-instruction-paths-path
             (generated-instruction-paths-path)
             #t)

  (for ([kind (in-list '("raw" "rebuilt"))])
    (define dest-dir (generated-field-dir kind))
    (make-directory* dest-dir)
    (for ([file (in-list field-module-filenames)])
      (copy-file (build-path source-riscv-dir kind file)
                 (build-path dest-dir file)
                 #t)))

  (make-directory* (generated-info-lib-dir))
  (copy-file source-info-struct-path (generated-info-struct-path) #t)
  (copy-file source-info-query-path (generated-info-query-path) #t)
  (copy-file source-info-lookup-path (generated-info-lookup-path) #t))

(define (make-output-dirs!)
  (make-directory* (generated-instruction-dir "raw"))
  (make-directory* (generated-instruction-dir "rebuilt"))
  (make-directory* (generated-info-dir)))

(define (build-all #:output-root [output-root #f])
  (when output-root
    (generated-root output-root))

  (clean-generated-output!)
  (copy-dependencies!)
  (make-output-dirs!)

  (define files (ratified-extension-source-files))
  (define parsed-files
    (for/list ([path (in-list files)])
      (parse-extension-file path)))

  (define extension-map
    (make-immutable-hash
     (for/list ([parsed (in-list parsed-files)])
       (cons (extension-stem (extension-file-path parsed)) parsed))))

  (define ext->defs (make-hash))

  (define-values (standard pseudo imports emitted skipped-definitions)
    (for/fold ([standard 0]
               [pseudo 0]
               [imports 0]
               [emitted 0]
               [skipped-definitions '()])
              ([parsed (in-list parsed-files)])
      (define-values (defs skipped)
        (prepare-extension-defs parsed extension-map))
      (define ext (extension-stem (extension-file-path parsed)))
      (hash-set! ext->defs ext defs)

      (define raw-path (raw-output-path ext))
      (define rebuilt-path (rebuilt-output-path ext))
      (define info-path (info-output-path ext))

      (display-to-file (gen-raw-file-content defs raw-path)
                       raw-path
                       #:exists 'replace)
      (display-to-file (gen-rebuilt-file-content defs rebuilt-path)
                       rebuilt-path
                       #:exists 'replace)
      (display-to-file (gen-info-file-content ext defs info-path)
                       info-path
                       #:exists 'replace)

      (values (+ standard (length (extension-file-standard parsed)))
              (+ pseudo (length (extension-file-pseudo parsed)))
              (+ imports (length (extension-file-imports parsed)))
              (+ emitted (length defs))
              (append skipped skipped-definitions))))

  (display-to-file (gen-extension-list-content ext->defs)
                   (extensions-output-path)
                   #:exists 'replace)
  (display-to-file (gen-extension-map-content ext->defs)
                   (instruction-extensions-output-path)
                   #:exists 'replace)

  (printf "Generated ~a ratified extensions\n" (length files))
  (printf "  standard definitions:  ~a\n" standard)
  (printf "  pseudo definitions:    ~a\n" pseudo)
  (printf "  import definitions:    ~a\n" imports)
  (printf "  emitted per extension: ~a\n" emitted)
  (define skipped-unique
    (sort (remove-duplicates skipped-definitions)
          string<?
          #:key skipped-definition-name))
  (printf "  skipped duplicates:    ~a\n" (length skipped-unique))
  (for ([skipped (in-list skipped-unique)])
    (printf "    ~a: ~a\n"
            (skipped-definition-name skipped)
            (skipped-definition-reason skipped)))
  (printf "  package root:          ~a\n" (generated-root)))

(define args (current-command-line-arguments))
(define output-root
  (cond
    [(zero? (vector-length args)) #f]
    [(= (vector-length args) 1) (vector-ref args 0)]
    [else
     (error 'build
            "usage: racket binary-build/build.rkt [output-root]")]))

(build-all #:output-root output-root)
