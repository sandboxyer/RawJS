section .data
    ; Data section - add your messages here

section .text
    global _start

; Print function
print_string:
    ; rsi = message pointer
    ; rdx = message length
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall
    ret

_start:
    ; Your program starts here

    ; Exit program
    mov rax, 60         ; sys_exit
    xor rdi, rdi        ; exit code 0
    syscall
