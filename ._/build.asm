section .data
    filename db "./build_output.asm", 0  ; Added ./ to ensure current directory
    template db "section .data", 10
             db "    ; Data section - add your messages here", 10, 10
             db "section .text", 10
             db "    global _start", 10, 10
             db "; Print function", 10
             db "print_string:", 10
             db "    ; rsi = message pointer", 10
             db "    ; rdx = message length", 10
             db "    mov rax, 1          ; sys_write", 10
             db "    mov rdi, 1          ; stdout", 10
             db "    syscall", 10
             db "    ret", 10, 10
             db "_start:", 10
             db "    ; Your program starts here", 10, 10
             db "    ; Exit program", 10
             db "    mov rax, 60         ; sys_exit", 10
             db "    xor rdi, rdi        ; exit code 0", 10
             db "    syscall", 10
    template_len equ $ - template

section .bss
    fd resq 1

section .text
    global _start

_start:
    ; Open file for writing (create or truncate)
    mov rax, 2          ; sys_open
    mov rdi, filename   ; filename - now with ./ prefix
    mov rsi, 0o101      ; O_CREAT | O_WRONLY | O_TRUNC (decimal 577)
    or rsi, 0o100       ; Ensure O_CREAT flag
    mov rdx, 0o644      ; rw-r--r--
    syscall
    
    ; Check for errors
    cmp rax, 0
    jl exit_error       ; If negative, error occurred
    
    mov [fd], rax       ; save file descriptor

    ; Write template to file
    mov rax, 1          ; sys_write
    mov rdi, [fd]       ; file descriptor
    mov rsi, template   ; buffer
    mov rdx, template_len ; length
    syscall

    ; Close file
    mov rax, 3          ; sys_close
    mov rdi, [fd]
    syscall

    ; Exit successfully
    mov rax, 60         ; sys_exit
    xor rdi, rdi        ; exit code 0
    syscall

exit_error:
    ; Exit with error code 1
    mov rax, 60         ; sys_exit
    mov rdi, 1          ; exit code 1
    syscall
