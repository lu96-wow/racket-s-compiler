#lang racket/base

(require racket/file
         "paths.rkt"
         "riscv/parse/main.rkt"
         "riscv/codegen.rkt"
         "riscv/info-codegen.rkt")

;; ============================================================
;; 把依赖模块和生成产物打包到 generated-root
;; ============================================================

(define (copy-dependencies!)
  (make-directory* (generated-root))

  (copy-file source-base-path (generated-base-path) #t)
  (copy-file source-bit-path (generated-bit-path) #t)
  (copy-file source-instruction-paths-path
             (generated-instruction-paths-path)
             #t)

  (for ([kind (in-list '("raw" "rebuilt"))])
    (define dest-dir (generated-field-dir kind))
    (make-directory* dest-dir)
    (for ([file (in-list field-module-files)])
      (copy-file (build-path source-field-dir kind file)
                 (build-path dest-dir file)
                 #t)))

  (make-directory* (generated-info-dir))
  (copy-file source-info-struct-path (generated-info-struct-path) #t)
  (copy-file source-info-query-path (generated-info-query-path) #t))

(define (make-output-dirs!)
  (make-directory* (generated-instruction-dir "raw"))
  (make-directory* (generated-instruction-dir "rebuilt"))
  (make-directory* (generated-info-dir)))

(define (build-all #:output-root [output-root #f])
  (when output-root
    (generated-root output-root))

  (copy-dependencies!)
  (make-output-dirs!)

  (define files (extension-files))
  (define parsed-files
    (for/list ([path (in-list files)])
      (parse-extension-file path)))

  (define extension-map
    (make-immutable-hash
     (for/list ([parsed (in-list parsed-files)])
       (cons (extension-stem (extension-file-path parsed)) parsed))))

  (define ext->defs (make-hash))

  (define-values (standard pseudo imports emitted)
    (for/fold ([standard 0]
               [pseudo 0]
               [imports 0]
               [emitted 0])
              ([parsed (in-list parsed-files)])
      (define defs (prepare-extension-defs parsed extension-map))
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
              (+ emitted (length defs)))))

  (define all-info-path (all-info-output-path))
  (display-to-file (gen-all-info-content ext->defs all-info-path)
                   all-info-path
                   #:exists 'replace)
  (display-to-file (gen-extension-map-content ext->defs)
                   (extension-map-output-path)
                   #:exists 'replace)

  (printf "Generated ~a extensions\n" (length files))
  (printf "  standard definitions:  ~a\n" standard)
  (printf "  pseudo definitions:    ~a\n" pseudo)
  (printf "  import definitions:    ~a\n" imports)
  (printf "  emitted per extension: ~a\n" emitted)
  (printf "  package root:          ~a\n" (generated-root)))

(define args (current-command-line-arguments))
(define output-root
  (cond
    [(zero? (vector-length args)) #f]
    [(= (vector-length args) 1) (vector-ref args 0)]
    [else
     (error 'build
            "usage: racket Binary_Build/build.rkt [output-root]")]))

(build-all #:output-root output-root)
