#lang racket
;;; encode/syntax/csr-table.rkt
;;;
;;; 由 riscv-opcodes/csrs.csv 生成。RV32/RV64 公共 CSR。
;;; 名字 -> 12 位 CSR 编号。这里只有事实, 没有语法/策略。

(provide csr-table)

(define csr-table
  (hash
   'cycle #xc00 'dcsr #x7b0 'dpc #x7b1 'dscratch0 #x7b2
   'dscratch1 #x7b3 'fcsr #x003 'fflags #x001 'frm #x002
   'hcontext #x6a8 'hcounteren #x606 'hedeleg #x602 'henvcfg #x60a
   'hgatp #x680 'hgeie #x607 'hgeip #xe12 'hideleg #x603
   'hie #x604 'hip #x644 'hpmcounter10 #xc0a 'hpmcounter11 #xc0b
   'hpmcounter12 #xc0c 'hpmcounter13 #xc0d 'hpmcounter14 #xc0e 'hpmcounter15 #xc0f
   'hpmcounter16 #xc10 'hpmcounter17 #xc11 'hpmcounter18 #xc12 'hpmcounter19 #xc13
   'hpmcounter20 #xc14 'hpmcounter21 #xc15 'hpmcounter22 #xc16 'hpmcounter23 #xc17
   'hpmcounter24 #xc18 'hpmcounter25 #xc19 'hpmcounter26 #xc1a 'hpmcounter27 #xc1b
   'hpmcounter28 #xc1c 'hpmcounter29 #xc1d 'hpmcounter3 #xc03 'hpmcounter30 #xc1e
   'hpmcounter31 #xc1f 'hpmcounter4 #xc04 'hpmcounter5 #xc05 'hpmcounter6 #xc06
   'hpmcounter7 #xc07 'hpmcounter8 #xc08 'hpmcounter9 #xc09 'hstateen0 #x60c
   'hstateen1 #x60d 'hstateen2 #x60e 'hstateen3 #x60f 'hstatus #x600
   'htimedelta #x605 'htinst #x64a 'htval #x643 'hvictl #x609
   'hvien #x608 'hvip #x645 'hviprio1 #x646 'hviprio2 #x647
   'instret #xc02 'jvt #x017 'marchid #xf12 'mcause #x342
   'mconfigptr #xf15 'mcontext #x7a8 'mcounteren #x306 'mcountinhibit #x320
   'mctrctl #x34e 'mcycle #xb00 'mcyclecfg #x321 'medeleg #x302
   'menvcfg #x30a 'mepc #x341 'mhartid #xf14 'mhpmcounter10 #xb0a
   'mhpmcounter11 #xb0b 'mhpmcounter12 #xb0c 'mhpmcounter13 #xb0d 'mhpmcounter14 #xb0e
   'mhpmcounter15 #xb0f 'mhpmcounter16 #xb10 'mhpmcounter17 #xb11 'mhpmcounter18 #xb12
   'mhpmcounter19 #xb13 'mhpmcounter20 #xb14 'mhpmcounter21 #xb15 'mhpmcounter22 #xb16
   'mhpmcounter23 #xb17 'mhpmcounter24 #xb18 'mhpmcounter25 #xb19 'mhpmcounter26 #xb1a
   'mhpmcounter27 #xb1b 'mhpmcounter28 #xb1c 'mhpmcounter29 #xb1d 'mhpmcounter3 #xb03
   'mhpmcounter30 #xb1e 'mhpmcounter31 #xb1f 'mhpmcounter4 #xb04 'mhpmcounter5 #xb05
   'mhpmcounter6 #xb06 'mhpmcounter7 #xb07 'mhpmcounter8 #xb08 'mhpmcounter9 #xb09
   'mhpmevent10 #x32a 'mhpmevent11 #x32b 'mhpmevent12 #x32c 'mhpmevent13 #x32d
   'mhpmevent14 #x32e 'mhpmevent15 #x32f 'mhpmevent16 #x330 'mhpmevent17 #x331
   'mhpmevent18 #x332 'mhpmevent19 #x333 'mhpmevent20 #x334 'mhpmevent21 #x335
   'mhpmevent22 #x336 'mhpmevent23 #x337 'mhpmevent24 #x338 'mhpmevent25 #x339
   'mhpmevent26 #x33a 'mhpmevent27 #x33b 'mhpmevent28 #x33c 'mhpmevent29 #x33d
   'mhpmevent3 #x323 'mhpmevent30 #x33e 'mhpmevent31 #x33f 'mhpmevent4 #x324
   'mhpmevent5 #x325 'mhpmevent6 #x326 'mhpmevent7 #x327 'mhpmevent8 #x328
   'mhpmevent9 #x329 'mideleg #x303 'mie #x304 'mimpid #xf13
   'minstret #xb02 'minstretcfg #x322 'mintstatus #x346 'mip #x344
   'mireg #x351 'mireg2 #x352 'mireg3 #x353 'mireg4 #x355
   'mireg5 #x356 'mireg6 #x357 'misa #x301 'miselect #x350
   'mnxti #x345 'mpmpdeleg #x316 'mscontext #x7aa 'mscratch #x340
   'mscratchcsw #x348 'mscratchcswl #x349 'mseccfg #x747 'mstateen0 #x30c
   'mstateen1 #x30d 'mstateen2 #x30e 'mstateen3 #x30f 'mstatus #x300
   'mtinst #x34a 'mtopei #x35c 'mtopi #xfb0 'mtval #x343
   'mtval2 #x34b 'mtvec #x305 'mtvt #x307 'mtype #xc23
   'mvendorid #xf11 'mvien #x308 'mvip #x309 'pmpaddr0 #x3b0
   'pmpaddr1 #x3b1 'pmpaddr10 #x3ba 'pmpaddr11 #x3bb 'pmpaddr12 #x3bc
   'pmpaddr13 #x3bd 'pmpaddr14 #x3be 'pmpaddr15 #x3bf 'pmpaddr16 #x3c0
   'pmpaddr17 #x3c1 'pmpaddr18 #x3c2 'pmpaddr19 #x3c3 'pmpaddr2 #x3b2
   'pmpaddr20 #x3c4 'pmpaddr21 #x3c5 'pmpaddr22 #x3c6 'pmpaddr23 #x3c7
   'pmpaddr24 #x3c8 'pmpaddr25 #x3c9 'pmpaddr26 #x3ca 'pmpaddr27 #x3cb
   'pmpaddr28 #x3cc 'pmpaddr29 #x3cd 'pmpaddr3 #x3b3 'pmpaddr30 #x3ce
   'pmpaddr31 #x3cf 'pmpaddr32 #x3d0 'pmpaddr33 #x3d1 'pmpaddr34 #x3d2
   'pmpaddr35 #x3d3 'pmpaddr36 #x3d4 'pmpaddr37 #x3d5 'pmpaddr38 #x3d6
   'pmpaddr39 #x3d7 'pmpaddr4 #x3b4 'pmpaddr40 #x3d8 'pmpaddr41 #x3d9
   'pmpaddr42 #x3da 'pmpaddr43 #x3db 'pmpaddr44 #x3dc 'pmpaddr45 #x3dd
   'pmpaddr46 #x3de 'pmpaddr47 #x3df 'pmpaddr48 #x3e0 'pmpaddr49 #x3e1
   'pmpaddr5 #x3b5 'pmpaddr50 #x3e2 'pmpaddr51 #x3e3 'pmpaddr52 #x3e4
   'pmpaddr53 #x3e5 'pmpaddr54 #x3e6 'pmpaddr55 #x3e7 'pmpaddr56 #x3e8
   'pmpaddr57 #x3e9 'pmpaddr58 #x3ea 'pmpaddr59 #x3eb 'pmpaddr6 #x3b6
   'pmpaddr60 #x3ec 'pmpaddr61 #x3ed 'pmpaddr62 #x3ee 'pmpaddr63 #x3ef
   'pmpaddr7 #x3b7 'pmpaddr8 #x3b8 'pmpaddr9 #x3b9 'pmpcfg0 #x3a0
   'pmpcfg1 #x3a1 'pmpcfg10 #x3aa 'pmpcfg11 #x3ab 'pmpcfg12 #x3ac
   'pmpcfg13 #x3ad 'pmpcfg14 #x3ae 'pmpcfg15 #x3af 'pmpcfg2 #x3a2
   'pmpcfg3 #x3a3 'pmpcfg4 #x3a4 'pmpcfg5 #x3a5 'pmpcfg6 #x3a6
   'pmpcfg7 #x3a7 'pmpcfg8 #x3a8 'pmpcfg9 #x3a9 'satp #x180
   'scause #x142 'scontext #x5a8 'scounteren #x106 'scountinhibit #x120
   'scountovf #xda0 'sctrctl #x14e 'sctrdepth #x15f 'sctrstatus #x14f
   'seed #x015 'senvcfg #x10a 'sepc #x141 'sie #x104
   'sintstatus #x146 'sip #x144 'sireg #x151 'sireg2 #x152
   'sireg3 #x153 'sireg4 #x155 'sireg5 #x156 'sireg6 #x157
   'siselect #x150 'snxti #x145 'spmpen #x183 'srmcfg #x181
   'sscratch #x140 'sscratchcsw #x148 'sscratchcswl #x149 'ssp #x011
   'sstateen0 #x10c 'sstateen1 #x10d 'sstateen2 #x10e 'sstateen3 #x10f
   'sstatus #x100 'stimecmp #x14d 'stopei #x15c 'stopi #xdb0
   'stval #x143 'stvec #x105 'stvt #x107 'tcontrol #x7a5
   'tdata1 #x7a1 'tdata2 #x7a2 'tdata3 #x7a3 'time #xc01
   'tinfo #x7a4 'tselect #x7a0 'uintstatus #x046 'unxti #x045
   'uscratchcsw #x048 'uscratchcswl #x049 'utvt #x007 'vcsr #x00f
   'vl #xc20 'vlenb #xc22 'vsatp #x280 'vscause #x242
   'vsctrctl #x24e 'vsepc #x241 'vsie #x204 'vsip #x244
   'vsireg #x251 'vsireg2 #x252 'vsireg3 #x253 'vsireg4 #x255
   'vsireg5 #x256 'vsireg6 #x257 'vsiselect #x250 'vsscratch #x240
   'vsstatus #x200 'vstart #x008 'vstimecmp #x24d 'vstopei #x25c
   'vstopi #xeb0 'vstval #x243 'vstvec #x205 'vtype #xc21
   'vxrm #x00a 'vxsat #x009
   ))
