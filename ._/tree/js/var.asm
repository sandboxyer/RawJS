section .text
    global _start

_start:
    ; Open /proc/self/status to get command line
    mov rax, 2          ; sys_open
    mov rdi, status_path
    mov rsi, 0          ; O_RDONLY
    syscall
    
    mov rbx, rax        ; save fd
    
    ; Read from file
    mov rax, 0          ; sys_read
    mov rdi, rbx
    mov rsi, buffer
    mov rdx, 4096
    syscall
    
    ; Close file
    mov rax, 3          ; sys_close
    mov rdi, rbx
    syscall
    
    ; Find "Name:" field in status file
    mov rdi, buffer
    mov rcx, 4096
    mov al, 'N'
    repne scasb
    cmp byte [rdi-1], 'N'
    jne .exit
    
    cmp byte [rdi], 'a'
    jne .exit
    cmp byte [rdi+1], 'm'
    jne .exit
    cmp byte [rdi+2], 'e'
    jne .exit
    cmp byte [rdi+3], ':'
    jne .exit
    
    ; Skip past "Name:" and whitespace
    add rdi, 4
.find_start:
    cmp byte [rdi], 0x20
    jne .found_start
    inc rdi
    jmp .find_start
    
.found_start:
    mov rsi, rdi        ; Start of filename
    
    ; Find end of filename (newline)
.find_end:
    cmp byte [rdi], 0x0A
    je .print_filename
    inc rdi
    jmp .find_end
    
.print_filename:
    mov rdx, rdi
    sub rdx, rsi        ; Calculate length
    
    ; Write filename
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    syscall
    
    ; Write separator
    mov rax, 1
    mov rdi, 1
    mov rsi, separator
    mov rdx, separator_len
    syscall
    
.exit:
    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

section .data
status_path: db '/proc/self/status', 0
separator: db ' | Done.', 0x0A
separator_len equ $ - separator

section .bss
buffer: resb 4096
