#lang racket
;;; amd64/compiler/encode/encode.rkt
;;;
;;; bound layout -> 每段字节。分支目标在这里换成相对偏移。
;;; 目前只支持已解析/常量内存 displacement。
;;;
;;; 两种段两条路径: code/data 逐条落字节; kind = hole 的段只有地址没有字节,
;;; 产物是 (size n) + (bytes #"")。洞里的内容不归本产物定义。

(require "../../amd64-asm/sexp.rkt"
         "../../amd64-asm/target.rkt"
         "../item.rkt"
         "../../amd64-asm/insn.rkt"
         (only-in "../item.rkt" pad-size bytes-content fill-size fill-byte)
         (only-in "../layout/forms.rkt"
                  layout-phase layout-segments layout-symbols
                  layout-requests layout-problems
                  layout-segment? layout-segment-name layout-segment-kind
                  layout-segment-start layout-segment-size layout-segment-items
                  offset? offset-position offset-item)
         (only-in "../bind-labels/forms.rkt"
                  symbol-entry? symbol-chain symbol-address)
         (only-in "../../amd64-help/branch.rkt"
                  control-transfer-name?))

(provide encode-layout)

;; 符号表: 链 -> 地址。原来是每个引用扫一遍全部符号(几十万条), 在大镜像上是
;; 二次的 —— pc-repl 有 22 万条符号, encode 会跑成几十分钟。
;; 同一个链出现多次时保留**第一个**(和原来的 for/first 一致)。
(define (symbols->table symbols)
  (for/fold ([h (make-hash)]) ([s (in-list symbols)])
    (cond
      [(not (symbol-entry? s)) h]
      [(hash-has-key? h (symbol-chain s)) h]
      [else (hash-set! h (symbol-chain s) (symbol-address s)) h])))

(define (resolve-symbol symbol-table chain)
  (hash-ref symbol-table (normalize-path chain)
            (lambda () (error 'encode "undefined symbol: ~e" chain))))

(define (resolve-address symbol-table expr here)
  (eval-address expr (lambda (chain) (resolve-symbol symbol-table chain)) here))

(define (value->bytes width expr symbol-table here)
  (list->bytes (integer->bytes width (resolve-address symbol-table expr here))))

(define (make-build-segment name kind start size bytes)
  (list 'segment
        (list 'name name)
        (list 'kind kind)
        (list 'start start)
        (list 'size size)
        (list 'bytes bytes)))

(define (resolve-mem m here size symbol-table)
  (define d (mem-disp m))
  (define resolved
    (cond
      [(exact-integer? d) d]
      [(eq? (mem-base m) 'rip)
       (- (resolve-address symbol-table d here) (+ here size))]
      [else (resolve-address symbol-table d here)]))
  (struct-copy mem m [disp resolved]))

(define (resolve-operand op here size symbol-table)
  (cond
    [(mem? op) (resolve-mem op here size symbol-table)]
    [(mem-form? op) (resolve-mem (parse-mem op) here size symbol-table)]
    ;; Prepared immediate wrapper whose payload is still symbolic.
    [(and (immediate-form op)
          (symbolic-immediate? (cadr op)))
     (list (immediate-form op) (resolve-address symbol-table (cadr op) here))]
    [(and (address-expr? op) (not (exact-integer? op)))
     (list 'imm32 (resolve-address symbol-table op here))]
    [else op]))

(define (encode-code target name operands here symbol-table)
  (cond
    [(eq? name 'prefix)
     (unless (and (= 2 (length operands)) (form? (cadr operands)))
       (error 'encode "bad prefix form: ~e" (cons name operands)))
     (define pname (car operands))
     (define inner (cadr operands))
     ;; The prefix byte shifts the inner instruction by one byte, so
     ;; RIP-relative operands inside it use here+1 and the inner size.
     (define inner-size (instruction-size target (car inner) (cdr inner)))
     (define prepared (choose-symbolic-immediate-forms (car inner) (cdr inner)))
     (define inner* (cons (car inner)
                          (map (lambda (op) (resolve-operand op (+ here 1) inner-size symbol-table))
                               prepared)))
     (encode-instruction target 'prefix (list pname inner*))]

    [(control-transfer-name? name)
     (let* ([target-operand (last operands)]
            [size (instruction-size target name operands)]
            [address (resolve-symbol symbol-table target-operand)]
            [offset (- address (+ here size))]
            [ops (append (drop-right operands 1) (list offset))])
       (encode-instruction target name ops))]

    [else
     (let* ([prepared (choose-symbolic-immediate-forms name operands)]
            [size (instruction-size target name operands)]
            [ops (map (lambda (op) (resolve-operand op here size symbol-table))
                      prepared)])
       (encode-instruction target name ops))]))

;; (offset k ...) is an assertion: by the time we reach this item the position
;; must be exactly k.  Both segment paths share it, so their errors cannot drift.
(define (check-offset! name at reached it)
  (unless (= at reached)
    (error 'encode "segment ~a offset mismatch: layout ~a, encode ~a (item ~e)"
           name at reached it)))

;; A hole segment has an address range but no file bytes; the segment's size is
;; kept, the bytes are empty.  What lives there is defined by the loader, the
;; program or the hardware -- not by this artifact, so encode does not
;; materialize anything and does not care who zeroes it.
;; Items can only be label / reserve (layout already turned align into reserve).
(define (encode-hole-segment seg)
  (unless (layout-segment? seg)
    (error 'encode "bad layout segment: ~e" seg))
  (define name (layout-segment-name seg))
  (define size (layout-segment-size seg))
  (define cursor 0)                     ; memory-only: there is no file cursor here
  (for ([entry (in-list (layout-segment-items seg))])
    (unless (offset? entry)
      (error 'encode "bad layout offset entry: ~e" entry))
    (define at (offset-position entry))
    (define it (offset-item entry))
    (check-offset! name at cursor it)
    (cond
      [(label-form? it) (void)]
      [(reserve-form? it) (set! cursor (+ cursor (reserve-size it)))]
      [else (error 'encode
                   "hole segment ~a got an item that writes bytes: ~e"
                   name it)]))
  (unless (= cursor size)
    (error 'encode "segment ~a size mismatch: layout says ~a, hole advances ~a"
           name size cursor))
  (make-build-segment name 'hole (layout-segment-start seg) size #""))

(define (encode-materialized-segment target seg symbol-table)
  (unless (layout-segment? seg)
    (error 'encode "bad layout segment: ~e" seg))
  (define name (layout-segment-name seg))
  (define kind (layout-segment-kind seg))
  (define start (layout-segment-start seg))
  (define size (layout-segment-size seg))
  (define entries (layout-segment-items seg))
  ;; 段大小在布局阶段就定死了, 所以直接写进一块预分配的字节串:
  ;; 之前是每个 item 一个 bytevector, 最后再 (apply bytes-append …) 一次,
  ;; 在大镜像上是几十万次分配 + 一次巨型 append。
  (let ([out (make-bytes size)]
        [cursor 0])
    (define (emit! bs)
      (bytes-copy! out cursor bs)
      (set! cursor (+ cursor (bytes-length bs))))
    (for ([entry (in-list entries)])
      (unless (offset? entry)
        (error 'encode "bad layout offset entry: ~e" entry))
      (define at (offset-position entry))
      (define it (offset-item entry))
      (define here (+ start at))
      (check-offset! name at cursor it)
      (cond
        [(label-form? it) (void)]
        [(pad-form? it) (emit! (list->bytes (padding-bytes target kind (pad-size it))))]
        [(bytes-form? it) (emit! (list->bytes (bytes-content it)))]
        [(fill-form? it) (emit! (make-bytes (fill-size it) (fill-byte it)))]
        [(reserve-form? it)
         (error 'encode "reserve is only valid in a hole segment: ~e" it)]
        [(value-form? it)
         (emit! (value->bytes (value-width it) (value-payload it) symbol-table here))]
        [else
         (define expect (instruction-size target (car it) (cdr it)))
         (define bs (encode-code target (car it) (cdr it) here symbol-table))
         (unless (= expect (bytes-length bs))
           (error 'encode
                  "item size mismatch at ~a/~a: layout ~a, encode ~a: ~e"
                  name at expect (bytes-length bs) it))
         (emit! bs)]))
    (unless (= cursor size)
      (error 'encode "segment ~a size mismatch: layout says ~a, encoder wrote ~a"
             name size cursor))
    (make-build-segment name kind start size out)))

;; Two kinds of segments, two paths: materialized ones emit bytes item by item,
;; hole ones only advance the position.  "Where the hole starts" is not a
;; runtime state -- the segment declares it.
(define (encode-segment target seg symbol-table)
  (unless (layout-segment? seg)
    (error 'encode "bad layout segment: ~e" seg))
  (if (eq? (layout-segment-kind seg) 'hole)
      (encode-hole-segment seg)
      (encode-materialized-segment target seg symbol-table)))
(define (encode-layout target layout)
  (unless (eq? (layout-phase layout) 'bound)
    (error 'encode-layout "expected bound-layout, got phase ~e"
           (layout-phase layout)))
  (define requests (layout-requests layout))
  (unless (null? requests)
    (error 'encode-layout "layout still has requests: ~e" requests))
  (define problems (layout-problems layout))
  (unless (null? problems)
    (error 'encode-layout "layout still has problems: ~e" problems))
  (define symbol-table (symbols->table (layout-symbols layout)))
  (define segments (layout-segments layout))
  (cons 'build
        (for/list ([seg (in-list segments)])
          (encode-segment target seg symbol-table))))
