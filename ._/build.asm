section .data
    filename db "./build_output.asm", 0
    template db "; =========================================================", 10
             db "; EASY-APPEND BLANK ASSEMBLY TEMPLATE", 10
             db "; =========================================================", 10, 10
             
             db "; 1. DATA SECTION - Add variables and messages here", 10
             db "; =========================================================", 10
             db "section .data", 10
             db "    ; === STRING MESSAGES ===", 10
             db "    ; Add here: msg_name db 'text', 10, 0", 10, 10
             
             db "    ; === VARIABLES ===", 10
             db "    ; Add here: var_name dq value", 10, 10
             
             db "    ; === CONSTANTS ===", 10
             db "    ; Add here: CONST_NAME equ value", 10, 10
             
             db "; 2. BSS SECTION - Uninitialized data", 10
             db "; =========================================================", 10
             db "section .bss", 10
             db "    ; === BUFFERS ===", 10
             db "    ; Add here: buffer_name resb size", 10, 10
             
             db "; 3. TEXT SECTION - Code", 10
             db "; =========================================================", 10
             db "section .text", 10
             db "    global _start", 10, 10
             
             db "; === PRINT FUNCTION (null-terminated string) ===", 10
             db "; Input: RSI = string pointer", 10
             db "print_str:", 10
             db "    push rdi", 10
             db "    push rcx", 10
             db "    push rdx", 10
             db "    mov rdi, rsi", 10
             db "    xor rcx, rcx", 10
             db "    not rcx", 10
             db "    xor al, al", 10
             db "    repne scasb", 10
             db "    not rcx", 10
             db "    dec rcx", 10
             db "    mov rax, 1", 10
             db "    mov rdi, 1", 10
             db "    mov rdx, rcx", 10
             db "    syscall", 10
             db "    pop rdx", 10
             db "    pop rcx", 10
             db "    pop rdi", 10
             db "    ret", 10, 10
             
             db "; === PRINT NUMBER (64-bit unsigned) ===", 10
             db "; Input: RAX = number", 10
             db "print_num:", 10
             db "    push rax", 10
             db "    push rbx", 10
             db "    push rdx", 10
             db "    push rdi", 10
             db "    push rsi", 10
             db "    sub rsp, 32", 10
             db "    lea rdi, [rsp+16]", 10
             db "    mov byte [rdi+19], 0", 10
             db "    add rdi, 18", 10
             db "    mov rbx, 10", 10
             db ".convert_loop:", 10
             db "    xor rdx, rdx", 10
             db "    div rbx", 10
             db "    add dl, '0'", 10
             db "    mov [rdi], dl", 10
             db "    dec rdi", 10
             db "    test rax, rax", 10
             db "    jnz .convert_loop", 10
             db "    inc rdi", 10
             db "    mov rsi, rdi", 10
             db "    call print_str", 10
             db "    add rsp, 32", 10
             db "    pop rsi", 10
             db "    pop rdi", 10
             db "    pop rdx", 10
             db "    pop rbx", 10
             db "    pop rax", 10
             db "    ret", 10, 10
             
             db "; === CUSTOM FUNCTIONS ===", 10
             db "; Add your functions here:", 10, 10
             
             db "; 4. MAIN PROGRAM", 10
             db "; =========================================================", 10
             db "_start:", 10
             db "    ; === YOUR CODE STARTS HERE ===", 10
             db "    ; Add initialization, logic, and prints", 10, 10
             
             db "    ; === EXIT PROGRAM ===", 10
             db "    mov rax, 60", 10
             db "    xor rdi, rdi", 10
             db "    syscall", 10
             
             db "; =========================================================", 10
             db "; END OF TEMPLATE", 10
             db "; =========================================================", 10
    template_len equ $ - template

section .bss
    fd resq 1

section .text
    global _start

_start:
    ; Open file
    mov rax, 2
    mov rdi, filename
    mov rsi, 0o101
    or rsi, 0o100
    mov rdx, 0o644
    syscall
    
    cmp rax, 0
    jl exit_error
    
    mov [fd], rax

    ; Write template
    mov rax, 1
    mov rdi, [fd]
    mov rsi, template
    mov rdx, template_len
    syscall

    ; Close file
    mov rax, 3
    mov rdi, [fd]
    syscall

    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall

exit_error:
    mov rax, 60
    mov rdi, 1
    syscall
