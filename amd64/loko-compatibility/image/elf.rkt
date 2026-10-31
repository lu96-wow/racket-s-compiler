#lang racket
;;; amd64/loko-compatibility/image/elf.rkt
;;;
;;; build + symbols -> ELF64 executable (bytevector).
;;;
;;; 输入：
;;;
;;;   build    (build (segment (name ...) (kind code|data|bss)
;;;                            (start ...) (size ...) (bytes ...)) ...)
;;;   symbols  (symbol chain segment offset address) ...
;;;
;;; 输出：
;;;
;;;   (elf
;;;     (entry 地址)
;;;     (size n)
;;;     (sections (section ...) ...)
;;;     (bytes #"..."))
;;;
;;; 当前实现：
;;;   - 一个 PT_LOAD，覆盖从最小段起点到最大段终点的连续内存；
;;;   - 末尾的 bss 作为 p_filesz < p_memsz 的零填充区；
;;;   - 另加一个 PT_GNU_STACK；
;;;   - .text/.data/.bss + .symtab/.strtab/.shstrtab section headers；
;;;   - 不做 reloc / dynamic linking。
;;;
;;; 这是第一个可用的静态 ELF writer，不是完整 linker。

(require racket/list
         racket/string)

(provide write-elf)

(struct elf-segment (name kind start size bytes) #:transparent)
(struct elf-section (name type flags addr offset size link info align entsize) #:transparent)
(struct elf-symbol (name chain seg address) #:transparent)

(define (field-value key row)
  (cond ((assq key (cdr row)) => cadr)
        [else #f]))

(define (align-up n align)
  (* align (quotient (+ n (sub1 align)) align)))

;; ---------------------------------------------------------------------------
;; byte writing
;; ---------------------------------------------------------------------------

(define (set-u8! bv off n)
  (bytes-set! bv off (bitwise-and n #xff)))

(define (set-u16! bv off n)
  (set-u8! bv off n)
  (set-u8! bv (+ off 1) (arithmetic-shift n -8)))

(define (set-u32! bv off n)
  (set-u16! bv off n)
  (set-u16! bv (+ off 2) (arithmetic-shift n -16)))

(define (set-u64! bv off n)
  (set-u32! bv off n)
  (set-u32! bv (+ off 4) (arithmetic-shift n -32)))

;; ---------------------------------------------------------------------------
;; input parsing
;; ---------------------------------------------------------------------------

(define (build-segments build)
  (unless (and (pair? build) (eq? (car build) 'build))
    (error 'write-elf "expected build: ~e" build))
  (for/list ([s (in-list (cdr build))])
    (elf-segment (field-value 'name s)
                 (field-value 'kind s)
                 (field-value 'start s)
                 (field-value 'size s)
                 (field-value 'bytes s))))

(define (symbol-chain s) (cadr s))
(define (symbol-seg s) (caddr s))
(define (symbol-address s) (list-ref s 4))

(define (normalize-entry entry)
  (cond
    [(symbol? entry) (list entry)]
    [(and (list? entry) (pair? entry) (andmap (lambda (x) (or (symbol? x) (string? x) (number? x))) entry))
     entry]
    [else #f]))

(define (find-entry-address symbols path)
  (for/first ([s (in-list symbols)]
              #:when (equal? (symbol-chain s) path))
    (symbol-address s)))

;; ---------------------------------------------------------------------------
;; names
;; ---------------------------------------------------------------------------

(define (mangle-symbol-name chain)
  (define out
    (for/list ([x (in-list chain)])
      (for/list ([c (in-string (format "~a" x))])
        (case c
          [(#\-) #\_]
          [(#\:) #\_]
          [(#\/) #\_]
          [(#\!) #\_]
          [(#\?) #\_]
          [(#\*) #\_]
          [else c]))))
  (define s (list->string (append* out)))
  (if (string=? s "") "symbol" s))

(define (segment-section-name name kind)
  (define base
    (case kind
      [(code) (if (eq? name 'text) ".text" (format ".~a" name))]
      [(data) (if (eq? name 'data) ".data" (format ".~a" name))]
      [(bss) (if (eq? name 'bss) ".bss" (format ".~a" name))]
      [else (format ".~a" name)]))
  base)

(define (unique-names names)
  (define seen (make-hash))
  (for/list ([name (in-list names)])
    (let loop ([n 0])
      (define candidate (if (zero? n) name (format "~a.~a" name n)))
      (cond
        [(hash-ref seen candidate #f) (loop (add1 n))]
        [else (hash-set! seen candidate #t) candidate]))))

;; ---------------------------------------------------------------------------
;; string tables
;; ---------------------------------------------------------------------------

(define (build-string-table names)
  ;; Offset 0 is the mandatory empty string.
  (define out (bytes 0))
  (define offsets '())
  (define cursor 1)
  (for ([name (in-list names)])
    (define b (string->bytes/utf-8 name))
    (cond
      [(string=? name "")
       (set! offsets (cons (cons name 0) offsets))]
      [else
       (set! offsets (cons (cons name cursor) offsets))
       (set! out (bytes-append out b (bytes 0)))
       (set! cursor (+ cursor (bytes-length b) 1))]))
  (values (reverse offsets) out))

(define (string-offset offsets name)
  (define p (assoc name offsets))
  (if p (cdr p) 0))

;; ---------------------------------------------------------------------------
;; sections / symbols
;; ---------------------------------------------------------------------------

(define (section-type->name type)
  (case type
    [(0) 'null]
    [(1) 'progbits]
    [(2) 'symtab]
    [(3) 'strtab]
    [(8) 'nobits]
    [else type]))

(define (section->sexp s)
  (list 'section
        (list 'name (elf-section-name s))
        (list 'type (section-type->name (elf-section-type s)))
        (list 'flags (elf-section-flags s))
        (list 'addr (elf-section-addr s))
        (list 'offset (elf-section-offset s))
        (list 'size (elf-section-size s))
        (list 'link (elf-section-link s))
        (list 'info (elf-section-info s))
        (list 'align (elf-section-align s))
        (list 'entsize (elf-section-entsize s))))

(define (section-flags kind)
  (case kind
    [(code) #x6]                    ; ALLOC | EXECINSTR
    [(data bss) #x3]                ; ALLOC | WRITE
    [else #x3]))

(define (section-type kind)
  (if (eq? kind 'bss) 8 1))         ; NOBITS / PROGBITS

(define (section-align kind)
  (if (eq? kind 'code) 16 8))

(define (make-symbol-records symbols)
  (for/list ([s (in-list symbols)])
    (elf-symbol (mangle-symbol-name (symbol-chain s))
                (symbol-chain s)
                (symbol-seg s)
                (symbol-address s))))

;; ---------------------------------------------------------------------------
;; main
;; ---------------------------------------------------------------------------

(define (write-elf build symbols
                   #:entry [entry 'elf-entry]
                   #:entry-address [entry-address #f])
  (define segments (build-segments build))
  (unless (pair? segments)
    (error 'write-elf "build has no segments"))
  (define image-base (apply min (map elf-segment-start segments)))
  (define image-end (apply max (map (lambda (s)
                                      (+ (elf-segment-start s) (elf-segment-size s)))
                                    segments)))
  (define file-mem-end
    (for/fold ([end image-base]) ([s (in-list segments)]
                                  #:unless (eq? (elf-segment-kind s) 'bss))
      (max end (+ (elf-segment-start s) (elf-segment-size s)))))
  (define data-span (max 0 (- file-mem-end image-base)))
  (define mem-span (max 0 (- image-end image-base)))

  (define entry-path (and entry (normalize-entry entry)))
  (define entry*
    (or entry-address
        (and entry-path (find-entry-address symbols entry-path))
        (for/first ([s (in-list segments)] #:when (eq? (elf-segment-kind s) 'code))
          (elf-segment-start s))
        (error 'write-elf "no entry symbol ~e and no code segment" entry)))

  ;; section names: null, segment sections, symtab, strtab, shstrtab
  (define segment-section-names
    (unique-names (for/list ([s (in-list segments)])
                    (segment-section-name (elf-segment-name s)
                                          (elf-segment-kind s)))))
  (define segment-section-index
    (for/hash ([name (in-list segment-section-names)]
               [i (in-naturals 1)])
      (values name i)))
  (define segment->section-index
    (for/hash ([s (in-list segments)]
               [name (in-list segment-section-names)])
      (values (elf-segment-name s) (hash-ref segment-section-index name))))

  (define symtab-index (+ 1 (length segments)))
  (define strtab-index (+ symtab-index 1))
  (define shstrtab-index (+ strtab-index 1))
  (define shnum (+ shstrtab-index 1))

  ;; symbol records + string table
  (define symbol-records (make-symbol-records symbols))
  (define symbol-names (cons "" (map elf-symbol-name symbol-records)))
  (define-values (symbol-name-offsets symbol-strtab)
    (build-string-table symbol-names))
  (define symtab-size (* 24 (add1 (length symbol-records))))
  (define symtab-bytes (make-bytes symtab-size 0))
  (for ([sym (in-list symbol-records)] [i (in-naturals 1)])
    (define off (* 24 i))
    (define seg (elf-symbol-seg sym))
    (define section-index (hash-ref segment->section-index seg 0))
    (define kind
      (for/first ([s (in-list segments)] #:when (eq? (elf-segment-name s) seg))
        (elf-segment-kind s)))
    (set-u32! symtab-bytes off (string-offset symbol-name-offsets (elf-symbol-name sym)))
    (set-u8! symtab-bytes (+ off 4)
             (bitwise-ior (arithmetic-shift 1 4)
                          (if (eq? kind 'code) 2 1)))
    (set-u8! symtab-bytes (+ off 5) 0)
    (set-u16! symtab-bytes (+ off 6) section-index)
    (set-u64! symtab-bytes (+ off 8) (elf-symbol-address sym))
    (set-u64! symtab-bytes (+ off 16) 0))

  (define section-names
    (append (list "")
            segment-section-names
            (list ".symtab" ".strtab" ".shstrtab")))
  (define-values (section-name-offsets shstrtab)
    (build-string-table section-names))

  (define ehdr-size 64)
  (define phdr-size 56)
  (define phnum 2)
  (define header-end (+ ehdr-size (* phdr-size phnum)))
  ;; p_offset and p_vaddr must be congruent modulo p_align.
  (define data-offset
    (+ (align-up header-end 4096) (modulo image-base 4096)))
  (define symtab-offset (align-up (+ data-offset data-span) 8))
  (define strtab-offset (+ symtab-offset symtab-size))
  (define shstrtab-offset (+ strtab-offset (bytes-length symbol-strtab)))
  (define shoff (align-up (+ shstrtab-offset (bytes-length shstrtab)) 8))
  (define total-size (+ shoff (* 64 shnum)))
  (define out (make-bytes total-size 0))

  ;; section headers
  (define sections
    (append
     (list (elf-section "" 0 0 0 0 0 0 0 0 0))
     (for/list ([s (in-list segments)] [name (in-list segment-section-names)])
       (elf-section name
                    (section-type (elf-segment-kind s))
                    (section-flags (elf-segment-kind s))
                    (elf-segment-start s)
                    (+ data-offset (- (elf-segment-start s) image-base))
                    (elf-segment-size s)
                    0 0
                    (section-align (elf-segment-kind s))
                    0))
     (list (elf-section ".symtab" 2 0 0 symtab-offset symtab-size
                        strtab-index 1 8 24)
           (elf-section ".strtab" 3 0 0 strtab-offset
                        (bytes-length symbol-strtab) 0 0 1 0)
           (elf-section ".shstrtab" 3 0 0 shstrtab-offset
                        (bytes-length shstrtab) 0 0 1 0))))

  ;; copy segment bytes
  (for ([s (in-list segments)] #:unless (eq? (elf-segment-kind s) 'bss))
    (define b (elf-segment-bytes s))
    (unless (= (bytes-length b) (elf-segment-size s))
      (error 'write-elf "segment ~a file size mismatch"
             (elf-segment-name s)))
    (bytes-copy! out
                 (+ data-offset (- (elf-segment-start s) image-base))
                 b))
  (bytes-copy! out symtab-offset symtab-bytes)
  (bytes-copy! out strtab-offset symbol-strtab)
  (bytes-copy! out shstrtab-offset shstrtab)

  ;; ELF header
  (set-u8! out 0 #x7f)
  (set-u8! out 1 (char->integer #\E))
  (set-u8! out 2 (char->integer #\L))
  (set-u8! out 3 (char->integer #\F))
  (set-u8! out 4 2)                 ; ELFCLASS64
  (set-u8! out 5 1)                 ; ELFDATA2LSB
  (set-u8! out 6 1)                 ; EV_CURRENT
  (set-u8! out 7 0)                 ; ELFOSABI_SYSV
  (set-u8! out 8 0)
  (set-u16! out 16 2)               ; ET_EXEC
  (set-u16! out 18 #x3e)            ; EM_X86_64
  (set-u32! out 20 1)               ; EV_CURRENT
  (set-u64! out 24 entry*)
  (set-u64! out 32 ehdr-size)
  (set-u64! out 40 shoff)
  (set-u32! out 48 0)
  (set-u16! out 52 ehdr-size)
  (set-u16! out 54 phdr-size)
  (set-u16! out 56 phnum)
  (set-u16! out 58 64)
  (set-u16! out 60 shnum)
  (set-u16! out 62 shstrtab-index)

  ;; PT_LOAD
  (define ph0 ehdr-size)
  (set-u32! out ph0 1)
  (set-u32! out (+ ph0 4) #x7)      ; R|W|X (first version)
  (set-u64! out (+ ph0 8) data-offset)
  (set-u64! out (+ ph0 16) image-base)
  (set-u64! out (+ ph0 24) image-base)
  (set-u64! out (+ ph0 32) data-span)
  (set-u64! out (+ ph0 40) mem-span)
  (set-u64! out (+ ph0 48) 4096)

  ;; PT_GNU_STACK
  (define ph1 (+ ehdr-size phdr-size))
  (set-u32! out ph1 #x6474e551)
  (set-u32! out (+ ph1 4) #x6)      ; R|W
  (set-u64! out (+ ph1 8) 0)
  (set-u64! out (+ ph1 16) 0)
  (set-u64! out (+ ph1 24) 0)
  (set-u64! out (+ ph1 32) 0)
  (set-u64! out (+ ph1 40) 0)
  (set-u64! out (+ ph1 48) 16)

  ;; section headers
  (for ([s (in-list sections)] [i (in-naturals)])
    (define off (+ shoff (* 64 i)))
    (set-u32! out off (string-offset section-name-offsets (elf-section-name s)))
    (set-u32! out (+ off 4) (elf-section-type s))
    (set-u64! out (+ off 8) (elf-section-flags s))
    (set-u64! out (+ off 16) (elf-section-addr s))
    (set-u64! out (+ off 24) (elf-section-offset s))
    (set-u64! out (+ off 32) (elf-section-size s))
    (set-u32! out (+ off 40) (elf-section-link s))
    (set-u32! out (+ off 44) (elf-section-info s))
    (set-u64! out (+ off 48) (elf-section-align s))
    (set-u64! out (+ off 56) (elf-section-entsize s)))

  (list 'elf
        (list 'entry entry*)
        (list 'size total-size)
        (cons 'sections (map section->sexp sections))
        (list 'bytes out)))
