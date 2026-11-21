#lang racket
;;; test/data-test.rkt
;;;
;;; data 形状、尺寸、对齐、字节生成。

(require rackunit
         "../data/data.rkt")

(test-case "data shape"
  (check-true (data-form? '(data (d table) (value 8 1) (bytes 1 2 3))))
  (check-false (data-form? '(data () (value 8 1))))
  (check-false (data-form? '(data (d) (value 3 1))))
  (check-false (data-form? '(data (d) (bytes 256))))
  (check-false (data-form? '(data (d) (fill -1 0))))
  (check-false (data-form? '(data (d) (align 3))))
  (check-equal? (data-name '(data (d table) (align 8))) '(d table)))

(test-case "bytes / fill / value"
  (define form
    '(data (d)
       (bytes 1 2 3)
       (fill 4 255)
       (value 1 42)
       (value 2 #x1234)
       (value 4 #x12345678)
       (value 8 #x1122334455667788)))
  (check-equal? (data-size form) (+ 3 4 1 2 4 8))
  (check-equal? (data-bytes form)
                (append '(1 2 3)
                        '(255 255 255 255)
                        '(42)
                        '(#x34 #x12)
                        '(#x78 #x56 #x34 #x12)
                        '(#x88 #x77 #x66 #x55 #x44 #x33 #x22 #x11))))

(test-case "negative values use two's complement"
  (check-equal? (data-bytes '(data (d) (value 1 -1))) '(255))
  (check-equal? (data-bytes '(data (d) (value 2 -2))) '(254 255))
  (check-equal? (data-bytes '(data (d) (value 4 -1))) '(255 255 255 255)))

(test-case "align pads with zero bytes"
  (define form
    '(data (d)
       (bytes 1)
       (align 8)
       (bytes 2)
       (align 4)))
  (check-equal? (data-size form) 12)
  (check-equal? (data-bytes form)
                '(1 0 0 0 0 0 0 0 2 0 0 0))
  (check-equal? (data-align form) 8))

(test-case "no align means alignment 1"
  (check-equal? (data-align '(data (d) (bytes 1 2))) 1))

(test-case "value range is checked"
  (check-exn #rx"outside the 1-byte range"
             (lambda () (data-bytes '(data (d) (value 1 256)))))
  (check-exn #rx"outside the 1-byte range"
             (lambda () (data-bytes '(data (d) (value 1 -129)))))
  (check-equal? (data-bytes '(data (d) (value 1 255))) '(255))
  (check-equal? (data-bytes '(data (d) (value 1 -128))) '(128)))

(test-case "empty data is legal"
  (check-equal? (data-size '(data (d))) 0)
  (check-equal? (data-bytes '(data (d))) '())
  (check-equal? (data-align '(data (d))) 1))

(test-case "address values produce relocations"
  (define form
    '(data (d)
       (align 8)
       (value 8 (global (x)))
       (value 8 (+ (global (y)) 4))))
  (define l (layout-data form))
  (check-equal? (data-layout-size l) 16)
  (check-equal? (data-layout-bytes l) (make-list 16 0))
  (check-equal? (data-layout-relocations l)
                (list (data-relocation 0 8 '(x) 0)
                      (data-relocation 8 8 '(y) 4)))
  (check-exn #rx"address values"
             (lambda () (data-bytes form))))

(test-case "address value width must be 4 or 8"
  (check-false (data-form? '(data (d) (value 2 (global (x))))))
  (check-exn #rx"malformed data"
             (lambda () (data-size '(data (d) (value 2 (global (x))))))))

(test-case "data labels define offsets without bytes"
  (define form
    '(data (d)
       (bytes 1 2)
       (label (start) (also-start))
       (align 8)
       (label (end))
       (bytes 3)))
  (define l (layout-data form))
  (check-equal? (data-layout-size l) 9)
  (check-equal? (hash-ref (data-layout-labels l) '(start)) 2)
  (check-equal? (hash-ref (data-layout-labels l) '(also-start)) 2)
  (check-equal? (hash-ref (data-layout-labels l) '(end)) 8)
  (check-equal? (data-bytes form)
                '(1 2 0 0 0 0 0 0 3)))

(test-case "duplicate data label is rejected"
  (check-exn #rx"data label .* is defined twice"
             (lambda ()
               (layout-data '(data (d)
                              (label (x))
                              (bytes 1)
                              (label (x)))))))
