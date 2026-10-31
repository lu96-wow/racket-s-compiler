#lang racket
;;; amd64/amd64-elf/writer.rkt
;;;
;;; build + symbols -> ELF64 executable (bytevector).
;;;
;;; 输入：
;;;
;;;   build    (build (segment (name ...) (kind code|data|hole)
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
;;;   - 没有 plan 时一个 PT_LOAD；有 plan load 时按 build segment 生成多个 PT_LOAD；
;;;   - kind hole 的段（.bss / .tbss / guard …）作为 p_filesz < p_memsz 的零填充区；
;;;   - 另加一个 PT_GNU_STACK；
;;;   - .text/.data/.bss + .symtab/.strtab/.shstrtab section headers；
;;;   - 不做 reloc / dynamic linking。
;;;
;;; 这是第一个可用的静态 ELF writer，不是完整 linker。

(require racket/list
         racket/string
         "../amd64-asm/sexp.rkt")

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
      [(hole) (if (eq? name 'bss) ".bss" (format ".~a" name))]
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
    [(data hole) #x3]               ; ALLOC | WRITE
    [else #x3]))

(define (section-type kind)
  (if (eq? kind 'hole) 8 1))        ; NOBITS / PROGBITS

(define (section-align kind)
  (if (eq? kind 'code) 16 8))

(define (make-symbol-records symbols)
  (for/list ([s (in-list symbols)])
    (elf-symbol (mangle-symbol-name (symbol-chain s))
                (symbol-chain s)
                (symbol-seg s)
                (symbol-address s))))

;; ---------------------------------------------------------------------------
;; image plan
;; ---------------------------------------------------------------------------

(define (plan-clauses plan key)
  (for/list ([c (in-list plan)]
             #:when (and (pair? c) (eq? (car c) key)))
    c))

(define (plan-field clause key)
  (cond ((assq key (cdr clause)) => cadr)
        [else #f]))

(define (plan-entry-expr plan)
  (define c (for/first ([c (in-list (plan-clauses plan 'entry))]) c))
  (and c (plan-field c 'entry)))

(define (plan-load-for plan name)
  (for/first ([c (in-list (plan-clauses plan 'load))]
              #:when (eq? (plan-field c 'name) name))
    c))

(define (plan-section-for plan segment)
  (for/first ([c (in-list (plan-clauses plan 'section))]
              #:when (eq? (plan-field c 'segment) segment))
    c))

(define (plan-symbol-for plan chain)
  (for/first ([c (in-list (plan-clauses plan 'symbol))]
              #:when (equal? (plan-field c 'name) chain))
    c))

(define (find-symbol-address symbols chain)
  (for/first ([s (in-list symbols)]
              #:when (equal? (symbol-chain s) chain))
    (symbol-address s)))

(define (eval-plan-expr expr symbols)
  (and expr
       (eval-address expr
                     (lambda (chain)
                       (find-symbol-address symbols chain)))))

(define (perm-string->flags str)
  (+ (if (and (> (string-length str) 0)
              (char=? (string-ref str 0) #\r))
         4 0)
     (if (and (> (string-length str) 1)
              (char=? (string-ref str 1) #\w))
         2 0)
     (if (and (> (string-length str) 2)
              (char=? (string-ref str 2) #\x))
         1 0)))

(define (perm->flags x)
  (cond
    [(symbol? x) (perm-string->flags (symbol->string x))]
    [(string? x) (perm-string->flags x)]
    [else (error 'write-elf "bad load flags: ~e" x)]))

(define (section-flags->number x)
  (cond
    [(symbol? x) (perm->flags x)]
    [(list? x)
     (for/fold ([f 0]) ([s (in-list x)])
       (bitwise-ior f
                    (case s
                      [(write) #x1]
                      [(alloc) #x2]
                      [(exec execinstr) #x4]
                      [else 0])))]
    [else (error 'write-elf "bad section flags: ~e" x)]))

(define (section-type-name->number x)
  (case x
    [(null) 0]
    [(progbits) 1]
    [(symtab) 2]
    [(strtab) 3]
    [(rela) 4]
    [(hash) 5]
    [(dynamic) 6]
    [(note) 7]
    [(nobits) 8]
    [(rel) 9]
    [(dynsym) 11]
    [else (error 'write-elf "bad section type: ~e" x)]))

(define (symbol-type->number x)
  (case x
    [(notype) 0]
    [(object) 1]
    [(func) 2]
    [(section) 3]
    [(file) 4]
    [(common) 5]
    [(tls) 6]
    [else (error 'write-elf "bad symbol type: ~e" x)]))

(define (symbol-bind->number x)
  (case x
    [(local) 0]
    [(global) 1]
    [(weak) 2]
    [else (error 'write-elf "bad symbol bind: ~e" x)]))

(define (symbol-type->name n)
  (case n
    [(0) 'notype]
    [(1) 'object]
    [(2) 'func]
    [(3) 'section]
    [(4) 'file]
    [(5) 'common]
    [(6) 'tls]
    [else n]))

(define (symbol-bind->name n)
  (case n
    [(0) 'local]
    [(1) 'global]
    [(2) 'weak]
    [else n]))

(define (segment-load-flags plan s)
  (define p (plan-load-for plan (elf-segment-name s)))
  (define f (and p (plan-field p 'flags)))
  (cond
    [f (perm->flags f)]
    [(eq? (elf-segment-kind s) 'code) #x5] ; R|X
    [else #x6]))                            ; R|W

(define (segment-load-align plan s)
  (define p (plan-load-for plan (elf-segment-name s)))
  (or (and p (plan-field p 'align)) 4096))

(define (segment-section-name-from-plan plan s)
  (define p (plan-section-for plan (elf-segment-name s)))
  (define n (and p (plan-field p 'name)))
  (cond
    [(string? n) n]
    [(symbol? n) (symbol->string n)]
    [else (segment-section-name (elf-segment-name s)
                                (elf-segment-kind s))]))

(define (segment-section-type plan s)
  (define p (plan-section-for plan (elf-segment-name s)))
  (define t (and p (plan-field p 'type)))
  (if t (section-type-name->number t) (section-type (elf-segment-kind s))))

(define (segment-section-flags plan s)
  (define p (plan-section-for plan (elf-segment-name s)))
  (define f (and p (plan-field p 'flags)))
  (if f (section-flags->number f) (section-flags (elf-segment-kind s))))

(define (segment-section-align plan s)
  (define p (plan-section-for plan (elf-segment-name s)))
  (or (and p (plan-field p 'align))
      (section-align (elf-segment-kind s))))

(define (write-phdr! out off type flags offset vaddr paddr filesz memsz align)
  (set-u32! out off type)
  (set-u32! out (+ off 4) flags)
  (set-u64! out (+ off 8) offset)
  (set-u64! out (+ off 16) vaddr)
  (set-u64! out (+ off 24) paddr)
  (set-u64! out (+ off 32) filesz)
  (set-u64! out (+ off 40) memsz)
  (set-u64! out (+ off 48) align))

;; ---------------------------------------------------------------------------
;; main
;; ---------------------------------------------------------------------------

(define (write-elf build symbols
                   #:entry [entry 'elf-entry]
                   #:entry-address [entry-address #f]
                   #:plan [plan '()])
  (define plan* (or plan '()))
  (define segments (build-segments build))
  (unless (pair? segments)
    (error 'write-elf "build has no segments"))
  (define image-base (apply min (map elf-segment-start segments)))
  (define image-end (apply max (map (lambda (s)
                                      (+ (elf-segment-start s) (elf-segment-size s)))
                                    segments)))
  (define file-mem-end
    (for/fold ([end image-base]) ([s (in-list segments)]
                                  #:unless (eq? (elf-segment-kind s) 'hole))
      (max end (+ (elf-segment-start s) (elf-segment-size s)))))
  (define data-span (max 0 (- file-mem-end image-base)))
  (define mem-span (max 0 (- image-end image-base)))

  (define plan-entry (plan-entry-expr plan*))
  (define entry-path (and entry (normalize-entry entry)))
  (define entry*
    (or entry-address
        (and plan-entry (eval-plan-expr plan-entry symbols))
        (and entry-path (find-symbol-address symbols entry-path))
        (for/first ([s (in-list segments)] #:when (eq? (elf-segment-kind s) 'code))
          (elf-segment-start s))
        (error 'write-elf "no entry symbol ~e and no code segment" entry)))

  (define plan-loads (plan-clauses plan* 'load))
  (define per-segment-loads? (pair? plan-loads))
  (for ([p (in-list plan-loads)])
    (define name (plan-field p 'name))
    (unless (for/or ([s (in-list segments)])
              (eq? name (elf-segment-name s)))
      (error 'write-elf "plan load names unknown segment: ~e" name)))

  (define layout-align
    (if per-segment-loads?
        (apply max 4096
               (for/list ([s (in-list segments)])
                 (segment-load-align plan* s)))
        4096))
  (define phnum
    (if per-segment-loads?
        (+ 1 (length segments))
        2))
  (define ehdr-size 64)
  (define phdr-size 56)
  (define header-end (+ ehdr-size (* phdr-size phnum)))
  ;; p_offset and p_vaddr must be congruent modulo p_align.
  (define data-offset
    (+ (align-up header-end layout-align)
       (modulo image-base layout-align)))

  ;; section names / indices
  (define base-section-names
    (for/list ([s (in-list segments)])
      (segment-section-name-from-plan plan* s)))
  (define segment-section-names (unique-names base-section-names))
  (define segment-section-index
    (for/hash ([name (in-list segment-section-names)]
               [i (in-naturals 1)])
      (values name i)))
  (define segment->section-index
    (for/hash ([s (in-list segments)]
               [name (in-list segment-section-names)])
      (values (elf-segment-name s) (hash-ref segment-section-index name))))

  (define segment-sections
    (for/list ([s (in-list segments)] [name (in-list segment-section-names)])
      (elf-section name
                   (segment-section-type plan* s)
                   (segment-section-flags plan* s)
                   (elf-segment-start s)
                   (+ data-offset (- (elf-segment-start s) image-base))
                   (elf-segment-size s)
                   0 0
                   (segment-section-align plan* s)
                   0)))

  ;; symbols + string table
  (define symbol-records (make-symbol-records symbols))
  (define symbol-names (cons "" (map elf-symbol-name symbol-records)))
  (define-values (symbol-name-offsets symbol-strtab)
    (build-string-table symbol-names))
  (define symtab-size (* 24 (add1 (length symbol-records))))
  (define symtab-bytes (make-bytes symtab-size 0))
  (define symbol-output '())
  (for ([sym (in-list symbol-records)]
        [orig (in-list symbols)]
        [i (in-naturals 1)])
    (define off (* 24 i))
    (define seg (elf-symbol-seg sym))
    (define kind
      (for/first ([s (in-list segments)] #:when (eq? (elf-segment-name s) seg))
        (elf-segment-kind s)))
    (define plan-sym (plan-symbol-for plan* (symbol-chain orig)))
    (define plan-size
      (and plan-sym (eval-plan-expr (plan-field plan-sym 'size) symbols)))
    (define plan-type
      (and plan-sym
           (plan-field plan-sym 'type)
           (symbol-type->number (plan-field plan-sym 'type))))
    (define plan-bind
      (and plan-sym
           (plan-field plan-sym 'bind)
           (symbol-bind->number (plan-field plan-sym 'bind))))
    (define plan-section
      (and plan-sym (plan-field plan-sym 'section)))
    (define section-index
      (cond
        [(and plan-section
              (symbol? plan-section)
              (hash-ref segment->section-index plan-section #f))]
        [(and plan-section
              (for/first ([sec (in-list segment-sections)]
                          [idx (in-naturals 1)]
                          #:when (equal? (elf-section-name sec)
                                         (format "~a" plan-section)))
                idx))]
        [else (hash-ref segment->section-index seg 0)]))
    (define type (or plan-type (if (eq? kind 'code) 2 1)))
    (define bind (or plan-bind 1))
    (set-u32! symtab-bytes off (string-offset symbol-name-offsets (elf-symbol-name sym)))
    (set-u8! symtab-bytes (+ off 4)
             (bitwise-ior (arithmetic-shift bind 4) type))
    (set-u8! symtab-bytes (+ off 5) 0)
    (set-u16! symtab-bytes (+ off 6) section-index)
    (set-u64! symtab-bytes (+ off 8) (elf-symbol-address sym))
    (set-u64! symtab-bytes (+ off 16) (or plan-size 0))
    (set! symbol-output
          (cons (list 'symbol
                      (list 'name (elf-symbol-name sym))
                      (list 'value (elf-symbol-address sym))
                      (list 'size (or plan-size 0))
                      (list 'section section-index)
                      (list 'type (symbol-type->name type))
                      (list 'bind (symbol-bind->name bind)))
                symbol-output)))

  (define symtab-index (+ 1 (length segments)))
  (define strtab-index (+ symtab-index 1))
  (define shstrtab-index (+ strtab-index 1))
  (define section-names
    (append (list "")
            segment-section-names
            (list ".symtab" ".strtab" ".shstrtab")))
  (define-values (section-name-offsets shstrtab)
    (build-string-table section-names))

  (define symtab-offset (align-up (+ data-offset data-span) 8))
  (define strtab-offset (+ symtab-offset symtab-size))
  (define shstrtab-offset (+ strtab-offset (bytes-length symbol-strtab)))
  (define shoff (align-up (+ shstrtab-offset (bytes-length shstrtab)) 8))
  (define shnum (+ shstrtab-index 1))
  (define total-size (+ shoff (* 64 shnum)))
  (define out (make-bytes total-size 0))

  (define sections
    (append
     (list (elf-section "" 0 0 0 0 0 0 0 0 0))
     segment-sections
     (list (elf-section ".symtab" 2 0 0 symtab-offset symtab-size
                        strtab-index 1 8 24)
           (elf-section ".strtab" 3 0 0 strtab-offset
                        (bytes-length symbol-strtab) 0 0 1 0)
           (elf-section ".shstrtab" 3 0 0 shstrtab-offset
                        (bytes-length shstrtab) 0 0 1 0))))

  ;; load program headers
  (define load-phdrs
    (if per-segment-loads?
        (for/list ([s (in-list segments)])
          (define kind (elf-segment-kind s))
          (define b (elf-segment-bytes s))
          (unless (or (eq? kind 'hole) (= (bytes-length b) (elf-segment-size s)))
            (error 'write-elf "segment ~a file size mismatch"
                   (elf-segment-name s)))
          (list 1
                (segment-load-flags plan* s)
                (+ data-offset (- (elf-segment-start s) image-base))
                (elf-segment-start s)
                (elf-segment-start s)
                (if (eq? kind 'hole) 0 (bytes-length b))
                (elf-segment-size s)
                (segment-load-align plan* s)))
        (list (list 1 #x7 data-offset image-base image-base
                    data-span mem-span 4096))))

  ;; copy segment bytes
  (for ([s (in-list segments)] #:unless (eq? (elf-segment-kind s) 'hole))
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
  (set-u16! out 56 (+ 1 (length load-phdrs)))
  (set-u16! out 58 64)
  (set-u16! out 60 shnum)
  (set-u16! out 62 shstrtab-index)

  (for ([ph (in-list load-phdrs)] [i (in-naturals)])
    (write-phdr! out (+ ehdr-size (* phdr-size i))
                  (list-ref ph 0) (list-ref ph 1)
                  (list-ref ph 2) (list-ref ph 3) (list-ref ph 4)
                  (list-ref ph 5) (list-ref ph 6) (list-ref ph 7)))

  ;; PT_GNU_STACK
  (define gnu-stack-offset (+ ehdr-size (* phdr-size (length load-phdrs))))
  (write-phdr! out gnu-stack-offset #x6474e551 #x6 0 0 0 0 0 16)

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
        (cons 'symbols (reverse symbol-output))
        (list 'bytes out)))
