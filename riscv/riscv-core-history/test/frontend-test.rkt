#lang racket
;;; test/frontend-test.rkt
;;;
;;; 前端三件事的验收：
;;;   1. collect：模块表、定义表、raw label；
;;;   2. link：provide / require / prefix / rename / re-export / 循环；
;;;   3. rewrite：只把全局名换成完整链。

(require rackunit
         "../frontend/main.rkt"
         "../examples/module.rkt"
         "../examples/asm.rkt")

;; ---------------------------------------------------------------------------
;; 辅助
;; ---------------------------------------------------------------------------

(define (check-resolve source expected-program expected-exports)
  (define-values (program exports) (resolve-program source))
  (check-equal? program expected-program)
  (check-equal? exports expected-exports))

(define (check-resolve-files files expected-program expected-exports)
  (define-values (program exports) (resolve-files files))
  (check-equal? program expected-program)
  (check-equal? exports expected-exports))

(define (check-frontend-error rx source)
  (check-exn rx (lambda () (resolve-program source))))

;; ---------------------------------------------------------------------------
;; 1. 隐式根模块
;; ---------------------------------------------------------------------------

(define implicit-root-source
  '((func (main)
      (vregs (($ a) (b64)))
      (entry b0)
      (block b0
        (call ($ a) (global (helper)))
        (term (return ($ a)))))
    (func (helper)
      (vregs (($ r) (b64)))
      (entry b0)
      (block b0
        (term (return ($ r)))))))

(define implicit-root-expected
  '((func (main)
      (vregs (($ a) (b64)))
      (entry b0)
      (block b0
        (call ($ a) (global (helper)))
        (term (return ($ a)))))
    (func (helper)
      (vregs (($ r) (b64)))
      (entry b0)
      (block b0
        (term (return ($ r)))))))

(test-case "implicit root keeps names and exports all definitions"
  (check-resolve implicit-root-source
                 implicit-root-expected
                 '((helper) (main))))

;; ---------------------------------------------------------------------------
;; 2. 同一个 module 内的全局名
;; ---------------------------------------------------------------------------

(define module-local-source
  '((module (lib)
      (provide (f) (g))
      (func (f)
        (vregs (($ a) (b64)))
        (entry b0)
        (block b0
          (call ($ a) (global (g)))
          (term (return ($ a)))))
      (func (g)
        (vregs (($ r) (b64)))
        (entry b0)
        (block b0
          (term (return ($ r))))))))

(define module-local-expected
  '((func (lib f)
      (vregs (($ a) (b64)))
      (entry b0)
      (block b0
        (call ($ a) (global (lib g)))
        (term (return ($ a)))))
    (func (lib g)
      (vregs (($ r) (b64)))
      (entry b0)
      (block b0
        (term (return ($ r)))))))

(test-case "same-module references use the module scope"
  (check-resolve module-local-source
                 module-local-expected
                 '((lib f) (lib g))))

;; ---------------------------------------------------------------------------
;; 3. 跨模块 require
;; ---------------------------------------------------------------------------

(test-case "examples/module.rkt resolves exactly as documented"
  (check-resolve module-source
                 module-resolved
                 '((lib util f))))

;; ---------------------------------------------------------------------------
;; 4. prefix-in：前缀是链头，不做字符串拼接
;; ---------------------------------------------------------------------------

(define prefix-source
  '((module (lib base)
      (provide (f) (h))
      (func (f)
        (vregs (($ a) (b64)))
        (entry b0
          (block b0 (term (return ($ a))))))
      (func (h)
        (vregs (($ b) (b64)))
        (entry b0
          (block b0 (term (return ($ b)))))))
    (module (app)
      (require (prefix-in b (lib base)))
      (func (main)
        (vregs (($ r) (b64)))
        (entry b0
          (block b0
            (call ($ r) (global (b f)))
            (call ($ r) (global (b h)))
            (term (return ($ r)))))))))

(define prefix-expected
  '((func (lib base f)
      (vregs (($ a) (b64)))
      (entry b0
        (block b0 (term (return ($ a))))))
    (func (lib base h)
      (vregs (($ b) (b64)))
      (entry b0
        (block b0 (term (return ($ b))))))
    (func (app main)
      (vregs (($ r) (b64)))
      (entry b0
        (block b0
          (call ($ r) (global (lib base f)))
          (call ($ r) (global (lib base h)))
          (term (return ($ r))))))))

(test-case "prefix-in prepends a chain head"
  (check-resolve prefix-source
                 prefix-expected
                 '((lib base f) (lib base h))))

(test-case "prefix-in works on multi-element external chains"
  (check-resolve
   '((module (lib)
       (provide (a b))
       (func (a b)
         (entry b0
           (block b0 (term (return 0))))))
     (module (app)
       (require (prefix-in p (lib)))
       (func (main)
         (vregs (($ r) (b64)))
         (entry b0
           (block b0
             (call ($ r) (global (p a b)))
             (term (return ($ r))))))))
   '((func (lib a b)
       (entry b0
         (block b0 (term (return 0)))))
     (func (app main)
       (vregs (($ r) (b64)))
       (entry b0
         (block b0
           (call ($ r) (global (lib a b)))
           (term (return ($ r)))))))
   '((lib a b))))

;; ---------------------------------------------------------------------------
;; 5. rename-in：只改指定外部名，其它名字照常导入
;; ---------------------------------------------------------------------------

(define rename-in-source
  '((module (lib)
      (provide (f) (h))
      (func (f)
        (vregs (($ a) (b64)))
        (entry b0
          (block b0 (term (return ($ a))))))
      (func (h)
        (vregs (($ b) (b64)))
        (entry b0
          (block b0 (term (return ($ b)))))))
    (module (app)
      (require (rename-in (lib) (((f) (g)))))
      (func (main)
        (vregs (($ r) (b64)))
        (entry b0
          (block b0
            (call ($ r) (global (g)))
            (call ($ r) (global (h)))
            (term (return ($ r)))))))))

(define rename-in-expected
  '((func (lib f)
      (vregs (($ a) (b64)))
      (entry b0
        (block b0 (term (return ($ a))))))
    (func (lib h)
      (vregs (($ b) (b64)))
      (entry b0
        (block b0 (term (return ($ b))))))
    (func (app main)
      (vregs (($ r) (b64)))
      (entry b0
        (block b0
          (call ($ r) (global (lib f)))
          (call ($ r) (global (lib h)))
          (term (return ($ r))))))))

(test-case "rename-in renames selected imports"
  (check-resolve rename-in-source
                 rename-in-expected
                 '((lib f) (lib h))))

;; ---------------------------------------------------------------------------
;; 6. rename-out
;; ---------------------------------------------------------------------------

(define rename-out-source
  '((module (lib)
      (provide (rename-out (((f) (pub)))))
      (func (f)
        (vregs (($ a) (b64)))
        (entry b0
          (block b0 (term (return ($ a)))))))
    (module (app)
      (require (lib))
      (func (main)
        (vregs (($ r) (b64)))
        (entry b0
          (block b0
            (call ($ r) (global (pub)))
            (term (return ($ r)))))))))

(define rename-out-expected
  '((func (lib f)
      (vregs (($ a) (b64)))
      (entry b0
        (block b0 (term (return ($ a))))))
    (func (app main)
      (vregs (($ r) (b64)))
      (entry b0
        (block b0
          (call ($ r) (global (lib f)))
          (term (return ($ r))))))))

(test-case "rename-out changes only the external name"
  (check-resolve rename-out-source
                 rename-out-expected
                 '((lib f))))

;; ---------------------------------------------------------------------------
;; 7. provide *
;; ---------------------------------------------------------------------------

(define provide-all-source
  '((module (lib)
      (provide *)
      (func (f)
        (vregs (($ a) (b64)))
        (entry b0
          (block b0 (term (return ($ a))))))
      (data (table)
        (bytes 1 2)))))

(define provide-all-expected
  '((func (lib f)
      (vregs (($ a) (b64)))
      (entry b0
        (block b0 (term (return ($ a))))))
    (data (lib table)
      (bytes 1 2))))

(test-case "provide * exports all definitions in the module"
  (check-resolve provide-all-source
                 provide-all-expected
                 '((lib f) (lib table))))

;; ---------------------------------------------------------------------------
;; 8. raw label 也是全局名
;; ---------------------------------------------------------------------------

(define raw-label-source
  '((module (m)
      (provide *)
      (raw (start)
        (label (loop))
        (j (loop))))))

(define raw-label-expected
  '((raw (m start)
      (label (m loop))
      (j (m loop)))))

(test-case "raw labels are global names in the module scope"
  (check-resolve raw-label-source
                 raw-label-expected
                 '((m loop) (m start))))

(test-case "raw jal target follows native operand order"
  (check-resolve
   '((module (m)
       (provide (start) (end))
       (raw (start)
         (jal (native x0) (end)))
       (raw (end)
         (j (start)))))
   '((raw (m start)
       (jal (native x0) (m end)))
     (raw (m end)
       (j (m start))))
   '((m end) (m start))))

;; ---------------------------------------------------------------------------
;; 9. re-export
;; ---------------------------------------------------------------------------

(define re-export-source
  '((module (lib)
      (provide (f))
      (func (f)
        (vregs (($ a) (b64)))
        (entry b0
          (block b0 (term (return ($ a)))))))
    (module (facade)
      (require (lib))
      (provide (f)))
    (module (app)
      (require (facade))
      (func (main)
        (vregs (($ r) (b64)))
        (entry b0
          (block b0
            (call ($ r) (global (f)))
            (term (return ($ r)))))))))

(define re-export-expected
  '((func (lib f)
      (vregs (($ a) (b64)))
      (entry b0
        (block b0 (term (return ($ a))))))
    (func (app main)
      (vregs (($ r) (b64)))
      (entry b0
        (block b0
          (call ($ r) (global (lib f)))
          (term (return ($ r))))))))

(test-case "a module can re-export an imported name"
  (check-resolve re-export-source
                 re-export-expected
                 '((lib f))))

;; ---------------------------------------------------------------------------
;; 10. 循环 require
;; ---------------------------------------------------------------------------

(define cyclic-source
  '((module (a)
      (provide (fa))
      (require (b))
      (func (fa)
        (vregs (($ a) (b64)))
        (entry b0
          (block b0
            (call ($ a) (global (fb)))
            (term (return ($ a)))))))
    (module (b)
      (provide (fb))
      (require (a))
      (func (fb)
        (vregs (($ b) (b64)))
        (entry b0
          (block b0
            (call ($ b) (global (fa)))
            (term (return ($ b)))))))))

(define cyclic-expected
  '((func (a fa)
      (vregs (($ a) (b64)))
      (entry b0
        (block b0
          (call ($ a) (global (b fb)))
          (term (return ($ a))))))
    (func (b fb)
      (vregs (($ b) (b64)))
      (entry b0
        (block b0
          (call ($ b) (global (a fa)))
          (term (return ($ b))))))))

(test-case "cyclic require resolves to a fixpoint"
  (check-resolve cyclic-source
                 cyclic-expected
                 '((a fa) (b fb))))

;; ---------------------------------------------------------------------------
;; 11. 多文件
;; ---------------------------------------------------------------------------

(test-case "resolve-files keeps module scope across files"
  (check-resolve-files
   (list
    (list 'file 'lib.rkt
          '(module (lib)
             (provide (f))
             (func (f)
               (vregs (($ a) (b64)))
               (entry b0
                 (block b0 (term (return ($ a))))))))
    (list 'file 'app.rkt
          '(module (app)
             (require (lib))
             (func (main)
               (vregs (($ r) (b64)))
               (entry b0
                 (block b0
                   (call ($ r) (global (f)))
                   (term (return ($ r)))))))))
   '((func (lib f)
       (vregs (($ a) (b64)))
       (entry b0
         (block b0 (term (return ($ a))))))
     (func (app main)
       (vregs (($ r) (b64)))
       (entry b0
         (block b0
           (call ($ r) (global (lib f)))
           (term (return ($ r)))))))
   '((lib f))))

;; ---------------------------------------------------------------------------
;; 12. asm 是封闭块
;; ---------------------------------------------------------------------------

(test-case "inline asm is opaque to global-name rewriting"
  (check-resolve (list asm-add)
                 (list asm-add)
                 '((main))))

;; ---------------------------------------------------------------------------
;; 13. data body 由 data 层校验；前端解析 body 里的 (global chain)
;; ---------------------------------------------------------------------------

(test-case "data labels are global names and resolve in the body"
  (check-resolve
   '((module (m)
       (provide (d) (end))
       (data (d)
         (bytes 1)
         (label (end))
         (value 8 (global (end))))))
   '((data (m d)
       (bytes 1)
       (label (m end))
       (value 8 (global (m end)))))
   '((m d) (m end))))

(test-case "data body global references are resolved"
  (check-resolve
   '((module (m)
       (provide (d) (x))
       (data (x)
         (bytes 1))
       (data (d)
         (value 8 (global (x)))
         (value 8 (+ (global (x)) 4)))))
   '((data (m x)
       (bytes 1))
     (data (m d)
       (value 8 (global (m x)))
       (value 8 (+ (global (m x)) 4))))
   '((m d) (m x))))

;; ---------------------------------------------------------------------------
;; 14. 错误
;; ---------------------------------------------------------------------------

(test-case "undefined global reference"
  (check-frontend-error
   #rx"undefined global"
   '((func (main)
       (vregs (($ r) (b64)))
       (entry b0
         (block b0
           (call ($ r) (global (missing)))
           (term (return ($ r)))))))))

(test-case "require of an undefined module"
  (check-frontend-error
   #rx"requires undefined module"
   '((module (app)
       (require (missing))
       (func (main)
         (vregs (($ r) (b64)))
         (entry b0
           (block b0 (term (return ($ r))))))))))

(test-case "duplicate module across files"
  (check-exn #rx"defined twice"
             (lambda ()
               (resolve-files
                (list
                 (list 'file 'a.rkt '(module (lib) (provide (f)) (func (f) (entry b0) (block b0 (term (return 0))))))
                 (list 'file 'b.rkt '(module (lib) (provide (g)) (func (g) (entry b0) (block b0 (term (return 0)))))))))))

(test-case "duplicate global definition"
  (check-frontend-error
   #rx"defined twice"
   '((func (main) (entry b0) (block b0 (term (return 0))))
     (func (main) (entry b0) (block b0 (term (return 0)))))))

(test-case "two imports with the same local name"
  (check-frontend-error
   #rx"imports .* from two different globals"
   '((module (a)
       (provide (f))
       (func (f) (entry b0) (block b0 (term (return 0)))))
     (module (b)
       (provide (f))
       (func (f) (entry b0) (block b0 (term (return 0)))))
     (module (c)
       (require (a) (b))
       (func (main)
         (vregs (($ r) (b64)))
         (entry b0
           (block b0
             (call ($ r) (global (f)))
             (term (return ($ r))))))))))

(test-case "provide of an undefined name"
  (check-frontend-error
   #rx"provides .* not defined"
   '((module (m)
       (provide (missing))))))

(test-case "rename-in of a name that is not exported"
  (check-frontend-error
   #rx"renames .* not exported"
   '((module (lib)
       (provide (f))
       (func (f) (entry b0) (block b0 (term (return 0)))))
     (module (app)
       (require (rename-in (lib) (((missing) (x)))))))))

(test-case "cannot mix module and implicit root in one file"
  (check-frontend-error
   #rx"cannot mix"
   '((module (m)
       (provide (f))
       (func (f) (entry b0) (block b0 (term (return 0)))))
     (func (main) (entry b0) (block b0 (term (return 0)))))))

(test-case "nested modules are rejected"
  (check-frontend-error
   #rx"nested modules"
   '((module (a)
       (module (b))))))

(test-case "top-level require is rejected"
  (check-frontend-error
   #rx"top-level forms must be"
   '((require (lib)))))

(test-case "provide only accepts name chains"
  (check-frontend-error
   #rx"provide only accepts"
   '((module (m)
       (provide (($ a)))))))

(test-case "undefined raw label"
  (check-frontend-error
   #rx"undefined raw label"
   '((module (m)
       (raw (start)
         (j (missing)))))))

(test-case "raw label needs at least one chain"
  (check-frontend-error
   #rx"label needs"
   '((module (m)
       (raw (start)
         (label))))))

(test-case "malformed global reference"
  (check-frontend-error
   #rx"malformed global"
   '((func (main)
       (vregs (($ r) (b64)))
       (entry b0
         (block b0
           (call ($ r) (global))
           (term (return ($ r)))))))))

;; ---------------------------------------------------------------------------
;; 15. interface source -> externs
;; ---------------------------------------------------------------------------

(test-case "interface source produces externs without units"
  (define build
    '((file main
        (module (m)
          (provide (main))
          (require (lib))
          (func (main)
            (vregs (($ r) (b64)))
            (entry b0)
            (block b0
              (call ($ r) (global (f)))
              (term (return ($ r)))))))))
  (define iface
    '((file iface
        (module (lib)
          (provide (f) (d))
          (func (f)
            (vregs (($ r) (b64)))
            (entry b0)
            (block b0
              (const ($ r) 1)
              (term (return ($ r)))))
          (data (d)
            (bytes 1))))))
  (define-values (items exports externs)
    (resolve-files-with-interfaces build iface))
  (check-equal?
   items
   '((func (m main)
       (vregs (($ r) (b64)))
       (entry b0)
       (block b0
         (call ($ r) (global (lib f)))
         (term (return ($ r)))))))
  (check-equal? exports '((lib d) (lib f) (m main)))
  (check-equal?
   externs
   '((extern (lib d) (kind data))
     (extern (lib f) (kind func)))))
