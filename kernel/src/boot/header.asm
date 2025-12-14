[bits 32]
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
