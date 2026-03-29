#lang racket

(require "riscv/instruction_build.rkt"
         "riscv/instruction_info_build.rkt")

(define input-dir "riscv-opcodes/extensions/")
(define output-dir "riscv/instruction/")
(define output-info-dir "riscv/instruction_info/")

(for ([dir (list output-dir output-info-dir)])
  (unless (directory-exists? dir)
    (make-directory* dir)))

(define (list-extension-files dir)
  (filter (λ (name)
            (let ([full-path (build-path dir name)])
              (file-exists? full-path)))
          (directory-list dir)))

(define (filename->type-sym file)
  (string->symbol (path->string (path-replace-suffix file ""))))

(define (build-all-extensions in-dir out-dir out-info-dir)
  (define file-infos '())

  (for ([file (in-list (list-extension-files in-dir))])
    (define in-path (build-path in-dir file))
    (define base-name (path-replace-suffix file ""))
    (define type-sym (filename->type-sym file))

    (define out-instr (build-path out-dir (string-append (path->string base-name) ".rkt")))
    (define out-info  (build-path out-info-dir (string-append (path->string base-name) ".rkt")))

    (printf "Building ~a\n" in-path)
    (printf "  -> ~a\n" out-instr)
    (printf "  -> ~a\n" out-info)

    (build-riscv-instruction-file in-path out-instr)
    (build-riscv-instruction-info-file in-path out-info type-sym)

    (set! file-infos (cons (cons in-path type-sym) file-infos)))

  (define global-out (build-path out-info-dir "instruction_info.rkt"))
  (printf "Building global instruction map -> ~a\n" global-out)
  (build-global-instruction-extension-map (reverse file-infos) global-out)
  (define stats-out (build-path out-info-dir "instruction_counts.rkt"))
  (printf "Generating instruction statistics -> ~a\n" stats-out)
  (define-values (uniq dup exts)
    (build-instruction-counts (reverse file-infos) stats-out))
  (printf "\nBuild Summary:\n")
  (printf "  Total unique instructions: ~a\n" uniq)
  (printf "  Total definitions (with duplicates): ~a\n" dup)
  (printf "  Extensions: ~a\n\n" (length exts)))

(build-all-extensions input-dir output-dir output-info-dir)