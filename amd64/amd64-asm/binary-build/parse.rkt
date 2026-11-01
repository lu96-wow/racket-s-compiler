#lang racket/base

;; ============================================================
;; Parser for NASM's preprocessed x86/insns.pre.dat.
;;
;; The preprocessed file has already expanded $macros.  Every functional
;; line still has exactly four fields:
;;
;;   MNEMONIC  operands  [operand-code: byte-code]  flags
;;
;; This module only tokenizes those fields.  It deliberately does not
;; decide which forms the amd64 backend supports; resolve.rkt does that.
;; ============================================================

(require racket/list
         racket/match
         racket/string
         racket/path
         "../registers.rkt"
         "model.rkt")

(define line-rx
  #px"^\\s*([^\\s;]+)\\s+([^\\s;]+)\\s+\\[([^\\]]*)\\]\\s+([^\\s;]+)\\s*(?:;.*)?$")

(define (comment-or-blank? line)
  (define s (string-trim line))
  (or (string=? s "")
      (string-prefix? s ";")
      (string-prefix? s "#")))

(define (hex-byte? s)
  (and (regexp-match? #px"^[0-9a-fA-F]{2}$" s)
       (string->number s 16)))

(define (hex-bytes s)
  (and (even? (string-length s))
       (regexp-match? #px"^[0-9a-fA-F]+$" s)
       (for/list ([i (in-range 0 (string-length s) 2)])
         (string->number (substring s i (+ i 2)) 16))))

;; ------------------------------------------------------------
;; operands
;; ------------------------------------------------------------

(define fixed-gpr-rx #rx"^reg_([a-z][a-z0-9]*)$")

(define (fixed-gpr text)
  (define m (regexp-match fixed-gpr-rx text))
  (and m
       (let* ([name (list-ref m 1)]
              [r (lookup-register (string->symbol name) #f)])
         (and r
              (gpr-register? r)
              (operand-def text 'gpr-fixed (reg-width r) (reg-name r))))))

(define (parse-operand text)
  ;; NASM size/relocation qualifiers after "|" do not change the register
  ;; class.  APX/EVEX optional markers are unsupported by this backend.
  (define base (car (string-split text #rx"\\|" #:trim? #t)))
  (cond
    [(or (string=? base "void") (string=? base "ignore")) #f]
    [(string=? base "unity") (operand-def text 'unity #f #f)]
    [(regexp-match? #px"[:*?]" base) #f]
    [(fixed-gpr base)]
    [(regexp-match #px"^(reg)(8|16|32|64)$" base)
     => (lambda (m)
          (operand-def text 'gpr
                       (string->number (list-ref m 2)) #f))]
    [(regexp-match #px"^(rm)(8|16|32|64)$" base)
     => (lambda (m)
          (operand-def text 'rm
                       (string->number (list-ref m 2)) #f))]
    [(string=? base "rm_sel")
     (operand-def text 'rm 16 #f)]
    [(regexp-match #px"^mem(8|16|32|64|128)?$" base)
     => (lambda (m)
          (operand-def text 'mem
                       (and (list-ref m 1)
                            (string->number (list-ref m 1)))
                       #f))]
    [(regexp-match #px"^imm(8|16|32|64)?$" base)
     => (lambda (m)
          (operand-def text 'imm
                       (and (list-ref m 1)
                            (string->number (list-ref m 1)))
                       #f))]
    [(regexp-match #px"^(sbyteword16|sbytedword32|sbytedword64)$" base)
     (operand-def text 'imm 8 #f)]
    [(regexp-match #px"^(sdword64|udword64)$" base)
     (operand-def text 'imm 32 #f)]
    [(string=? base "xmmreg")
     (operand-def text 'xmm 128 #f)]
    [(regexp-match #px"^xmmrm(16|32|64|128)?$" base)
     => (lambda (m)
          (operand-def text 'xmm-rm
                       (and (list-ref m 1)
                            (string->number (list-ref m 1)))
                       #f))]
    [(regexp-match #px"^rel(8|16|32)?$" base)
     (operand-def text 'rel #f #f)]
    [else #f]))

(define (parse-operands text)
  (cond
    [(or (string=? text "void") (string=? text "ignore"))
     (values '() #f)]
    [else
     (define parts (string-split text ","))
     (define parsed (map parse-operand parts))
     (if (andmap (lambda (x) (and x #t)) parsed)
         (values parsed #f)
         (values '() (format "unsupported operand: ~a"
                              (for/first ([p (in-list parsed)]
                                          [text (in-list parts)]
                                          #:unless p)
                                text))))]))

;; ------------------------------------------------------------
;; encoding
;; ------------------------------------------------------------

(define immediate-tokens
  (hash "ib"      '(ib 1 any)
        "ib,u"    '(ib 1 uint8)
        "ib,s"    '(ib 1 int8)
        "iw"      '(iw 2 any16)
        "id"      '(id 4 any32)
        "id,s"    '(id 4 int32)
        "id,u"    '(id 4 uint32)
        "iq"      '(iq 8 any64)
        "rel8"    '(rel8 1 any)
        "rel16"   '(rel16 2 any)
        "rel32"   '(rel32 4 any)
        "rel"     '(rel 4 any)))

(define size-tokens
  (hash "o8" 'o8 "o16" 'o16 "o32" 'o32 "o64" 'o64
        "osz" 'osz "osm" 'osm "odf" 'odf))

(define prefix-bytes
  (hash "66" #x66 "f2" #xf2 "f3" #xf3 "9b" #x9b))

(define ignored-tokens
  '("np" "nof3" "norep" "norexw" "norexb" "norexx" "norexr"
    "nohi" "!osp" "!asp" "optw" "optd" "hle" "hlexr" "hlenl"
    "adf" "m0" "wait"))

(define unsupported-token?
  (lambda (t)
    (or (string-prefix? t "vex") (string-prefix? t "evex")
        (string-prefix? t "xop") (string-prefix? t "rex2")
        (string-prefix? t "t1s")
        (member t '("/is4" "/3r0" "iwdq" "seg" "jlen" "jmp8" "jcc8"
                    "a16" "a32" "67" "ibn"))
        ;; aliases such as c8+r and 70+c are accepted below when they
        ;; contain "+r"; "+c" needs the condition-code pseudo mnemonic.
        (and (string-contains? t "+") (not (string-suffix? t "+r"))))))

(define (role-index roles role)
  (for/first ([ch (in-string roles)]
              [i (in-naturals)]
              #:when (char=? ch role))
    i))

(define (parse-encoding encoding-text)
  (define colon
    (let ([m (regexp-match-positions #rx":" encoding-text)])
      (and m (caar m))))
  (define roles (if colon (substring encoding-text 0 colon) ""))
  (define body (if colon
                   (substring encoding-text (add1 colon))
                   encoding-text))
  (define tokens (filter (lambda (s) (not (string=? s "")))
                         (string-split body)))
  (define prefixes '())
  (define opcode '())
  (define plus-r #f)
  (define modrm-token #f)
  (define imm '())
  (define size-mode #f)
  (define nw? #f)
  (define force-rex-w? #f)
  (define rex-b? #f)
  (define rex-x? #f)
  (define rex-r? #f)
  (define wait? #f)
  (define problem #f)

  (define (bad! reason)
    (unless problem (set! problem reason)))

  (for ([token (in-list tokens)])
    (cond
      [(hex-bytes token)
       => (lambda (bs)
            (cond
              [(hash-ref prefix-bytes token #f)
               (set! prefixes (append prefixes (list (hash-ref prefix-bytes token))))]
              [else (set! opcode (append opcode bs))]))]
      [(regexp-match #px"^([0-9a-fA-F]+)\\+r$" token)
       => (lambda (m)
            (define base (hex-bytes (list-ref m 1)))
            (if base
                (begin
                  (set! opcode (append opcode base))
                  (set! plus-r (or (role-index roles #\r) 0)))
                (bad! (format "bad +r token: ~a" token))))]
      [(string=? token "/r")
       (define r (role-index roles #\r))
       (define m (role-index roles #\m))
       (if (and r m)
           (set! modrm-token (list 'rr m r))
           (bad! "missing r/m operand role for /r"))]
      [(regexp-match #px"^/([0-7])$" token)
       => (lambda (m)
            (define d (string->number (list-ref m 1)))
            (define rm (role-index roles #\m))
            (if rm
                (set! modrm-token (list 'digit d rm))
                (bad! "missing memory/register operand role for /digit")))]
      [(hash-ref immediate-tokens token #f)
       => (lambda (spec)
            (define i (or (role-index roles #\i)
                          (role-index roles #\j)))
            (if i
                (set! imm (append imm (list (append spec (list i)))))
                (bad! (format "immediate token without operand: ~a" token))))]
      [(hash-ref size-tokens token #f)
       => (lambda (s) (set! size-mode s))]
      [(string=? token "nw") (set! nw? #t)]
      [(string=? token "o64nw") (set! nw? #t) (set! size-mode 'o64)]
      [(string=? token "rex.w") (set! force-rex-w? #t)]
      [(string=? token "rex.b") (set! rex-b? #t)]
      [(string=? token "rex.x") (set! rex-x? #t)]
      [(string=? token "rex.r") (set! rex-r? #t)]
      [(string=? token "wait") (set! wait? #t)]
      [(string=? token "f3i")
       (set! prefixes (append prefixes (list #xf3)))]
      [(member token ignored-tokens) (void)]
      [(member token '("asm" "repe")) (void)]
      [(unsupported-token? token)
       (bad! (format "unsupported encoding token: ~a" token))]
      [else
       (bad! (format "unknown encoding token: ~a" token))]))

  (if problem
      (values #f problem)
      (values (encoding-def prefixes opcode plus-r
                            (and modrm-token
                                 (if (eq? (car modrm-token) 'rr)
                                     (cadr modrm-token)
                                     (caddr modrm-token)))
                            (and modrm-token
                                 (if (eq? (car modrm-token) 'rr)
                                     (list 'r (caddr modrm-token))
                                     (list 'digit (cadr modrm-token))))
                            imm size-mode nw? force-rex-w?
                            rex-b? rex-x? rex-r? wait?)
              #f)))

;; ------------------------------------------------------------
;; one line / one file
;; ------------------------------------------------------------

(define (parse-line line path line-number)
  (cond
    [(comment-or-blank? line) (values #f #f)]
    [else
     (define m (regexp-match line-rx line))
     (cond
       [(not m) (values #f "not a four-field preprocessed NASM line")]
       [else
        (define mnemonic (string-downcase (list-ref m 1)))
        (define operands-text (list-ref m 2))
        (define encoding-text (list-ref m 3))
        (define flags (map string->symbol
                           (filter (lambda (s) (not (string=? s "")))
                                   (string-split (list-ref m 4) #rx"[,\\s]+"))))
        (define-values (operands operand-problem)
          (parse-operands operands-text))
        (cond
          [operand-problem (values #f operand-problem)]
          [else
           (define-values (encoding encoding-problem)
             (parse-encoding encoding-text))
           (cond
             [encoding-problem (values #f encoding-problem)]
             [else
              (values (raw-line (string->symbol mnemonic)
                                operands encoding flags
                                path line-number)
                      #f)])])])]))

(define (parse-source-file path)
  (define parsed
    (with-input-from-file path
      (lambda ()
        (for/list ([line (in-lines)]
                   [n (in-naturals 1)])
          (let-values ([(raw problem) (parse-line line path n)])
            (cons raw problem))))))
  (values (for/list ([p (in-list parsed)] #:when (car p)) (car p))
          (for/list ([p (in-list parsed)] #:unless (car p)) (cdr p))))

(provide parse-line
         parse-source-file
         parse-operand
         parse-encoding
         comment-or-blank?)
