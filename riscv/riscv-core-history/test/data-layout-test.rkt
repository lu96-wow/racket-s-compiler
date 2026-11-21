#lang racket
;;; test/data-layout-test.rkt
;;;
;;; data 段放置、段间 padding、addr(global) 解析、data 编码。

(require rackunit
         racket/list
         "../ir/cfg.rkt"
         "../layout/plan.rkt"
         "../layout/relax.rkt"
         "../layout/program.rkt"
         "../encode/encode.rkt")

(define frame16
  '(frame
     (size 16)
     (header 16)
     (outgoing 0)
     (align 16)
     (slots)))

(define (function-with-addr name target)
  (list 'func name frame16 '(scratch) '(entry b0)
        (list 'block 'b0
              (list 'addr '(native x5) (list 'global target))
              '(term (return)))))

(define data-form
  '(data (d table)
     (align 8)
     (value 8 7)
     (bytes 1 2 3)
     (align 8)
     (value 8 9)))

(test-case "addr(global) is resolved to auipc + addi after data placement"
  (define program
    (layout-program (list (function-with-addr '(main) '(d table))
                          data-form)))
  (define function-section (car (program-layout-sections program)))
  (define data-section (cadr (program-layout-sections program)))

  ;; function: label + 8B addr-global + 4B return = 12；data 起点对齐到 16。
  (check-equal? (function-section-size function-section) 12)
  (check-equal? (data-section-base data-section) 16)
  (check-equal? (data-section-size data-section) 24)
  (check-equal? (data-section-align data-section) 8)
  (check-equal? (program-layout-size program) 40)
  (check-equal? (hash-ref (program-layout-bases program) '(d table)) 16)

  (check-equal?
   (function-section-items function-section)
   '((label b0)
     (auipc (native x5) 0)
     (addi (native x5) (native x5) 16)
     (jalr (native x0) (native x1) 0))))

(test-case "data bytes are encoded after code padding"
  (define program
    (layout-program (list (function-with-addr '(main) '(d table))
                          data-form)))
  (define enc (encode-program program))
  (check-equal? (encoded-program-size enc) 40)
  (check-equal? (map encoded-section-kind (encoded-program-sections enc))
                '(code data))
  (check-equal? (map encoded-section-base (encoded-program-sections enc))
                '(0 16))

  (define bs (encoded-program-bytes enc))
  ;; 函数 12B，随后是 4B 段间 padding，然后 data 段 24B。
  (check-equal? (for/list ([i (in-range 12 16)]) (bytes-ref bs i))
                '(0 0 0 0))
  (check-equal?
   (for/list ([i (in-range 16 40)]) (bytes-ref bs i))
   (append '(7 0 0 0 0 0 0 0)
           '(1 2 3)
           '(0 0 0 0 0)
           '(9 0 0 0 0 0 0 0))))

(test-case "multiple data sections keep their own alignment"
  (define data-a '(data (d a) (align 16) (bytes 1 2)))
  (define data-b '(data (d b) (align 4) (bytes 3)))
  (define func (function-with-addr '(main) '(d b)))
  (define program (layout-program (list func data-a data-b)))
  (define sections (program-layout-sections program))
  (check-equal? (map (lambda (s)
                       (cond
                         [(function-section? s) (list 'code (function-section-base s))]
                         [(data-section? s) (list 'data (data-section-base s))]))
                     sections)
                '((code 0) (data 16) (data 20)))
  (check-equal? (program-layout-size program) 21))

(test-case "undefined addr target is rejected"
  (check-exn #rx"addr refers to undefined global"
             (lambda ()
               (layout-program
                (list (function-with-addr '(main) '(missing)))))))

(test-case "data name conflicts with function name"
  (check-exn #rx"defined twice"
             (lambda ()
               (layout-program
                (list (function-with-addr '(main) '(d))
                      '(data (main) (bytes 1)))))))

(test-case "encode-layout rejects unresolved addr-global"
  (define func (function-with-addr '(main) '(d table)))
  (define cfg (build-cfg func))
  (define plan (plan-layout cfg))
  (define layout (layout-func func plan))
  (check-exn #rx"addr-global requires program layout"
             (lambda () (encode-layout layout))))

(define (plain-function name)
  (list 'func name frame16 '(scratch) '(entry b0)
        '(block b0 (term (return)))))

(define (bytes-ref-word bs offset width)
  (for/fold ([w 0]) ([i (in-range width)])
    (bitwise-ior w
                 (arithmetic-shift (bytes-ref bs (+ offset i)) (* 8 i)))))

(test-case "data address values are relocated after placement"
  (define data-d '(data (d) (align 8) (value 8 (global (main)))))
  (define data-e '(data (e) (align 8) (value 8 (+ (global (d)) 4))))
  (define program
    (layout-program (list (plain-function '(main)) data-d data-e)))
  (check-equal? (program-layout-size program) 24)
  (check-equal? (hash-ref (program-layout-bases program) '(d)) 8)
  (check-equal? (hash-ref (program-layout-bases program) '(e)) 16)
  (check-equal? (program-layout-origin program) 0)

  (define enc (encode-program program))
  (define bs (encoded-program-bytes enc))
  (check-equal? (bytes-ref-word bs 8 8) 0)   ; main 在 origin 0
  (check-equal? (bytes-ref-word bs 16 8) 12) ; d 在 8，addend 4
  )

(test-case "data address values use program origin"
  (define data-d '(data (d) (align 8) (value 8 (global (main)))))
  (define data-e '(data (e) (align 8) (value 8 (+ (global (d)) 4))))
  (define program
    (layout-program (list (plain-function '(main)) data-d data-e)
                    #:origin #x1000))
  (check-equal? (program-layout-origin program) #x1000)
  (define bs (encoded-program-bytes (encode-program program)))
  (check-equal? (bytes-ref-word bs 8 8) #x1000)
  (check-equal? (bytes-ref-word bs 16 8) #x100C))

(test-case "data address value target must exist"
  (check-exn #rx"data value refers to undefined global"
             (lambda ()
               (layout-program
                (list (plain-function '(main))
                      '(data (d) (value 8 (global (missing)))))))))

(test-case "data address value must fit its width"
  (check-exn #rx"does not fit in 4 bytes"
             (lambda ()
               (layout-program
                (list (plain-function '(main))
                      '(data (d) (value 4 (global (main)))))
                #:origin #x100000000))))

(test-case "data labels participate in address values"
  (define data-d
    '(data (d)
       (align 8)
       (label (end))
       (value 8 (global (end)))))
  (define program
    (layout-program (list (plain-function '(main)) data-d)))
  (check-equal? (hash-ref (program-layout-bases program) '(end)) 8)
  (define bs (encoded-program-bytes (encode-program program)))
  (check-equal? (bytes-ref-word bs 8 8) 8))

(test-case "addr(global) can target a data label"
  (define program
    (layout-program
     (list (function-with-addr '(main) '(end))
           '(data (d)
              (align 8)
              (label (end))
              (bytes 1)))))
  (define function-section (car (program-layout-sections program)))
  (check-equal? (hash-ref (program-layout-bases program) '(end)) 16)
  (check-equal?
   (function-section-items function-section)
   '((label b0)
     (auipc (native x5) 0)
     (addi (native x5) (native x5) 16)
     (jalr (native x0) (native x1) 0))))

(test-case "data label conflicts with a function name"
  (check-exn #rx"defined twice"
             (lambda ()
               (layout-program
                (list (plain-function '(main))
                      '(data (d) (label (main))))))))

(test-case "far global address falls back to absolute lui + addi"
  (check-equal?
   (addr-global-items '(native x5) 0 #x100000000 0 64)
   '((lui (native x5) 0)
     (addi (native x5) (native x5) 0)))
  (check-equal?
   (addr-global-items '(native x5) #x1234 #x100000000 #x1000 64)
   '((lui (native x5) 2)
     (addi (native x5) (native x5) 564))))

(test-case "far global address outside absolute range is rejected"
  (check-exn #rx"addr far form cannot encode absolute"
             (lambda ()
               (addr-global-items '(native x5)
                                  #x9000000000000000
                                  #x100000000
                                  0
                                  64))))
