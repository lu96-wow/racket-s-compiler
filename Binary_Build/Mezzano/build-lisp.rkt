#lang racket

;; ============================================================
;; Build script: Generates Mezzano lap-riscv64.lisp from
;; riscv-opcodes source files
;; ============================================================

(require "../riscv/parse/main.rkt"
         "gen-lisp.rkt")

;; ============================================================
;; Configuration
;; ============================================================

(define input-dir "../riscv-opcodes/extensions/")
(define output-dir "../../../../MBuild/Mezzano/compiler/")
(define fallback-dir (build-path (current-directory) "Mezzano_output"))
(define output-file "lap-riscv64-gen.lisp")

;; ============================================================
;; Discover & build
;; ============================================================

(define (discover-source-files dir)
  (define all-entries (directory-list dir))
  (define file-entries
    (filter (λ (name)
              (let ([p (build-path dir name)])
                (file-exists? p)))
            all-entries))
  (sort file-entries (λ (a b) (string<? (path->string a) (path->string b)))))

(define (make-extension-sources dir files)
  (for/list ([f (in-list files)])
    (make-extension-source (build-path dir f))))

(define (build-lisp)
  (printf "=== Racket-S-Compiler → Mezzano LAP Generator ===\n\n")

  ;; 1. Discover source files
  (printf "[1/3] Discovering RISC-V opcode sources...\n")
  (define source-files (discover-source-files input-dir))
  (define ext-sources (make-extension-sources input-dir source-files))
  (printf "  Found ~a extension files\n\n" (length ext-sources))

  ;; 2. Generate Lisp code
  (printf "[2/3] Generating Mezzano LAP code...\n")
  (define lisp-content (gen-lisp-master-file ext-sources))

  ;; 3. Write output
  (printf "\n[3/3] Writing output...\n")
  (define full-output-path
    (if (directory-exists? output-dir)
        (build-path output-dir output-file)
        (let ([alt-dir (build-path (current-directory) "Mezzano_output")])
          (unless (directory-exists? alt-dir)
            (make-directory* alt-dir))
          (printf "  Output directory ~a not found, writing to ~a\n" output-dir alt-dir)
          (build-path alt-dir output-file))))

  (display-to-file lisp-content full-output-path #:exists 'replace)

  (printf "\n=== Done! ===\n")
  (printf "Output: ~a\n" full-output-path)
  (printf "Size: ~a bytes\n" (string-length lisp-content))

  ;; Print instruction counts
  (define target-extensions
    '(rv_i rv64_i rv_m rv64_m rv_a rv64_a
      rv_f rv_d rv64_f rv64_d
      rv_zicsr rv_zifencei
      rv_zba rv64_zba rv_zbb rv64_zbb rv_zbs rv64_zbs))
  (printf "\nInstructions by extension:\n")
  (define total 0)
  (for ([ext-sym (in-list target-extensions)])
    (define esrc (findf (λ (e) (equal? (extension-source-type-sym e) ext-sym))
                        ext-sources))
    (if esrc
        (let* ([path (extension-source-path esrc)]
               [defs (parse-file path)]
               [cnt (length defs)])
          (printf "  ~a: ~a\n" ext-sym cnt)
          (set! total (+ total cnt)))
        (printf "  ~a: NOT FOUND\n" ext-sym)))
  (printf "  Total: ~a instructions\n" total))

(build-lisp)
