[bits 32]
; start in 32 bit mode, we will make the switch to long mode before we call into kernel_main

MBMAGIC         equ 0xE85250D6
MBARCH          equ 0
MBHEADERLEN     equ headerend - header
MBCHECKSUM      equ -(MBMAGIC + MBARCH + MBHEADERLEN)
MBHEADERTAGEND  equ 0

[section .multiboot]
align 4
header:
    dd MBMAGIC
    dd MBARCH
    dd MBHEADERLEN
    dd MBCHECKSUM

fbhstart:
    dw 5
    dw 1
    dd fbhend - fbhstart
    dd 1024
    dd 768
    dd 32

fbhend:
    dw MBHEADERTAGEND
    dw 0
    dd 0
headerend:


[section .text]
[bits 32]
[global _start]
PRESENT     equ 1 << 7
NOT_SYS     equ 1 << 4
EXEC        equ 1 << 3
RW          equ 1 << 1

GRAN_4K     equ 1 << 7
SZ_32       equ 1 << 6
LONG_MODE   equ 1 << 5

CPUID_EXTENSIONS        equ 0x80000000
CPUID_EXT_FEATURES      equ 0x80000001
CPUID_EDX_EXT_FEAT_LM   equ 1 << 29

CR0_PAGING  equ 1 << 31

_start:
    ; initial stack setup
    mov esp, stack_top
    mov ebp, esp

    ; save information about multiboot to memory (avoiding dealing with a possibly changing stack due to the jump to long mode)
    mov [mb2_magic], eax
    mov [mb2_mbiaddr], ebx

    cli

    ; Check if long mode is supported
    call checkCPUID
    jnz .hasCPUID

.noCPUID:
    hlt
    jmp .noCPUID

.hasCPUID:
    ; We can call cpuid
.queryLongMode:
    mov eax, CPUID_EXTENSIONS
    cpuid
    cmp eax, CPUID_EXT_FEATURES
    jb noLongMode

    mov eax, CPUID_EXT_FEATURES
    cpuid
    test edx, CPUID_EDX_EXT_FEAT_LM
    jz noLongMode

.disablePaging32:
    mov eax, cr0
    and eax, ~CR0_PAGING
    mov cr0, eax

.setupPageTable:
    mov eax, pdpt               ; move the address of the layer-3 page table into eax
    or eax, 0b11                ; set the present and r/w bits on this entry
    mov [pml4t], eax            ; write this value into entry 0 of the layer-4 page table

    mov eax, pdt                ; move the address of the layer-2 page table into eax
    or eax, 0b11                ; set the present and r/w bits on this entry
    mov [pdpt], eax             ; write this value into entry 0 of the layer-4 page table

    mov ecx, 0                  ; initialize counter
.ptloop:
    mov eax, 0x200000           ; pages are 2 MiB, so we need to jump by 2 MiB for each page we write
    mul ecx                     ; calculate page address using counter
    or eax, 0b10000011          ; set the present, r/w, huge page
    mov [pdt + ecx * 8], eax    ; set the page table entry in the layer 2 page table (since we use huge pages, there are no layer-1 page tables)

    inc ecx                     ; increment counter
    cmp ecx, 512                ; check if whole table is mapped
    jne .ptloop                 ; if not, continue mapping

.enablePaging:
    mov eax, pml4t
    mov cr3, eax

    ; enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; enable long mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; enable paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax


    lgdt [gdt_descriptor]
    jmp CODE_SEG:finish_setup


; No long mode
noLongMode:
    hlt
    jmp noLongMode

EFLAGS_ID   equ 1 << 21

; Check if the cpuid instruction is available.
; This is done by attempting to flip the id bit in the eflags register. if the bit can be flipped, then cpuid is available. Otherwise, it is not.
checkCPUID:
    pushfd
    pop eax
    mov ecx, eax
    xor eax, EFLAGS_ID
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    xor eax, ecx
    jnz .supported
    .notSupported:
        mov ax, 0
        ret
    .supported:
        mov ax, 1
        ret

gdt_start:
    dq 0
gdt_code:
    dw 0xffff
    dw 0
    db 0
    db PRESENT | NOT_SYS | EXEC | RW
    db GRAN_4K | LONG_MODE | 0xF
    db 0

gdt_data:
    dw 0xffff
    dw 0
    db 0
    db PRESENT | NOT_SYS | RW
    db GRAN_4K | SZ_32 | 0xF
    db 0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dq gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

[bits 64]
extern kernel_main
finish_setup:
    cli

    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax 

    xor rdi, rdi
    xor rsi, rsi
    mov edi, [mb2_magic]
    mov esi, [mb2_mbiaddr]

    call kernel_main


.hang:
    hlt
    jmp .hang


global get_pml4t_addr
get_pml4t_addr:
    mov rax, pml4t
    ret

global get_cr2
get_cr2:
    mov rax, cr2
    ret


[section .bss]
align 4096
pml4t:
resb 4096
pdpt:
resb 4096
pdt:
resb 4096

; multiboot data (while we allocate 8 bytes to each field, we only use 4. This is mostly for alignment and to make sure that the data is read correctly in 64 bit mode)
align 16
mb2_magic:
resb 8

mb2_mbiaddr:
resb 8

align 16
stack_bottom:
resb 16384
stack_top:


