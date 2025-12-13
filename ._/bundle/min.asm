section .data
    ; Error messages
    error_args db 'Usage: ./minify input.js [output.js]', 0x0A, 0
    error_open_input db 'Error: Cannot open input file', 0x0A, 0
    error_open_output db 'Error: Cannot open output file', 0x0A, 0
    error_read db 'Error: Cannot read input file', 0x0A, 0
    error_write db 'Error: Cannot write output file', 0x0A, 0
    
    ; Default output filename
    default_output db 'output.js', 0
    
    ; Buffers - explicitly sized for safety
    input_buffer times 65536 db 0
    output_buffer times 65536 db 0
    
section .text
    global _start

_start:
    ; Validate command line arguments
    pop rcx                     ; argc
    cmp rcx, 2
    jl .error_args              ; Need at least input file
    cmp rcx, 3
    jg .error_args              ; Max 3 args
    
    ; Process input filename
    pop rdi                     ; Skip program name
    pop rdi                     ; First arg (input file)
    
    ; Open input file - read only mode
    mov rax, 2                  ; sys_open
    mov rsi, 0                  ; O_RDONLY
    mov rdx, 0                  ; No special permissions needed
    syscall
    cmp rax, 0
    jl .error_open_input
    mov r8, rax                 ; Save input file descriptor
    
    ; Read input file with explicit size limit
    mov rdi, rax                ; fd
    mov rax, 0                  ; sys_read
    mov rsi, input_buffer
    mov rdx, 65536              ; Max buffer size
    syscall
    cmp rax, 0
    jl .error_read
    mov r9, rax                 ; Save actual input length
    
    ; Close input file immediately after reading
    mov rax, 3                  ; sys_close
    mov rdi, r8
    syscall
    
    ; Check if output filename was provided
    pop rcx                     ; Check for third argument
    test rcx, rcx
    jz .use_default_output
    
    mov rdi, rcx                ; Use provided output filename
    jmp .open_output
    
.use_default_output:
    lea rdi, [default_output]
    
.open_output:
    ; Open/Create output file with safe permissions
    mov rax, 2                  ; sys_open
    mov rsi, 0x241              ; O_CREAT|O_WRONLY|O_TRUNC
    mov rdx, 0o644              ; Standard file permissions (rw-r--r--)
    syscall
    cmp rax, 0
    jl .error_open_output
    mov r10, rax                ; Save output file descriptor
    
    ; ========== MINIFIER LOGIC ==========
    mov rsi, input_buffer       ; Source pointer
    mov rdi, output_buffer      ; Destination pointer
    mov rcx, r9                 ; Input length
    
    ; State tracking
    xor r11, r11                ; String state: 0=none, 1=', 2=", 3=`
    xor r12, r12                ; Comment state: 0=none, 1=//, 2=/* */
    xor r13, r13                ; Escape next char flag
    xor r14, r14                ; Last non-whitespace char
    xor r15, r15                ; Brace depth (0 = not in object/array)
    
.minify_loop:
    test rcx, rcx
    jz .minify_done
    
    mov al, [rsi]
    
    ; Handle comments first
    test r12, r12
    jnz .in_comment
    
    ; Handle strings
    test r11, r11
    jnz .in_string
    
    ; Not in string or comment
    cmp al, "'"
    je .start_string_single
    cmp al, '"'
    je .start_string_double
    cmp al, '`'
    je .start_string_template
    cmp al, '/'
    je .possible_comment
    
    ; Update brace depth tracking
    cmp al, '{'
    je .increase_brace_depth
    cmp al, '}'
    je .decrease_brace_depth
    cmp al, '['
    je .increase_brace_depth
    cmp al, ']'
    je .decrease_brace_depth
    
    ; Handle whitespace
    call .is_whitespace
    jc .handle_whitespace
    
    ; Handle regular character
    mov [rdi], al
    inc rdi
    
    ; Check if we need semicolon before this character
    mov bl, al
    mov r14, rbx                ; Save last char
    
    jmp .next_char

.handle_whitespace:
    ; Check what type of whitespace
    cmp al, 0x0A                ; Newline
    je .handle_newline
    cmp al, 0x0D                ; Carriage return
    je .handle_newline
    
    ; For spaces/tabs
    cmp al, ' '
    jne .skip_char
    
    ; Keep space between identifiers
    cmp rsi, input_buffer
    je .skip_char
    
    cmp rcx, 1
    je .skip_char
    
    mov bl, [rsi - 1]
    mov dl, [rsi + 1]
    
    call .is_identifier_char
    jnc .skip_char
    
    push rbx
    mov bl, dl
    call .is_identifier_char
    pop rbx
    jnc .skip_char
    
    mov byte [rdi], ' '
    inc rdi
    
.skip_char:
    inc rsi
    dec rcx
    jmp .minify_loop

.handle_newline:
    ; Check if we need semicolon at newline
    test r14, r14
    jz .skip_char                ; No last char
    
    ; Don't add semicolons inside object/array literals
    test r15, r15
    jnz .skip_char               ; Inside object/array
    
    ; Check last character to see if we need semicolon
    mov bl, r14b
    
    ; If last char was } ) ] " ' ` or identifier, we might need semicolon
    cmp bl, '}'
    je .maybe_add_semicolon
    cmp bl, ')'
    je .maybe_add_semicolon
    cmp bl, ']'
    je .maybe_add_semicolon
    cmp bl, '"'
    je .maybe_add_semicolon
    cmp bl, "'"
    je .maybe_add_semicolon
    cmp bl, '`'
    je .maybe_add_semicolon
    
    ; Check if last char was identifier char
    call .is_identifier_char
    jc .maybe_add_semicolon
    
    jmp .skip_char

.maybe_add_semicolon:
    ; Don't add if already has semicolon
    cmp rdi, output_buffer
    je .skip_char
    
    mov dl, [rdi - 1]
    cmp dl, ';'
    je .skip_char
    cmp dl, '{'
    je .skip_char
    
    ; Insert semicolon
    mov byte [rdi], ';'
    inc rdi
    jmp .skip_char

.increase_brace_depth:
    inc r15
    jmp .copy_char

.decrease_brace_depth:
    dec r15
    jmp .copy_char

.start_string_single:
    mov r11, 1
    jmp .copy_char

.start_string_double:
    mov r11, 2
    jmp .copy_char

.start_string_template:
    mov r11, 3
    jmp .copy_char

.copy_char:
    mov [rdi], al
    inc rdi
    mov r14, rax                ; Save last char
    jmp .next_char

.in_string:
    mov [rdi], al
    inc rdi
    mov r14, rax                ; Save last char
    
    cmp r13, 1
    je .reset_escape
    
    cmp al, '\'
    je .set_escape
    
    cmp r11, 1
    je .check_single_quote
    cmp r11, 2
    je .check_double_quote
    cmp r11, 3
    je .check_backtick
    
    jmp .next_char

.check_single_quote:
    cmp al, "'"
    jne .next_char
    xor r11, r11
    jmp .next_char

.check_double_quote:
    cmp al, '"'
    jne .next_char
    xor r11, r11
    jmp .next_char

.check_backtick:
    cmp al, '`'
    jne .next_char
    xor r11, r11
    jmp .next_char

.set_escape:
    mov r13, 1
    jmp .next_char

.reset_escape:
    mov r13, 0
    jmp .next_char

.possible_comment:
    cmp rcx, 1
    je .copy_char
    
    mov bl, [rsi + 1]
    cmp bl, '/'
    je .start_line_comment
    cmp bl, '*'
    je .start_block_comment
    
    mov [rdi], al
    inc rdi
    mov r14, rax                ; Save last char
    jmp .next_char

.start_line_comment:
    xor r14, r14                ; Reset last char for comment
    mov r12, 1
    add rsi, 2
    sub rcx, 2
    jmp .minify_loop

.start_block_comment:
    xor r14, r14                ; Reset last char for comment
    mov r12, 2
    add rsi, 2
    sub rcx, 2
    jmp .minify_loop

.in_comment:
    cmp r12, 1
    je .line_comment
    cmp r12, 2
    je .block_comment
    jmp .next_char

.line_comment:
    cmp al, 0x0A
    jne .skip_comment_char
    xor r12, r12
.skip_comment_char:
    inc rsi
    dec rcx
    jmp .minify_loop

.block_comment:
    cmp al, '*'
    jne .skip_comment_char
    cmp rcx, 1
    je .skip_comment_char
    mov bl, [rsi + 1]
    cmp bl, '/'
    jne .skip_comment_char
    xor r12, r12
    add rsi, 2
    sub rcx, 2
    jmp .minify_loop

.next_char:
    inc rsi
    dec rcx
    jmp .minify_loop

.minify_done:
    ; Calculate output length
    mov r11, rdi
    lea rdi, [output_buffer]
    sub r11, rdi
    
    ; Write output file
    mov rax, 1
    mov rdi, r10
    mov rsi, output_buffer
    mov rdx, r11
    syscall
    cmp rax, 0
    jl .error_write
    
    ; Close output file
    mov rax, 3
    mov rdi, r10
    syscall
    
    ; Clean exit
    mov rax, 60
    xor rdi, rdi
    syscall

; ========== HELPER FUNCTIONS ==========

.is_whitespace:
    cmp al, ' '
    je .is_ws_yes
    cmp al, 0x09
    je .is_ws_yes
    cmp al, 0x0A
    je .is_ws_yes
    cmp al, 0x0D
    je .is_ws_yes
    clc
    ret
.is_ws_yes:
    stc
    ret

.is_identifier_char:
    cmp bl, '0'
    jb .check_letters
    cmp bl, '9'
    jbe .is_id_yes
.check_letters:
    cmp bl, 'A'
    jb .check_lower
    cmp bl, 'Z'
    jbe .is_id_yes
.check_lower:
    cmp bl, 'a'
    jb .check_special
    cmp bl, 'z'
    jbe .is_id_yes
.check_special:
    cmp bl, '_'
    je .is_id_yes
    cmp bl, '$'
    je .is_id_yes
    clc
    ret
.is_id_yes:
    stc
    ret

; ========== ERROR HANDLERS ==========
.error_args:
    mov rax, 1
    mov rdi, 2
    lea rsi, [error_args]
    mov rdx, 37
    syscall
    jmp .exit_with_error

.error_open_input:
    mov rax, 1
    mov rdi, 2
    lea rsi, [error_open_input]
    mov rdx, 32
    syscall
    jmp .exit_with_error

.error_open_output:
    mov rax, 1
    mov rdi, 2
    lea rsi, [error_open_output]
    mov rdx, 33
    syscall
    jmp .exit_with_error

.error_read:
    mov rax, 1
    mov rdi, 2
    lea rsi, [error_read]
    mov rdx, 30
    syscall
    jmp .exit_with_error

.error_write:
    mov rax, 1
    mov rdi, 2
    lea rsi, [error_write]
    mov rdx, 31
    syscall
    jmp .exit_with_error

.exit_with_error:
    mov rax, 60
    mov rdi, 1
    syscall