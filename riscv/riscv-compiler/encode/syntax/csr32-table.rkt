#lang racket
;;; encode/syntax/csr32-table.rkt
;;;
;;; 由 riscv-opcodes/csrs32.csv 生成。只给未来的 rv32 target profile 用。
;;; 名字 -> 12 位 CSR 编号。这里只有事实, 没有语法/策略。

(provide csr32-table)

(define csr32-table
  (hash
   'cycleh #xc80 'hedelegh #x612 'henvcfgh #x61a 'hidelegh #x613
   'hpmcounter10h #xc8a 'hpmcounter11h #xc8b 'hpmcounter12h #xc8c 'hpmcounter13h #xc8d
   'hpmcounter14h #xc8e 'hpmcounter15h #xc8f 'hpmcounter16h #xc90 'hpmcounter17h #xc91
   'hpmcounter18h #xc92 'hpmcounter19h #xc93 'hpmcounter20h #xc94 'hpmcounter21h #xc95
   'hpmcounter22h #xc96 'hpmcounter23h #xc97 'hpmcounter24h #xc98 'hpmcounter25h #xc99
   'hpmcounter26h #xc9a 'hpmcounter27h #xc9b 'hpmcounter28h #xc9c 'hpmcounter29h #xc9d
   'hpmcounter30h #xc9e 'hpmcounter31h #xc9f 'hpmcounter3h #xc83 'hpmcounter4h #xc84
   'hpmcounter5h #xc85 'hpmcounter6h #xc86 'hpmcounter7h #xc87 'hpmcounter8h #xc88
   'hpmcounter9h #xc89 'hstateen0h #x61c 'hstateen1h #x61d 'hstateen2h #x61e
   'hstateen3h #x61f 'htimedeltah #x615 'hvienh #x618 'hviph #x655
   'hviprio1h #x656 'hviprio2h #x657 'instreth #xc82 'mcyclecfgh #x721
   'mcycleh #xb80 'medelegh #x312 'menvcfgh #x31a 'mhpmcounter10h #xb8a
   'mhpmcounter11h #xb8b 'mhpmcounter12h #xb8c 'mhpmcounter13h #xb8d 'mhpmcounter14h #xb8e
   'mhpmcounter15h #xb8f 'mhpmcounter16h #xb90 'mhpmcounter17h #xb91 'mhpmcounter18h #xb92
   'mhpmcounter19h #xb93 'mhpmcounter20h #xb94 'mhpmcounter21h #xb95 'mhpmcounter22h #xb96
   'mhpmcounter23h #xb97 'mhpmcounter24h #xb98 'mhpmcounter25h #xb99 'mhpmcounter26h #xb9a
   'mhpmcounter27h #xb9b 'mhpmcounter28h #xb9c 'mhpmcounter29h #xb9d 'mhpmcounter30h #xb9e
   'mhpmcounter31h #xb9f 'mhpmcounter3h #xb83 'mhpmcounter4h #xb84 'mhpmcounter5h #xb85
   'mhpmcounter6h #xb86 'mhpmcounter7h #xb87 'mhpmcounter8h #xb88 'mhpmcounter9h #xb89
   'mhpmevent10h #x72a 'mhpmevent11h #x72b 'mhpmevent12h #x72c 'mhpmevent13h #x72d
   'mhpmevent14h #x72e 'mhpmevent15h #x72f 'mhpmevent16h #x730 'mhpmevent17h #x731
   'mhpmevent18h #x732 'mhpmevent19h #x733 'mhpmevent20h #x734 'mhpmevent21h #x735
   'mhpmevent22h #x736 'mhpmevent23h #x737 'mhpmevent24h #x738 'mhpmevent25h #x739
   'mhpmevent26h #x73a 'mhpmevent27h #x73b 'mhpmevent28h #x73c 'mhpmevent29h #x73d
   'mhpmevent30h #x73e 'mhpmevent31h #x73f 'mhpmevent3h #x723 'mhpmevent4h #x724
   'mhpmevent5h #x725 'mhpmevent6h #x726 'mhpmevent7h #x727 'mhpmevent8h #x728
   'mhpmevent9h #x729 'midelegh #x313 'mieh #x314 'minstretcfgh #x722
   'minstreth #xb82 'miph #x354 'mncause #x742 'mnepc #x741
   'mnscratch #x740 'mnstatus #x744 'mseccfgh #x757 'mstateen0h #x31c
   'mstateen1h #x31d 'mstateen2h #x31e 'mstateen3h #x31f 'mstatush #x310
   'mvienh #x318 'mviph #x319 'sieh #x114 'siph #x154
   'spmpenh #x193 'stimecmph #x15d 'timeh #xc81 'vsieh #x214
   'vsiph #x254 'vstimecmph #x25d
   ))
