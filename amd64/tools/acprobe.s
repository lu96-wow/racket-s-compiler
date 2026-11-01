        .text
        .globl _start
_start:
        pushfq
        orl     $0x40000, (%rsp)        /* RFLAGS.AC = 1 */
        popfq
        lea     buf+1(%rip), %rax       /* unaligned address */
        movl    (%rax), %eax            /* must raise SIGBUS while AC=1 */
        mov     $60, %eax               /* exit(0): #AC did NOT fire */
        xor     %edi, %edi
        syscall
        .data
        .align 8
buf:    .long   0x11223344
        .long   0
