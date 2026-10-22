#lang racket/base

(require racket/file
         "paths.rkt"
         "riscv/parse/main.rkt"
         "riscv/codegen.rkt"
         "riscv/info-codegen.rkt")

(define (build-all)
  (make-directory* raw-out-dir)
  (make-directory* rebuilt-out-dir)
  (make-directory* info-out-dir)

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

      (display-to-file (gen-raw-file-content defs)
                       (raw-output-path ext)
                       #:exists 'replace)
      (display-to-file (gen-rebuilt-file-content defs)
                       (rebuilt-output-path ext)
                       #:exists 'replace)
      (display-to-file (gen-info-file-content ext defs)
                       (info-output-path ext)
                       #:exists 'replace)

      (values (+ standard (length (extension-file-standard parsed)))
              (+ pseudo (length (extension-file-pseudo parsed)))
              (+ imports (length (extension-file-imports parsed)))
              (+ emitted (length defs)))))

  (display-to-file (gen-all-info-content ext->defs)
                   (all-info-output-path)
                   #:exists 'replace)
  (display-to-file (gen-extension-map-content ext->defs)
                   (extension-map-output-path)
                   #:exists 'replace)

  (printf "Generated ~a extensions\n" (length files))
  (printf "  standard definitions:  ~a\n" standard)
  (printf "  pseudo definitions:    ~a\n" pseudo)
  (printf "  import definitions:    ~a\n" imports)
  (printf "  emitted per extension: ~a\n" emitted)
  (printf "  raw output:            ~a\n" raw-out-dir)
  (printf "  rebuilt output:        ~a\n" rebuilt-out-dir)
  (printf "  info output:           ~a\n" info-out-dir))

(build-all)
