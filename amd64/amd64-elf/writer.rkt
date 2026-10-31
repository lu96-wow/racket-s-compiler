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
;;;   plan     (image-plan (entry ...) (region ...) (load ...) (symbol ...))
;;;
;;; 输出：
;;;
;;;   (elf
;;;     (entry 地址)
;;;     (size n)
;;;     (sections (section ...) ...)
;;;     (symbols (symbol ...) ...)
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

(define (perm-string x)
  (cond
    [(symbol? x) (symbol->string x)]
    [(string? x) x]
    [else (error 'write-elf "bad permission: ~e" x)]))

(define (perm->pf-flags x)
  (define str (perm-string x))
  (+ (if (and (> (string-length str) 0) (char=? (string-ref str 0) #\r)) 4 0)
     (if (and (> (string-length str) 1) (char=? (string-ref str 1) #\w)) 2 0)
     (if (and (> (string-length str) 2) (char=? (string-ref str 2) #\x)) 1 0)))

(define (perm->section-flags x)
  (define str (perm-string x))
  (bitwise-ior #x2                          ; ALLOC
               (if (and (> (string-length str) 1)
                        (char=? (string-ref str 1) #\w))
                   #x1 0)                   ; WRITE
               (if (and (> (string-length str) 2)
                        (char=? (string-ref str 2) #\x))
                   #x4 0)))                 ; EXECINSTR

(define (perm-exec? x)
  (define str (perm-string x))
  (and (> (string-length str) 2) (char=? (string-ref str 2) #\x)))

(define (content->section-type content)
  (case content
    [(materialized) 1]                  ; PROGBITS
    [(reserved) 8]                      ; NOBITS
    [else (error 'write-elf "bad region content: ~e" content)]))

(define (default-content kind)
  (if (eq? kind 'hole) 'reserved 'materialized))

(define (default-perm kind)
  (if (eq? kind 'code) 'r-x 'rw-))

(define (default-section-align kind)
  (if (eq? kind 'code) 16 8))

(define (make-symbol-records symbols)
  (for/list ([s (in-list symbols)])
    (elf-symbol (mangle-symbol-name (symbol-chain s))
                (symbol-chain s)
                (symbol-seg s)
                (symbol-address s))))

;; ---------------------------------------------------------------------------
;; canonical image model
;; ---------------------------------------------------------------------------

(struct image-region (id content section perm align load-id start size bytes kind)
  #:transparent)
(struct image-load (id start end file-end align flags regions) #:transparent)

(define (plan-clauses plan key)
  (for/list ([c (in-list plan)]
             #:when (and (pair? c) (eq? (car c) key)))
    c))

(define (plan-field clause key)
  (cond ((assq key (cdr clause)) => cadr)
        [else #f]))

(define (plan-entry-expr plan)
  ;; Two accepted spellings:
  ;;   (entry (entry expr))   explicit field form
  ;;   (entry expr)           the form emitted by loko-compat
  (define c (for/first ([c (in-list (plan-clauses plan 'entry))]) c))
  (and c
       (match (cdr c)
         [(list (cons 'entry expr)) expr]
         [(list expr) expr]
         [_ #f])))

(define (plan-region-for plan id)
  (for/first ([c (in-list (plan-clauses plan 'region))]
              #:when (eq? (plan-field c 'id) id))
    c))

(define (plan-load-for plan id)
  (for/first ([c (in-list (plan-clauses plan 'load))]
              #:when (eq? (plan-field c 'id) id))
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

(define (section-name-string name)
  (if (string? name) name (format "~a" name)))

;; Regions declared only in the image plan: stack, heap, guard pages, and
;; other loader/hardware-defined address ranges.  The compiler build has no
;; bytes for them, so they must be reserved.
(define (plan-only-regions plan segment-names)
  (for/list ([p (in-list (plan-clauses plan 'region))]
             #:unless (memq (plan-field p 'id) segment-names))
    (define id (plan-field p 'id))
    (define content (or (plan-field p 'content) 'reserved))
    (define start (plan-field p 'start))
    (define size (plan-field p 'size))
    (unless (eq? content 'reserved)
      (error 'write-elf "plan-only region ~a must be reserved" id))
    (unless (and (exact-integer? start) (exact-integer? size) (>= size 0))
      (error 'write-elf "plan-only reserved region ~a needs start and size" id))
    (image-region id 'reserved
                  (section-name-string (or (plan-field p 'section)
                                           (format ".~a" id)))
                  (or (plan-field p 'perm) 'rw-)
                  (or (plan-field p 'align) 8)
                  (or (plan-field p 'load) id)
                  start size #"" 'hole)))

(define (build-segment->region s plan single-default-load?)
  (define id (elf-segment-name s))
  (define kind (elf-segment-kind s))
  (define p (plan-region-for plan id))
  (define content
    (or (and p (plan-field p 'content))
        (default-content kind)))
  (define perm
    (or (and p (plan-field p 'perm))
        (default-perm kind)))
  (define section-name
    (section-name-string (or (and p (plan-field p 'section))
                             (format ".~a" id))))
  (define align
    (or (and p (plan-field p 'align))
        (default-section-align kind)))
  (define load-id
    (or (and p (plan-field p 'load))
        (if single-default-load? 'image id)))
  (define bytes (elf-segment-bytes s))
  (define size (elf-segment-size s))
  (case content
    [(materialized)
     (unless (= (bytes-length bytes) size)
       (error 'write-elf "materialized region ~a has ~a bytes, size is ~a"
              id (bytes-length bytes) size))]
    [(reserved)
     (unless (zero? (bytes-length bytes))
       (error 'write-elf "reserved region ~a has file bytes" id))]
    [else (error 'write-elf "bad region content: ~e" content)])
  (image-region id content section-name perm align load-id
                (elf-segment-start s) size bytes kind))

(define (normalize-regions segments plan)
  (define plan-regions (plan-clauses plan 'region))
  (define plan-loads (plan-clauses plan 'load))
  (define single-default-load?
    (and (null? plan-regions) (null? plan-loads)))
  (define segment-names
    (for/list ([s (in-list segments)]) (elf-segment-name s)))
  (append
   (for/list ([s (in-list segments)])
     (build-segment->region s plan single-default-load?))
   (plan-only-regions plan segment-names)))

(define (image-load-file-size load)
  (- (image-load-file-end load) (image-load-start load)))

(define (normalize-loads regions plan)
  (define plan-loads (plan-clauses plan 'load))
  (define ids
    (remove-duplicates
     (append (for/list ([c (in-list plan-loads)]) (plan-field c 'id))
             (for/list ([r (in-list regions)]) (image-region-load-id r)))))
  (for/list ([id (in-list ids)])
    (define rs
      (for/list ([r (in-list regions)]
                 #:when (eq? (image-region-load-id r) id))
        r))
    (unless (pair? rs)
      (error 'write-elf "unused image load: ~a" id))
    (define start
      (apply min (for/list ([r (in-list rs)]) (image-region-start r))))
    (define end
      (apply max (for/list ([r (in-list rs)])
                   (+ (image-region-start r) (image-region-size r)))))
    (define file-end
      (for/fold ([e start]) ([r (in-list rs)]
                             #:when (eq? (image-region-content r) 'materialized))
        (max e (+ (image-region-start r) (image-region-size r)))))
    (define flags
      (for/fold ([f 0]) ([r (in-list rs)])
        (bitwise-ior f (perm->pf-flags (image-region-perm r)))))
    (define p (plan-load-for plan id))
    (define align (or (and p (plan-field p 'align)) 4096))
    (image-load id start end file-end align flags rs)))

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
  (define regions (normalize-regions segments plan*))
  (define loads (normalize-loads regions plan*))
  (define image-base
    (apply min (for/list ([r (in-list regions)]) (image-region-start r))))
  (define image-end
    (apply max (for/list ([r (in-list regions)])
                 (+ (image-region-start r) (image-region-size r)))))
  (define file-mem-end
    (for/fold ([end image-base]) ([r (in-list regions)]
                                  #:when (eq? (image-region-content r) 'materialized))
      (max end (+ (image-region-start r) (image-region-size r)))))
  (define data-span (max 0 (- file-mem-end image-base)))
  (define mem-span (max 0 (- image-end image-base)))

  (define plan-entry (plan-entry-expr plan*))
  (define entry-path (and entry (normalize-entry entry)))
  (define entry*
    (or entry-address
        (and plan-entry (eval-plan-expr plan-entry symbols))
        (and entry-path (find-symbol-address symbols entry-path))
        (for/first ([r (in-list regions)]
                    #:when (perm-exec? (image-region-perm r)))
          (image-region-start r))
        (error 'write-elf "no entry symbol ~e and no executable region" entry)))

  (define layout-align
    (apply max 4096 (for/list ([l (in-list loads)]) (image-load-align l))))
  (define phnum (+ 1 (length loads)))
  (define ehdr-size 64)
  (define phdr-size 56)
  (define header-end (+ ehdr-size (* phdr-size phnum)))
  (define data-offset
    (+ (align-up header-end layout-align)
       (modulo image-base layout-align)))

  ;; section names / indices
  (define base-section-names
    (for/list ([r (in-list regions)]) (image-region-section r)))
  (define region-section-names (unique-names base-section-names))
  (define region->section-index
    (for/hash ([r (in-list regions)] [name (in-list region-section-names)]
               [i (in-naturals 1)])
      (values (image-region-id r) i)))
  (define region-sections
    (for/list ([r (in-list regions)] [name (in-list region-section-names)])
      (elf-section name
                   (content->section-type (image-region-content r))
                   (perm->section-flags (image-region-perm r))
                   (image-region-start r)
                   (+ data-offset (- (image-region-start r) image-base))
                   (image-region-size r)
                   0 0
                   (image-region-align r)
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
    (define plan-sym (plan-symbol-for plan* (symbol-chain orig)))
    (define region-id
      (if plan-sym (plan-field plan-sym 'region) (symbol-seg orig)))
    (define region
      (for/first ([r (in-list regions)]
                  #:when (eq? (image-region-id r) region-id))
        r))
    (unless region
      (error 'write-elf "symbol ~a references unknown region: ~e"
             (elf-symbol-name sym) region-id))
    (define section-index
      (hash-ref region->section-index region-id 0))
    (define size
      (if plan-sym
          (or (eval-plan-expr (plan-field plan-sym 'size) symbols) 0)
          0))
    (define default-type
      (if (perm-exec? (image-region-perm region)) 2 1))
    (define type
      (or (and plan-sym
               (plan-field plan-sym 'type)
               (symbol-type->number (plan-field plan-sym 'type)))
          default-type))
    (define bind
      (or (and plan-sym
               (plan-field plan-sym 'bind)
               (symbol-bind->number (plan-field plan-sym 'bind)))
          1))
    (set-u32! symtab-bytes off
              (string-offset symbol-name-offsets (elf-symbol-name sym)))
    (set-u8! symtab-bytes (+ off 4)
             (bitwise-ior (arithmetic-shift bind 4) type))
    (set-u8! symtab-bytes (+ off 5) 0)
    (set-u16! symtab-bytes (+ off 6) section-index)
    (set-u64! symtab-bytes (+ off 8) (elf-symbol-address sym))
    (set-u64! symtab-bytes (+ off 16) size)
    (set! symbol-output
          (cons (list 'symbol
                      (list 'name (elf-symbol-name sym))
                      (list 'value (elf-symbol-address sym))
                      (list 'size size)
                      (list 'section section-index)
                      (list 'type (symbol-type->name type))
                      (list 'bind (symbol-bind->name bind)))
                symbol-output)))

  (define symtab-index (+ 1 (length regions)))
  (define strtab-index (+ symtab-index 1))
  (define shstrtab-index (+ strtab-index 1))
  (define section-names
    (append (list "")
            region-section-names
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
     region-sections
     (list (elf-section ".symtab" 2 0 0 symtab-offset symtab-size
                        strtab-index 1 8 24)
           (elf-section ".strtab" 3 0 0 strtab-offset
                        (bytes-length symbol-strtab) 0 0 1 0)
           (elf-section ".shstrtab" 3 0 0 shstrtab-offset
                        (bytes-length shstrtab) 0 0 1 0))))

  (define load-phdrs
    (for/list ([l (in-list loads)])
      (list 1
            (image-load-flags l)
            (let ([filesz (image-load-file-size l)])
              (if (zero? filesz)
                  0
                  (+ data-offset (- (image-load-start l) image-base))))
            (image-load-start l)
            (image-load-start l)
            (- (image-load-file-end l) (image-load-start l))
            (- (image-load-end l) (image-load-start l))
            (image-load-align l))))

  ;; copy materialized region bytes
  (for ([r (in-list regions)]
        #:when (eq? (image-region-content r) 'materialized))
    (bytes-copy! out
                 (+ data-offset (- (image-region-start r) image-base))
                 (image-region-bytes r)))
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
