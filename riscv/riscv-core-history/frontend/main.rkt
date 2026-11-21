#lang racket
;;; frontend/main.rkt
;;;
;;; 前端入口。collect -> link -> rewrite。
;;;
;;; resolve-files : (listof (file name form ...)) -> (values resolved-items exports)
;;; resolve-files-with-interfaces :
;;;   build files + interface files
;;;   -> (values resolved-items exports externs)
;;; resolve-program : (listof form) -> (values resolved-items exports)
;;;
;;; resolved-items 顶层只有 func / data / raw；
;;; exports 是完整全局链，已去重排序；
;;; externs 只是 (extern chain (kind kind))，不进入二进制构建。

(require "collect.rkt"
         "link.rkt"
         "program.rkt"
         "rewrite.rkt")

(provide resolve-files
         resolve-files-with-interfaces
         resolve-program)

(define (resolve-files files)
  (define prog (collect-program files))
  (define linked (link-program prog))
  (values (rewrite-program linked)
          (linked-all-exports linked)))

(define (resolve-files-with-interfaces files interface-files)
  (define prog (collect-program files #:interface-files interface-files))
  (define linked (link-program prog))
  (values (rewrite-program linked)
          (linked-all-exports linked)
          (external-symbols prog linked)))

(define (resolve-program forms)
  (resolve-files (list (list* 'file 'input forms))))

;; interface 定义且被导出的全局名才是 extern。
(define (external-symbols prog linked)
  (define defs (program-defs prog))
  (for/list ([name (in-list (linked-all-exports linked))]
             #:when (let ([def (hash-ref defs name #f)])
                      (and def (definition-interface? def))))
    (list 'extern name (list 'kind (definition-kind (hash-ref defs name))))))
