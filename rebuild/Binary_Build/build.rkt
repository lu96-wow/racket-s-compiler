#lang racket/base

(require racket/file
         racket/path
         racket/string
         racket/runtime-path
         "riscv/parse/main.rkt"
         "riscv/codegen.rkt"
         "riscv/info-codegen.rkt")

(define-runtime-path source-dir "../riscv-opcodes/extensions")
(define-runtime-path raw-out-dir "riscv/instruction/raw")
(define-runtime-path rebuilt-out-dir "riscv/instruction/rebuilt")
(define-runtime-path info-out-dir "riscv/instruction_info")

(define (extension-files dir)
  (sort
   (for/list ([name (in-list (directory-list dir))]
              #:when (let ([p (build-path dir name)])
                       (and (file-exists? p)
                            (not (directory-exists? p))
                            (string-prefix? (path->string name) "rv"))))
     (build-path dir name))
   (lambda (a b)
     (string<? (path->string a) (path->string b)))))

(define (extension-stem path)
  (path->string (path-replace-suffix (file-name-from-path path) "")))

(define (output-path dir source-path)
  (build-path dir (string-append (extension-stem source-path) ".rkt")))

(define (build-all)
  (make-directory* raw-out-dir)
  (make-directory* rebuilt-out-dir)
  (make-directory* info-out-dir)

  (define files (extension-files source-dir))
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
              ([path (in-list files)]
               [parsed (in-list parsed-files)])
      (define defs (prepare-extension-defs parsed extension-map))
      (define ext (extension-stem path))
      (hash-set! ext->defs ext defs)
      (display-to-file (gen-raw-file-content defs)
                       (output-path raw-out-dir path)
                       #:exists 'replace)
      (display-to-file (gen-rebuilt-file-content defs)
                       (output-path rebuilt-out-dir path)
                       #:exists 'replace)
      (display-to-file (gen-info-file-content ext defs)
                       (build-path info-out-dir (string-append ext ".rkt"))
                       #:exists 'replace)
      (values (+ standard (length (extension-file-standard parsed)))
              (+ pseudo (length (extension-file-pseudo parsed)))
              (+ imports (length (extension-file-imports parsed)))
              (+ emitted (length defs)))))

  (display-to-file (gen-all-info-content ext->defs)
                   (build-path info-out-dir "all.rkt")
                   #:exists 'replace)
  (display-to-file (gen-extension-map-content ext->defs)
                   (build-path info-out-dir "instruction_extensions.rkt")
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
