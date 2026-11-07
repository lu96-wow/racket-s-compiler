#lang racket/base

;; ============================================================
;; la：加载地址
;;
;; 基础形式：
;;   delta 已知 -> auipc + addi
;;   delta 未知 -> 占位 auipc/addi，留 relocation
;;
;; load-pcrel / load-pcrel-size 在已知 delta 时自动选择近/远形式。
;;
;; 绝对地址直接复用 expand-li。
;; GOT / 平台基址 / 栈帧 分别提供独立入口。
;; ============================================================

(require "ranges.rkt"
         "registers.rkt"
         "li.rkt"
         "scratch.rkt")

;; ------------------------------------------------------------
;; PC-relative
;; ------------------------------------------------------------

;; (la-pcrel rd #:delta delta)
;;
;; delta = target - pc
;; pc    = auipc 指令地址
(define (la-pcrel rd
                  #:delta [delta #f]
                  #:word-size [word-size 'rv64])
  (cond
    [delta
     (unless (fits-auipc-pair? delta word-size)
       (error 'la-pcrel
              "PC-relative delta ~a cannot be encoded by auipc+addi"
              delta))
     (define-values (hi lo) (split-hi-lo delta))
     (list (list 'auipc rd hi)
           (list 'addi rd rd lo))]
    [else
     ;; 外部/未解析符号的占位形式。
     ;; R_RISCV_PCREL_HI20 / R_RISCV_PCREL_LO12_I 由 object 层生成。
     (list (list 'auipc rd 0)
           (list 'addi rd rd 0))]))

;; ------------------------------------------------------------
;; 自动 PC-relative 加载
;; ------------------------------------------------------------

(define (take-load-pcrel-scratch who rd scratch)
  ;; far 形式只要一个 scratch: 存在、非零、且不等于 rd。
  ;; load-pcrel 和 load-pcrel-size 共用这一条, 免得两条路径的“合法输入”再分叉。
  (define temp (car (take-scratch! who (scratch-list scratch) 1)))
  (check-not-zero! who temp)
  (when (same-register? temp rd)
    (error who "scratch register ~a must differ from rd" temp))
  temp)

;; delta = target - address(AUIPC)
;; AUIPC 始终是展开结果的第一条指令，因此 delta 相对于展开起点。
;;
;; 已知 delta 时自动选择：
;;   AUIPC + ADDI
;;   或 RV64 的
;;     auipc rd, 0
;;     li    temp, delta
;;     add   rd, rd, temp
;;
;; 参数顺序跟底层 opcode 一致: auipc rd, imm —— rd 在前。
(define (load-pcrel rd delta
                    #:word-size [word-size 'rv64]
                    #:scratch [scratch #f])
  (cond
    [(fits-auipc-pair? delta word-size)
     (la-pcrel rd #:delta delta #:word-size word-size)]
    [(eq? word-size 'rv64)
     (load-pcrel-far rd delta #:word-size word-size #:scratch scratch)]
    [else
     (error 'load-pcrel
            "PC-relative delta ~a cannot be encoded for ~a"
            delta word-size)]))

;; **强制**远形式：不管 delta 有多大, 都走
;;     auipc rd, 0
;;     li    temp, delta
;;     add   rd, rd, temp
;;
;; 为什么要“强制”：relax 把 la 升成远形式之后, 尺寸必须**不再变**。如果这里
;; 又按距离自动挑近形式, 一旦 delta 缩小, 展开会变成 8 字节, 而 layout 记的是
;; 远形式的固定尺寸 —— 两边对不上。所以远形式就是远形式。
;;
;; AUIPC 必须是第一条(delta 的基准就是它), 和 load-pcrel 的近形式同构。
(define (load-pcrel-far rd delta
                        #:word-size [word-size 'rv64]
                        #:scratch [scratch #f])
  (unless (eq? word-size 'rv64)
    (error 'load-pcrel-far "RV32 没有远 PC 相对形式: ~a" delta))
  (define temp (take-load-pcrel-scratch 'load-pcrel-far rd scratch))
  (append (list (list 'auipc rd 0))
          (li temp delta #:word-size 'rv64)
          (list (list 'add rd rd temp))))

;; 和 load-pcrel-far 同参数, 只返回实际字节数(不含上层为了固定尺寸补的 nop)。
(define (load-pcrel-far-size rd delta
                             #:word-size [word-size 'rv64]
                             #:scratch [scratch #f])
  (define temp (take-load-pcrel-scratch 'load-pcrel-far-size rd scratch))
  (+ (li-size temp delta #:word-size word-size) 8))

;; 和 load-pcrel 同一套选择规则、同一套 scratch 校验，只返回字节数。
(define (load-pcrel-size rd delta
                         #:word-size [word-size 'rv64]
                         #:scratch [scratch #f])
  (cond
    [(fits-auipc-pair? delta word-size)
     8]
    [(eq? word-size 'rv64)
     (define temp (take-load-pcrel-scratch 'load-pcrel-size rd scratch))
     (+ (li-size temp delta #:word-size 'rv64) 8)]
    [else
     (error 'load-pcrel-size
            "PC-relative delta ~a cannot be encoded for ~a"
            delta word-size)]))

;; ------------------------------------------------------------
;; 绝对地址
;; ------------------------------------------------------------

;; 绝对地址和 li 共享所有范围分派。
(define (la-abs rd address
                #:word-size [word-size 'rv64]
                #:scratch [scratch #f])
  (expand-li rd address
             #:word-size word-size
             #:scratch scratch))

;; ------------------------------------------------------------
;; GOT
;; ------------------------------------------------------------

;; PIC 下加载 GOT 中的地址。
;; 这是占位形式，具体 relocation 由 object/linker 层处理。
(define (la-got rd #:word-size [word-size 'rv64])
  (define load (case word-size
                 [(rv32) 'lw]
                 [(rv64) 'ld]
                 [else (error 'la-got "unknown word size: ~a" word-size)]))
  (list (list 'auipc rd 0)
        (list load rd rd 0)))

;; ------------------------------------------------------------
;; 平台基址相对 (la-gp)
;; ------------------------------------------------------------

;; 这一项是平台约定: x3 的用途由 ABI/target 定，不是 ISA 规定。
;; 用哪个寄存器由前端/IR 给，后端只知道"这是个 rs1 + s12" —— 参数顺序照 addi rd, rs1, imm。
(define (la-gp rd base offset)
  (unless (fits-s12? offset)
    (error 'la-gp "gp-relative offset ~a is outside signed 12-bit range" offset))
  (list (list 'addi rd base offset)))

;; ------------------------------------------------------------
;; 栈帧相对
;; ------------------------------------------------------------

;; offset 在 12 位范围内：
;;   addi rd, base, offset
;;
;; 超出范围：
;;   li tmp, offset
;;   add rd, base, tmp
;;
;; 参数顺序跟底层 opcode 一致: addi rd, rs1, imm / add rd, rs1, rs2 —— rd、base 在前。
(define (la-frame-scratch who rd base scratch)
  (define tmp (car (take-scratch! who (scratch-list scratch) 1)))
  (check-not-zero! who tmp)
  (when (or (same-register? tmp rd) (same-register? tmp base))
    (error who
           "scratch register ~a must differ from rd and base"
           tmp))
  tmp)

(define (la-frame rd base offset
                 #:scratch [scratch #f]
                 #:word-size [word-size 'rv64])
  (cond
    [(fits-s12? offset)
     (list (list 'addi rd base offset))]
    [else
     (define tmp (la-frame-scratch 'la-frame rd base scratch))
     (append (expand-li tmp offset #:word-size word-size)
             (list (list 'add rd base tmp)))]))

;; 和 la-frame 同一套参数、同一套校验，只返回字节数。
;; 小 offset 4B；大 offset = li-size(offset) + 4B（最坏 32 + 4 = 36B）。
(define (la-frame-size rd base offset
                      #:scratch [scratch #f]
                      #:word-size [word-size 'rv64])
  (cond
    [(fits-s12? offset)
     4]
    [else
     (define tmp (la-frame-scratch 'la-frame-size rd base scratch))
     (+ (li-size tmp offset #:word-size word-size) 4)]))

;; ------------------------------------------------------------
;; 通用组合
;; ------------------------------------------------------------

;; mode:
;;   'pcrel : value = delta 或 #f（#f 表示留 relocation）
;;   'abs   : value = 绝对地址
;;   'got   : value 忽略
;;   'gp    : value = 平台基址相对 offset，必须提供 #:base（用哪个寄存器由调用方定）
;;   'frame : value = frame offset，必须提供 #:base
(define (expand-la rd value
                   #:mode [mode 'pcrel]
                   #:word-size [word-size 'rv64]
                   #:scratch [scratch #f]
                   #:base [base #f])
  (case mode
    [(pcrel)
     (la-pcrel rd #:delta value #:word-size word-size)]
    [(abs)
     (la-abs rd value #:word-size word-size #:scratch scratch)]
    [(got)
     (la-got rd #:word-size word-size)]
    [(gp)
     (unless base
       (error 'expand-la "gp mode requires #:base"))
     (la-gp rd base value)]
    [(frame)
     (unless base
       (error 'expand-la "frame mode requires #:base"))
     (la-frame rd base value #:scratch scratch #:word-size word-size)]
    [else
     (error 'expand-la "unknown la mode: ~a" mode)]))

(provide la-pcrel
         load-pcrel
         load-pcrel-size
         load-pcrel-far
         load-pcrel-far-size
         la-abs
         la-got
         la-gp
         la-frame
         la-frame-size
         expand-la)
