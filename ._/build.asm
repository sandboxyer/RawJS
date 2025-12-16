section .data
    filename db "./build_output.asm", 0
    template db "; =========================================================", 10
             db "; JS-LIKE ASSEMBLY TEMPLATE - Easy JavaScript to Assembly", 10
             db "; =========================================================", 10, 10
             
             db "; 1. CONSTANTS SECTION (like JavaScript const)", 10
             db "; =========================================================", 10
             db "section .data", 10
             db "    ; === COMPILE-TIME CONSTANTS (const in JS) ===", 10
             db "    ; Add here: CONST_NAME equ value", 10
             db "    ; Example: MAX_SIZE equ 100", 10
             db "    ;          NULL equ 0", 10, 10
             
             db "    ; === READ-ONLY STRINGS (const strings) ===", 10
             db "    ; Add here: MSG_NAME db 'text', 10, 0", 10
             db "    ; Example: MSG_HELLO db 'Hello', 10, 0", 10, 10
             
             db "; 2. GLOBAL VARIABLES SECTION", 10
             db "; =========================================================", 10
             db "    ; === GLOBAL LET VARIABLES (let at global scope) ===", 10
             db "    ; Add here: g_name dq initial_value", 10
             db "    ; Example: g_counter dq 0", 10
             db "    ;          g_flag dq 1", 10, 10
             
             db "    ; === GLOBAL VAR VARIABLES (var at global scope) ===", 10
             db "    ; Add here: v_name dq initial_value", 10
             db "    ; Example: v_state dq 0", 10, 10
             
             db "; 3. UNINITIALIZED DATA SECTION", 10
             db "; =========================================================", 10
             db "section .bss", 10
             db "    ; === UNINITIALIZED LET VARIABLES (let x;) ===", 10
             db "    ; Add here: u_name resq 1", 10
             db "    ; Example: u_buffer_ptr resq 1", 10
             db "    ;          u_temp_value resq 1", 10, 10
             
             db "    ; === BUFFERS & ARRAYS ===", 10
             db "    ; Add here: buffer_name resb size", 10
             db "    ; Example: input_buffer resb 256", 10
             db "    ;          num_array resq 10", 10, 10
             
             db "; 4. CODE SECTION - Functions and Main Program", 10
             db "; =========================================================", 10
             db "section .text", 10
             db "    global _start", 10, 10
             
             db "; === UTILITY FUNCTIONS ===", 10, 10
             
             db "; print_str - Print null-terminated string (console.log)", 10
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
             
             db "; print_num - Print number (console.log with numbers)", 10
             db "; Input: RAX = 64-bit unsigned number", 10
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
             
             db "; === CUSTOM FUNCTIONS (function in JS) ===", 10
             db "; Add your functions here with JavaScript-like patterns:", 10
             db "; function_name:", 10
             db ";     push rbp", 10
             db ";     mov rbp, rsp", 10
             db ";     sub rsp, N    ; Allocate space for local vars", 10
             db ";     ; [rbp-8]   = let local_var1", 10
             db ";     ; [rbp-16]  = let local_var2", 10
             db ";     ; [rbp-24]  = var hoisted_var (function scope)", 10
             db ";     ; Use registers for const values", 10
             db ";     ; ... function body ...", 10
             db ";     add rsp, N", 10
             db ";     pop rbp", 10
             db ";     ret", 10, 10
             
             db "; === MAIN PROGRAM (like JavaScript global scope) ===", 10
             db "; =========================================================", 10
             db "_start:", 10
             db "    ; === INITIALIZE GLOBAL VARIABLES ===", 10
             db "    ; Initialize global let/var variables here:", 10
             db "    ; Example: mov QWORD [g_counter], 0", 10
             db "    ;          mov QWORD [v_state], 1", 10, 10
             
             db "    ; === YOUR JAVASCRIPT-LIKE CODE STARTS HERE ===", 10
             db "    ; Pattern 1: console.log('message')", 10
             db "    ;   mov rsi, MSG_NAME", 10
             db "    ;   call print_str", 10, 10
             
             db "    ; Pattern 2: let x = 10; console.log(x)", 10
             db "    ;   ; In .data: x dq 10", 10
             db "    ;   mov rsi, MSG_X", 10
             db "    ;   call print_str", 10
             db "    ;   mov rax, [x]", 10
             db "    ;   call print_num", 10
             db "    ;   mov rsi, MSG_NEWLINE", 10
             db "    ;   call print_str", 10, 10
             
             db "    ; Pattern 3: const y = 20; console.log(y)", 10
             db "    ;   ; In .data: Y equ 20", 10
             db "    ;   mov rsi, MSG_Y", 10
             db "    ;   call print_str", 10
             db "    ;   mov rax, Y", 10
             db "    ;   call print_num", 10
             db "    ;   mov rsi, MSG_NEWLINE", 10
             db "    ;   call print_str", 10, 10
             
             db "    ; Pattern 4: if-else statements", 10
             db "    ;   cmp [g_counter], 10", 10
             db "    ;   jl .if_block", 10
             db "    ;   jmp .else_block", 10
             db "    ; .if_block:", 10
             db "    ;   ; if code here", 10
             db "    ;   jmp .endif", 10
             db "    ; .else_block:", 10
             db "    ;   ; else code here", 10
             db "    ; .endif:", 10, 10
             
             db "    ; Pattern 5: for loops", 10
             db "    ;   mov QWORD [i], 0      ; let i = 0", 10
             db "    ; .for_loop:", 10
             db "    ;   cmp QWORD [i], 10     ; i < 10", 10
             db "    ;   jge .for_end", 10
             db "    ;   ; loop body here", 10
             db "    ;   inc QWORD [i]         ; i++", 10
             db "    ;   jmp .for_loop", 10
             db "    ; .for_end:", 10, 10
             
             db "    ; Pattern 6: while loops", 10
             db "    ; .while_start:", 10
             db "    ;   cmp [flag], 0", 10
             db "    ;   je .while_end", 10
             db "    ;   ; while body here", 10
             db "    ;   jmp .while_start", 10
             db "    ; .while_end:", 10, 10
             
             db "    ; Pattern 7: Function calls", 10
             db "    ;   call function_name", 10, 10
             
             db "    ; === CLEANUP ===", 10
             db "    ; Reset variables if needed", 10
             db "    ; Example: mov QWORD [g_counter], 0", 10, 10
                          
             db "    ; === EXIT PROGRAM ===", 10
             db "    mov rax, 60", 10
             db "    xor rdi, rdi", 10
             db "    syscall", 10, 10
             
             db "; === EXAMPLE DATA FOR WORKING TEMPLATE ===", 10
             db "; (Remove these when adding your own code)", 10
             db "msg_test: db 'Template works! ', 0", 10
             db "msg_newline: db 10, 0", 10, 10
             
             db "; === LOCAL FUNCTION EXAMPLES (uncomment and modify) ===", 10
             db "; calculate_sum:", 10
             db ";     push rbp", 10
             db ";     mov rbp, rsp", 10
             db ";     sub rsp, 16", 10
             db ";     ; let a = [rbp-8]", 10
             db ";     ; let b = [rbp-16]", 10
             db ";     mov QWORD [rbp-8], 10    ; a = 10", 10
             db ";     mov QWORD [rbp-16], 20   ; b = 20", 10
             db ";     mov rax, [rbp-8]", 10
             db ";     add rax, [rbp-16]        ; return a + b", 10
             db ";     add rsp, 16", 10
             db ";     pop rbp", 10
             db ";     ret", 10, 10
             
             db "; =========================================================", 10
             db "; JS → ASSEMBLY QUICK REFERENCE", 10
             db "; =========================================================", 10
             db "; JavaScript           Assembly", 10
             db "; -----------          --------", 10
             db "; const MAX = 100      MAX equ 100", 10
             db "; const MSG = 'hi'     MSG db 'hi',10,0", 10
             db "; let x = 5            x dq 5", 10
             db "; let y;               y resq 1", 10
             db "; var z = 10           z dq 10", 10
             db "; console.log(msg)     mov rsi, MSG; call print_str", 10
             db "; console.log(num)     mov rax, [NUM]; call print_num", 10
             db "; if (x > 0)           cmp [x], 0; jg .if_true", 10
             db "; for(i=0;i<10;i++)    mov [i],0;.loop: cmp [i],10; jge .end", 10
             db "; function fn() {      fn: push rbp; mov rbp,rsp; sub rsp,N", 10
             db "; =========================================================", 10
             db "; END OF TEMPLATE - Ready for JavaScript-like assembly!", 10
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
