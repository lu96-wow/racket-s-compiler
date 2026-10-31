#lang racket
;;; amd64/amd64-elf/test.rkt

(require rackunit
         "../amd64-asm/target.rkt"
         "../compiler/flow/flow.rkt"
         "writer.rkt")

(define (u16 bv off)
  (+ (bytes-ref bv off)
     (arithmetic-shift (bytes-ref bv (+ off 1)) 8)))

(define (u32 bv off)
  (+ (u16 bv off)
     (arithmetic-shift (u16 bv (+ off 2)) 16)))

(define (u64 bv off)
  (+ (u32 bv off)
     (arithmetic-shift (u32 bv (+ off 4)) 32)))

(define (section-field s key)
  (cadr (assq key (cdr s))))

(define source
  '(loko-source
    (text
     (%origin #x200000)
     (%mode 64)
     (%section text)
     (%label text)
     (ret))
    (data
     (%label data)
     (%u64 #x1234)
     (%label bss)
     (%section bss)
     (reserve 16)
     (%label bss-end))))

(define ctx
  (run-flow target-amd64 'loko (list (cons 'loko-source source))))
(define build (context-value ctx 'build))
(define symbols
  (cdr (assq 'symbols (context-value ctx 'bound-layout))))
(define image (write-elf build symbols))

(check-equal? (cadr (assq 'entry (cdr image))) #x200000)
(define bytes* (cadr (assq 'bytes (cdr image))))

(check-equal? (subbytes bytes* 0 4) #"\x7fELF")
(check-equal? (bytes-ref bytes* 4) 2)     ; ELFCLASS64
(check-equal? (bytes-ref bytes* 5) 1)     ; little-endian
(check-equal? (u64 bytes* 24) #x200000)   ; e_entry
(check-equal? (u64 bytes* 32) 64)         ; e_phoff
(check-equal? (u16 bytes* 56) 2)          ; e_phnum: PT_LOAD + GNU_STACK

;; PT_LOAD
(check-equal? (u32 bytes* 64) 1)
(check-equal? (u64 bytes* 72) 4096)       ; p_offset
(check-equal? (u64 bytes* 80) #x200000)   ; p_vaddr
(check-equal? (u64 bytes* 96) 9)          ; p_filesz: text + data
(check-equal? (u64 bytes* 104) 25)        ; p_memsz: text + data + bss
(check-equal? (u64 bytes* 112) 4096)      ; p_align

;; sections
(define sections (cdr (assq 'sections (cdr image))))
(define (find-section name)
  (for/first ([s (in-list sections)]
              #:when (equal? (section-field s 'name) name))
    s))
(define text-section (find-section ".text"))
(define data-section (find-section ".data"))
(define bss-section (find-section ".bss"))
(check-equal? (section-field text-section 'addr) #x200000)
(check-equal? (section-field text-section 'offset) 4096)
(check-equal? (section-field text-section 'size) 1)
(check-equal? (section-field data-section 'addr) #x200001)
(check-equal? (section-field data-section 'offset) 4097)
(check-equal? (section-field data-section 'size) 8)
(check-equal? (section-field bss-section 'addr) #x200009)
(check-equal? (section-field bss-section 'type) 'nobits)
(check-equal? (section-field bss-section 'size) 16)
(check-true (and (find-section ".symtab") #t))
(check-true (and (find-section ".strtab") #t))
(check-true (and (find-section ".shstrtab") #t))

(check-equal? (cadr (assq 'size (cdr image))) (bytes-length bytes*))

;; explicit image-plan: per-segment PT_LOADs, flags, section metadata, symbol size
(define plan-source
  '(loko-source
    (text
     (%origin #x200000)
     (%mode 64)
     (%section text)
     (%label text)
     (ret)
     (%elf
      (entry text)
      (load (name text) (flags r-x) (align 4096))
      (load (name data) (flags rw-) (align 4096))
      (load (name bss) (flags rw-) (align 4096))
      (section (segment text) (name .text) (type progbits)
               (flags (alloc exec)) (align 16))
      (section (segment data) (name .data) (type progbits)
               (flags (alloc write)) (align 8))
      (section (segment bss) (name .bss) (type nobits)
               (flags (alloc write)) (align 8))
      (symbol (name text) (size 1) (type func) (bind global))))
    (data
     (%label data)
     (%u64 #x1234)
     (%label bss)
     (%section bss)
     (reserve 16)
     (%label bss-end))))
(define plan-image
  (compile-image target-amd64 (list (cons 'loko-source plan-source))))
(define plan-bytes (cadr (assq 'bytes (cdr plan-image))))
(check-equal? (cadr (assq 'entry (cdr plan-image))) #x200000)
(check-equal? (u16 plan-bytes 56) 4)      ; text + data + bss + GNU_STACK
(check-equal? (u32 plan-bytes 68) #x5)    ; text: R|X
(check-equal? (u32 plan-bytes 124) #x6)   ; data: R|W
(check-equal? (u32 plan-bytes 180) #x6)   ; bss: R|W
(check-equal? (u32 plan-bytes 232) #x6474e551)
(define plan-sections (cdr (assq 'sections (cdr plan-image))))
(define (find-plan-section name)
  (for/first ([s (in-list plan-sections)]
              #:when (equal? (section-field s 'name) name))
    s))
(check-equal? (section-field (find-plan-section ".text") 'flags) #x6)
(check-equal? (section-field (find-plan-section ".data") 'flags) #x3)
(check-equal? (section-field (find-plan-section ".bss") 'type) 'nobits)
(define (symbol-field sym key)
  (cadr (assq key (cdr sym))))
(define text-symbol
  (for/first ([sym (in-list (cdr (assq 'symbols (cdr plan-image))))]
              #:when (equal? (symbol-field sym 'name) "text"))
    sym))
(check-equal? (symbol-field text-symbol 'size) 1)
(check-equal? (symbol-field text-symbol 'type) 'func)
(check-equal? (symbol-field text-symbol 'bind) 'global)

;; flow stage integration: compile-image uses the 'elf group
(define image2
  (compile-image target-amd64 (list (cons 'loko-source source))))
(define bytes2 (cadr (assq 'bytes (cdr image2))))
(check-equal? (subbytes bytes2 0 4) #"\x7fELF")
(check-equal? (cadr (assq 'entry (cdr image2))) #x200000)

(displayln "amd64 elf tests: ok")
