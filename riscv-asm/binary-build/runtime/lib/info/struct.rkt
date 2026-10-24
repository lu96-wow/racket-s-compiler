#lang racket/base

;; ============================================================
;; Runtime instruction metadata
;;
;; This module is copied verbatim into generated/lib/info/struct.rkt.
;;
;; instruction-info fields
;;   name             symbol, e.g. 'add
;;   extension        symbol, e.g. 'rv_i
;;   width            instruction width in bits (16 or 32)
;;   size             instruction width in bytes
;;   operands         rebuilt/logical operands, in API order
;;   raw-operands     raw operands, in API order
;;   fixed-fields     ((lo hi value) ...) exactly as emitted
;;   aliases          ((target source) ...) source alias relations
;;   origin           instruction-origin, provenance only
;;   raw-bindings     ((field-ref expr) ...) actual raw field bindings
;;   rebuilt-bindings ((field-ref expr) ...) actual rebuilt field bindings
;;   asm              display format for the rebuilt operands
;;
;; Provenance is deliberately NOT part of the encoding signature:
;; an import, a pseudo, and a standard definition can all produce the
;; same encoding and must still be deduplicated by the lookup layer.
;; ============================================================

(struct instruction-origin
  (kind                ; 'standard | 'import | 'pseudo
   source-extension    ; symbol or #f
   source-instruction) ; symbol or #f
  #:transparent)

(struct instruction-info
  (name
   extension
   width
   size
   operands
   raw-operands
   fixed-fields
   aliases
   origin
   raw-bindings
   rebuilt-bindings
   asm)
  #:transparent)

(provide instruction-origin
         instruction-origin?
         instruction-origin-kind
         instruction-origin-source-extension
         instruction-origin-source-instruction

         instruction-info
         instruction-info?
         instruction-info-name
         instruction-info-extension
         instruction-info-width
         instruction-info-size
         instruction-info-operands
         instruction-info-raw-operands
         instruction-info-fixed-fields
         instruction-info-aliases
         instruction-info-origin
         instruction-info-raw-bindings
         instruction-info-rebuilt-bindings
         instruction-info-asm)
