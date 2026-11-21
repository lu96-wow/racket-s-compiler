#lang racket
;;; test/raw-test.rkt
;;;
;;; raw 形状、label、控制转移、program layout、encode。

(require rackunit
         racket/list
         "../raw/raw.rkt"
         "../layout/program.rkt"
         "../encode/encode.rkt")

(define raw-form
  '(raw (start)
     (addi (native x10) (native x0) 1)
     (label (loop))
     (bne (loop) (native x10) (native x11))
     (j (done))
     (label (done))
     (jal (native x1) (start))))

(define (bytes->words bs)
  (for/list ([i (in-range 0 (bytes-length bs) 4)])
    (for/fold ([w 0]) ([j (in-range 4)])
      (bitwise-ior w
                   (arithmetic-shift (bytes-ref bs (+ i j)) (* 8 j))))))

(test-case "raw layout normalizes labels and control transfers"
  (define l (layout-raw raw-form))
  (check-equal? (raw-layout-name l) '(start))
  (check-equal? (raw-layout-size l) 16)
  (check-equal? (hash-ref (raw-layout-labels l) '(start)) 0)
  (check-equal? (hash-ref (raw-layout-labels l) '(loop)) 4)
  (check-equal? (hash-ref (raw-layout-labels l) '(done)) 12)
  (check-equal?
   (raw-layout-items l)
   '((label (start))
     (addi (native x10) (native x0) 1)
     (label (loop))
     (bne (loop) (native x10) (native x11))
     (jal (native x0) (done))
     (label (done))
     (jal (native x1) (start)))))

(test-case "raw branch target must be in the same unit"
  (check-exn #rx"not in the same raw unit"
             (lambda ()
               (layout-raw
                '(raw (start)
                   (j (missing)))))))

(test-case "duplicate raw label is rejected"
  (check-exn #rx"raw label .* is defined twice"
             (lambda ()
               (layout-raw
                '(raw (start)
                   (label (x))
                   (label (x)))))))

(test-case "raw name and body label conflict"
  (check-exn #rx"raw label .* is defined twice"
             (lambda ()
               (layout-raw
                '(raw (start)
                   (label (start)))))))

(test-case "raw operands are machine operands"
  (check-exn #rx"raw native operands"
             (lambda ()
               (layout-raw
                '(raw (start)
                   (addi (global (x)) (native x0) 1)))))
  (check-exn #rx"malformed raw jal"
             (lambda ()
               (layout-raw
                '(raw (start)
                   (jal 1 (start)))))))

(test-case "raw program layout and encode"
  (define data '(data (d)
                  (align 8)
                  (value 8 (global (done)))))
  (define program (layout-program (list raw-form data)))
  (define sections (program-layout-sections program))
  (check-equal? (map (lambda (s)
                       (cond
                         [(raw-section? s) (list 'raw (raw-section-base s) (raw-section-size s))]
                         [(data-section? s) (list 'data (data-section-base s) (data-section-size s))]))
                     sections)
                '((raw 0 16) (data 16 8)))
  (check-equal? (hash-ref (program-layout-bases program) '(done)) 12)
  (check-equal? (program-layout-size program) 24)

  (define enc (encode-program program))
  (check-equal? (map encoded-section-kind (encoded-program-sections enc))
                '(raw data))
  (check-equal? (encoded-program-size enc) 24)
  (check-equal? (bytes->words (subbytes (encoded-program-bytes enc) 0 16))
                (list #x00100513
                      #x00b51063
                      #x0040006f
                      #xff5ff0ef))
  ;; data 段从 16 开始，值是 (done) 的地址 12。
  (check-equal? (bytes->words (subbytes (encoded-program-bytes enc) 16 24))
                (list 12 0)))

(test-case "addr(global) can target a raw label"
  (define frame16
    '(frame (size 16) (header 16) (outgoing 0) (align 16) (slots)))
  (define func
    (list 'func '(main) frame16 '(scratch) '(entry b0)
          (list 'block 'b0
                (list 'addr '(native x5) '(global (done)))
                '(term (return)))))
  (define program (layout-program (list func raw-form)))
  (define function-section (car (program-layout-sections program)))
  ;; 函数 12B，raw 从 12 开始，(done) 在 raw 内偏移 12。
  (check-equal? (hash-ref (program-layout-bases program) '(done)) 24)
  (check-equal?
   (function-section-items function-section)
   '((label b0)
     (auipc (native x5) 0)
     (addi (native x5) (native x5) 24)
     (jalr (native x0) (native x1) 0))))

(test-case "raw label conflicts with function name"
  (define frame16
    '(frame (size 16) (header 16) (outgoing 0) (align 16) (slots)))
  (define func
    (list 'func '(main) frame16 '(scratch) '(entry b0) '(block b0 (term (return)))))
  (check-exn #rx"defined twice"
             (lambda ()
               (layout-program
                (list func
                      '(raw (start)
                         (label (main))))))))
