section .data
    filename db "./build_output.asm", 0
    template db "section .data", 10
             db "    ; Constants (like JavaScript const)", 10
             db "    ; Example: MAX_SIZE equ 100", 10, 10
             
             db "    ; Global variables (like JavaScript let/var)", 10
             db "    ; Example: counter dq 0", 10
             db "    ; Example: message db 'Hello', 0", 10, 10
             
             db "    ; Function pointers", 10
             db "    ; Example: callback dq 0", 10, 10
             
             db "    ; Type constants for print function", 10
             db "    TYPE_STRING equ 1", 10
             db "    TYPE_NUMBER equ 2", 10
             db "    TYPE_CHAR    equ 3", 10
             db "    TYPE_BOOLEAN equ 4", 10
             db "    TYPE_NULL    equ 5", 10
             db "    TYPE_UNDEFINED equ 6", 10, 10
             
             db "    ; Boolean strings", 10
             db "    true_str db 'true', 0", 10
             db "    false_str db 'false', 0", 10
             db "    null_str db 'null', 0", 10
             db "    undefined_str db 'undefined', 0", 10
             db "    hex_prefix db '0x', 0", 10, 10
             
             db "section .bss", 10
             db "    ; Uninitialized variables", 10
             db "    ; Example: buffer resb 256", 10
             db "    ; Example: temp resq 1", 10
             db "    print_buffer resb 32", 10, 10
             
             db "section .text", 10
             db "    global _start", 10, 10
             
             db "; Smart print function - detects type and prints appropriately", 10
             db "; Input: RAX = value to print", 10
             db ";        RDX = type (TYPE_STRING, TYPE_NUMBER, etc.)", 10
             db "; For strings: RAX = pointer to null-terminated string", 10
             db "; For numbers: RAX = 64-bit number", 10
             db "; For chars: RAX = character (only lower 8 bits used)", 10
             db "; For booleans: RAX = 0 for false, non-zero for true", 10
             db "print:", 10
             db "    push rsi", 10
             db "    push rdi", 10
             db "    push rcx", 10
             db "    push rdx", 10
             db "    push rax", 10, 10
             
             db "    cmp rdx, TYPE_STRING", 10
             db "    je .print_string", 10
             db "    cmp rdx, TYPE_NUMBER", 10
             db "    je .print_number", 10
             db "    cmp rdx, TYPE_CHAR", 10
             db "    je .print_char", 10
             db "    cmp rdx, TYPE_BOOLEAN", 10
             db "    je .print_boolean", 10
             db "    cmp rdx, TYPE_NULL", 10
             db "    je .print_null", 10
             db "    cmp rdx, TYPE_UNDEFINED", 10
             db "    je .print_undefined", 10
             db "    jmp .print_hex  ; Default: print as hex", 10, 10
             
             db ".print_string:", 10
             db "    mov rsi, rax", 10
             db "    call print_raw_string", 10
             db "    jmp .print_done", 10, 10
             
             db ".print_number:", 10
             db "    call print_raw_number", 10
             db "    jmp .print_done", 10, 10
             
             db ".print_char:", 10
             db "    mov [print_buffer], al", 10
             db "    mov byte [print_buffer + 1], 0", 10
             db "    mov rax, print_buffer", 10
             db "    mov rdx, TYPE_STRING", 10
             db "    call print", 10
             db "    jmp .print_done", 10, 10
             
             db ".print_boolean:", 10
             db "    test rax, rax", 10
             db "    jz .print_false", 10
             db "    mov rax, true_str", 10
             db "    mov rdx, TYPE_STRING", 10
             db "    call print", 10
             db "    jmp .print_done", 10
             db ".print_false:", 10
             db "    mov rax, false_str", 10
             db "    mov rdx, TYPE_STRING", 10
             db "    call print", 10
             db "    jmp .print_done", 10, 10
             
             db ".print_null:", 10
             db "    mov rax, null_str", 10
             db "    mov rdx, TYPE_STRING", 10
             db "    call print", 10
             db "    jmp .print_done", 10, 10
             
             db ".print_undefined:", 10
             db "    mov rax, undefined_str", 10
             db "    mov rdx, TYPE_STRING", 10
             db "    call print", 10
             db "    jmp .print_done", 10, 10
             
             db ".print_hex:", 10
             db "    mov rsi, hex_prefix", 10
             db "    call print_raw_string", 10
             db "    call print_raw_hex", 10
             db "    jmp .print_done", 10, 10
             
             db ".print_done:", 10
             db "    pop rax", 10
             db "    pop rdx", 10
             db "    pop rcx", 10
             db "    pop rdi", 10
             db "    pop rsi", 10
             db "    ret", 10, 10
             
             db "; Internal helper functions", 10
             db "print_raw_string:", 10
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
             
             db "print_raw_number:", 10
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
             db "    call print_raw_string", 10
             db "    add rsp, 32", 10
             db "    pop rsi", 10
             db "    pop rdi", 10
             db "    pop rdx", 10
             db "    pop rbx", 10
             db "    pop rax", 10
             db "    ret", 10, 10
             
             db "print_raw_hex:", 10
             db "    push rax", 10
             db "    push rbx", 10
             db "    push rdx", 10
             db "    push rdi", 10
             db "    push rsi", 10
             db "    sub rsp, 32", 10
             db "    lea rdi, [rsp+16]", 10
             db "    mov byte [rdi+16], 0", 10
             db "    add rdi, 15", 10
             db "    mov rbx, 16", 10
             db "    mov rcx, 16", 10
             db ".hex_loop:", 10
             db "    xor rdx, rdx", 10
             db "    div rbx", 10
             db "    cmp dl, 10", 10
             db "    jl .hex_digit", 10
             db "    add dl, 'a' - 10", 10
             db "    jmp .store_hex", 10
             db ".hex_digit:", 10
             db "    add dl, '0'", 10
             db ".store_hex:", 10
             db "    mov [rdi], dl", 10
             db "    dec rdi", 10
             db "    dec rcx", 10
             db "    test rax, rax", 10
             db "    jnz .hex_loop", 10
             db "    inc rdi", 10
             db "    mov rsi, rdi", 10
             db "    call print_raw_string", 10
             db "    add rsp, 32", 10
             db "    pop rsi", 10
             db "    pop rdi", 10
             db "    pop rdx", 10
             db "    pop rbx", 10
             db "    pop rax", 10
             db "    ret", 10, 10
             
             db "_start:", 10
             db "    ; Your code here", 10
             db "    ; Example usage:", 10
             db "    ;   mov rax, hello_msg", 10
             db "    ;   mov rdx, TYPE_STRING", 10
             db "    ;   call print", 10, 10
             
             db "    mov rax, 60", 10
             db "    xor rdi, rdi", 10
             db "    syscall", 10
    template_len equ $ - template

section .bss
    fd resq 1

section .text
    global _start

_start:
    ; Create the template file
    mov rax, 2
    mov rdi, filename
    mov rsi, 0o101
    or rsi, 0o100
    mov rdx, 0o644
    syscall
    
    cmp rax, 0
    jl exit_error
    
    mov [fd], rax

    ; Write the template content
    mov rax, 1
    mov rdi, [fd]
    mov rsi, template
    mov rdx, template_len
    syscall

    ; Close the file
    mov rax, 3
    mov rdi, [fd]
    syscall

    ; Exit successfully
    mov rax, 60
    xor rdi, rdi
    syscall

exit_error:
    mov rax, 60
    mov rdi, 1
    syscall