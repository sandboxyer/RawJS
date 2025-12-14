section .data
    ; ========== CONSTANTS AND PATHS ==========
    ; MODIFY THIS PATH IF JS LEVELS ARE IN DIFFERENT LOCATION
    jslevels_dir db './jslevels/', 0
    
    ; File patterns for each level (MODIFY IF FILE NAMING CHANGES)
    level_files:
        dq level1_file, level2_file, level3_file, level4_file
        ; ADD MORE LEVEL POINTERS HERE AS NEEDED
        ; dq level5_file, level6_file, etc.
    
    level1_file db '1.js', 0
    level2_file db '2.js', 0
    level3_file db '3.js', 0
    level4_file db '4.js', 0
    ; SPACE FOR FUTURE LEVELS (UNCOMMENT AND ADD AS NEEDED)
    ; level5_file db '5.js', 0
    ; level6_file db '6.js', 0
    
    ; Shell script file patterns
    level1_script db '1.sh', 0
    level2_script db '2.sh', 0
    level3_script db '3.sh', 0
    level4_script db '4.sh', 0
    
    ; ========== COMMAND STRINGS ==========
    ; Global commands that must be in PATH
    nasm_cmd db 'nasm', 0
    node_cmd db 'node', 0
    bash_cmd db 'bash', 0
    min_asm_file db 'min.asm', 0
    default_output_file db 'output.js', 0
    mv_cmd db 'mv', 0
    cd_cmd db 'cd', 0
    
    ; ========== TEMPORARY FILES ==========
    temp_js_output db 'test_output.js', 0  ; Temporary output for testing
    
    ; ========== TEST STATUS MESSAGES ==========
    test_start_msg db '🚀 STARTING JAVASCRIPT MINIFICATION TEST SUITE', 0x0A, 0
    test_divider db '══════════════════════════════════════════════════', 0x0A, 0
    level_test_msg db '🧪 Testing Level ', 0
    checking_file_msg db '   📁 Checking level file... ', 0
    generating_js_msg db '   🔧 Generating JS from shell script... ', 0
    moving_file_msg db '   📂 Moving JS file to jslevels directory... ', 0
    running_minify_msg db '   ⚡ Running minifier... ', 0
    testing_output_msg db '   🔍 Testing minified output... ', 0
    file_ok_msg db 'OK', 0x0A, 0
    file_missing_msg db 'MISSING', 0x0A, 0
    generating_ok_msg db 'OK', 0x0A, 0
    generating_fail_msg db 'FAILED', 0x0A, 0
    move_ok_msg db 'OK', 0x0A, 0
    move_fail_msg db 'FAILED', 0x0A, 0
    minify_ok_msg db 'OK', 0x0A, 0
    minify_fail_msg db 'FAILED', 0x0A, 0
    test_pass_msg db '   ✅ TEST PASSED - Minified code runs correctly', 0x0A, 0
    test_fail_msg db '   ❌ TEST FAILED', 0x0A, 0
    test_error_detail db '     Error: ', 0
    
    ; Error messages
    error_file_not_found db 'Level file not found and script missing', 0x0A, 0
    error_script_not_found db 'Shell script not found', 0x0A, 0
    error_script_failed db 'Shell script failed to generate JS', 0x0A, 0
    error_move_failed db 'Failed to move JS file to jslevels directory', 0x0A, 0
    error_minify_failed db 'Minification failed', 0x0A, 0
    error_syntax db 'Syntax error in minified code', 0x0A, 0
    error_runtime db 'Runtime error in minified code', 0x0A, 0
    error_node_not_found db 'Node.js command failed', 0x0A, 0
    
    test_summary_start db 0x0A, '📊 TEST SUMMARY:', 0x0A, 0
    summary_divider db '──────────────────────────────────────────────', 0x0A, 0
    summary_passed db '   ✅ Passed: ', 0
    summary_failed db '   ❌ Failed: ', 0
    summary_total db '   📋 Total: ', 0
    
    all_tests_passed db 0x0A, '🎉 ALL TESTS PASSED!', 0x0A, 0
    some_tests_failed db 0x0A, '⚠️ SOME TESTS FAILED', 0x0A, 0
    
    ; ========== COMMAND BUFFERS ==========
    ; Buffer for building command strings
    cmd_buffer times 512 db 0
    cmd_buffer2 times 512 db 0
    
    ; Buffer for file paths
    input_path times 256 db 0
    script_path times 256 db 0
    temp_js_path times 256 db 0
    current_dir_path times 256 db 0
    
    ; Level number as string
    level_str times 16 db 0
    level_js_file times 32 db 0
    
    ; ========== TEST COUNTERS ==========
    tests_passed dd 0
    tests_failed dd 0
    total_tests dd 0
    
    ; Current level being tested
    current_level dd 0
    
    ; ========== FORMATTING ==========
    newline db 0x0A, 0
    space db ' ', 0
    colon_space db ': ', 0

section .bss
    ; File descriptors for checking file existence
    check_fd resq 1
    
    ; Process IDs
    child_pid resq 1
    exit_status resd 1
    
    ; Command execution buffer
    argv_ptr resq 4
    env_ptr resq 1

section .text
    global _start

; ========== MAIN TEST SUITE ==========
_start:
    ; Initialize test counters
    mov dword [tests_passed], 0
    mov dword [tests_failed], 0
    mov dword [total_tests], 0
    
    ; Print test suite header
    mov rsi, test_start_msg
    call print_string
    mov rsi, test_divider
    call print_string
    
    ; ========== TEST INITIAL 4 LEVELS ==========
    mov dword [current_level], 1
.level_loop:
    mov edi, [current_level]
    cmp edi, 5                    ; Test levels 1-4
    jge .level_testing_done
    
    call test_single_level
    
    inc dword [current_level]
    jmp .level_loop

.level_testing_done:
    ; ========== MODULAR EXPANSION POINT ==========
    ; TO ADD MORE LEVELS, MODIFY THE .level_loop COMPARISON ABOVE
    ; AND ADD MORE FILE POINTERS IN THE level_files ARRAY
    
    ; Example for testing 6 levels instead of 4:
    ; cmp edi, 7                    ; Test levels 1-6
    ; ...
    
    ; ========== PRINT TEST SUMMARY ==========
    call print_test_summary
    
    ; ========== EXIT WITH APPROPRIATE CODE ==========
    mov eax, [tests_failed]
    test eax, eax
    jnz .exit_with_failures
    
    ; All tests passed
    mov rsi, all_tests_passed
    call print_string
    mov rax, 60                 ; sys_exit
    xor rdi, rdi                ; exit code 0
    syscall

.exit_with_failures:
    mov rsi, some_tests_failed
    call print_string
    mov rax, 60                 ; sys_exit
    mov rdi, 1                  ; exit code 1
    syscall

; ========== TEST A SINGLE LEVEL ==========
; Input: EDI = level number
test_single_level:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12d, edi               ; Save level number
    
    ; Increment total test count
    inc dword [total_tests]
    
    ; Print level header
    mov rsi, level_test_msg
    call print_string
    
    mov edi, r12d
    mov rsi, level_str
    call int_to_string
    mov rsi, level_str
    call print_string
    mov rsi, newline
    call print_string
    
    ; ========== STEP 1: CHECK IF JS FILE EXISTS ==========
    mov rsi, checking_file_msg
    call print_string
    
    ; Build JS file path: ./jslevels/X.js
    lea rdi, [input_path]
    lea rsi, [jslevels_dir]
    call string_copy
    
    ; Save the target JS path for later
    lea r14, [input_path]       ; R14 = target JS file path
    
    ; Get filename from level_files array
    mov eax, r12d
    dec eax                    ; Convert to 0-based index
    shl eax, 3                 ; Multiply by 8 (pointer size)
    lea rbx, [level_files]
    mov rsi, [rbx + rax]       ; Get pointer to filename
    call string_concatenate
    
    ; Check if JS file exists in jslevels directory
    mov rax, 2                  ; sys_open
    lea rdi, [input_path]
    mov rsi, 0                  ; O_RDONLY
    syscall
    
    cmp rax, 0
    jge .js_file_exists
    
    ; JS file doesn't exist, try to generate it from shell script
    jmp .generate_js_from_script

.js_file_exists:
    ; File exists, close it
    mov rdi, rax
    mov rax, 3                  ; sys_close
    syscall
    
    mov rsi, file_ok_msg
    call print_string
    jmp .run_minification

.generate_js_from_script:
    ; ========== STEP 1a: GENERATE JS FROM SHELL SCRIPT ==========
    mov rsi, file_missing_msg
    call print_string
    
    mov rsi, generating_js_msg
    call print_string
    
    ; Build shell script path: ./jslevels/X.sh
    lea rdi, [script_path]
    lea rsi, [jslevels_dir]
    call string_copy
    
    ; Get script filename based on level number
    mov eax, r12d
    cmp eax, 1
    je .script1
    cmp eax, 2
    je .script2
    cmp eax, 3
    je .script3
    cmp eax, 4
    je .script4
    ; Add more cases for additional levels
    jmp .script_not_found

.script1:
    lea rsi, [level1_script]
    jmp .add_script_name
.script2:
    lea rsi, [level2_script]
    jmp .add_script_name
.script3:
    lea rsi, [level3_script]
    jmp .add_script_name
.script4:
    lea rsi, [level4_script]
    jmp .add_script_name
    ; Add more script labels for additional levels

.add_script_name:
    call string_concatenate
    
    ; Check if shell script exists
    mov rax, 2                  ; sys_open
    lea rdi, [script_path]
    mov rsi, 0                  ; O_RDONLY
    syscall
    
    cmp rax, 0
    jl .script_not_found
    
    ; Script exists, close it
    mov rdi, rax
    mov rax, 3                  ; sys_close
    syscall
    
    ; Execute shell script to generate JS file
    ; Build command: cd ./jslevels && bash X.sh
    lea rdi, [cmd_buffer]
    
    ; First, change to jslevels directory
    lea rsi, [cd_cmd]
    call string_copy
    
    ; Add space
    mov byte [rdi], ' '
    inc rdi
    
    ; Add jslevels directory
    lea rsi, [jslevels_dir]
    call string_concatenate
    
    ; Add && bash X.sh
    lea rsi, [and_bash]
    call string_concatenate
    
    ; Add space
    mov byte [rdi], ' '
    inc rdi
    
    ; Add bash command
    lea rsi, [bash_cmd]
    call string_concatenate
    
    ; Add space
    mov byte [rdi], ' '
    inc rdi
    
    ; Add script filename only (not full path since we cd to directory)
    mov eax, r12d
    cmp eax, 1
    je .script_name1
    cmp eax, 2
    je .script_name2
    cmp eax, 3
    je .script_name3
    cmp eax, 4
    je .script_name4
    ; Add more cases

.script_name1:
    lea rsi, [level1_script]
    jmp .add_script_name_only
.script_name2:
    lea rsi, [level2_script]
    jmp .add_script_name_only
.script_name3:
    lea rsi, [level3_script]
    jmp .add_script_name_only
.script_name4:
    lea rsi, [level4_script]
    jmp .add_script_name_only

.add_script_name_only:
    call string_concatenate
    
    ; Execute the shell script
    lea rdi, [cmd_buffer]
    call execute_shell_command
    
    test rax, rax
    jnz .script_execution_failed
    
    ; ========== STEP 1b: CHECK IF JS WAS CREATED AND MOVE IF NEEDED ==========
    ; First check if JS file was created in jslevels directory
    mov rax, 2                  ; sys_open
    lea rdi, [input_path]       ; Check the target path (jslevels/X.js)
    mov rsi, 0                  ; O_RDONLY
    syscall
    
    cmp rax, 0
    jge .js_created_in_right_place
    
    ; JS not in jslevels, check if created in current directory
    ; Build JS file path in current directory: X.js
    lea rdi, [temp_js_path]
    
    ; Create levelX.js filename
    mov eax, r12d
    cmp eax, 1
    je .js_name1
    cmp eax, 2
    je .js_name2
    cmp eax, 3
    je .js_name3
    cmp eax, 4
    je .js_name4

.js_name1:
    lea rsi, [level1_file]
    jmp .build_js_name
.js_name2:
    lea rsi, [level2_file]
    jmp .build_js_name
.js_name3:
    lea rsi, [level3_file]
    jmp .build_js_name
.js_name4:
    lea rsi, [level4_file]
    jmp .build_js_name

.build_js_name:
    call string_copy
    
    ; Check if JS file exists in current directory
    mov rax, 2                  ; sys_open
    lea rdi, [temp_js_path]
    mov rsi, 0                  ; O_RDONLY
    syscall
    
    cmp rax, 0
    jl .script_didnt_create_js
    
    ; File exists in current directory, close it
    mov rdi, rax
    mov rax, 3                  ; sys_close
    syscall
    
    ; Move it to jslevels directory
    mov rsi, moving_file_msg
    call print_string
    
    ; Build move command: mv X.js ./jslevels/
    lea rdi, [cmd_buffer2]
    
    ; Add mv command
    lea rsi, [mv_cmd]
    call string_copy
    
    ; Add space
    mov byte [rdi], ' '
    inc rdi
    
    ; Add source file (in current directory)
    lea rsi, [temp_js_path]
    call string_concatenate
    
    ; Add space
    mov byte [rdi], ' '
    inc rdi
    
    ; Add destination directory
    lea rsi, [jslevels_dir]
    call string_concatenate
    
    ; Execute move command
    lea rdi, [cmd_buffer2]
    call execute_shell_command
    
    test rax, rax
    jnz .move_failed
    
    mov rsi, move_ok_msg
    call print_string
    
    ; Now check again if file is in jslevels
    mov rax, 2                  ; sys_open
    lea rdi, [input_path]       ; Check the target path
    mov rsi, 0                  ; O_RDONLY
    syscall
    
    cmp rax, 0
    jl .move_didnt_work
    
    ; Success! Close file
    mov rdi, rax
    mov rax, 3                  ; sys_close
    syscall
    
    mov rsi, generating_ok_msg
    call print_string
    jmp .run_minification

.js_created_in_right_place:
    ; JS already in correct location, close file
    mov rdi, rax
    mov rax, 3                  ; sys_close
    syscall
    
    mov rsi, generating_ok_msg
    call print_string
    jmp .run_minification

.script_not_found:
    mov rsi, generating_fail_msg
    call print_string
    mov rsi, test_fail_msg
    call print_string
    mov rsi, error_script_not_found
    call print_error_detail
    inc dword [tests_failed]
    jmp .test_complete

.script_execution_failed:
    mov rsi, generating_fail_msg
    call print_string
    mov rsi, test_fail_msg
    call print_string
    mov rsi, error_script_failed
    call print_error_detail
    inc dword [tests_failed]
    jmp .test_complete

.script_didnt_create_js:
    mov rsi, generating_fail_msg
    call print_string
    mov rsi, test_fail_msg
    call print_string
    mov rsi, error_script_failed
    call print_error_detail
    inc dword [tests_failed]
    jmp .test_complete

.move_failed:
    mov rsi, move_fail_msg
    call print_string
    mov rsi, test_fail_msg
    call print_string
    mov rsi, error_move_failed
    call print_error_detail
    inc dword [tests_failed]
    jmp .test_complete

.move_didnt_work:
    mov rsi, move_fail_msg
    call print_string
    mov rsi, test_fail_msg
    call print_string
    mov rsi, error_move_failed
    call print_error_detail
    inc dword [tests_failed]
    jmp .test_complete

.run_minification:
    ; ========== STEP 2: RUN MINIFIER ==========
    mov rsi, running_minify_msg
    call print_string
    
    ; Build command: nasm min.asm <input_path>
    lea rdi, [cmd_buffer]
    
    ; Add nasm command
    lea rsi, [nasm_cmd]
    call string_copy
    
    ; Add space
    mov byte [rdi], ' '
    inc rdi
    
    ; Add min.asm
    lea rsi, [min_asm_file]
    call string_concatenate
    
    ; Add space
    mov byte [rdi], ' '
    inc rdi
    
    ; Add input file path (should be ./jslevels/X.js)
    lea rsi, [input_path]
    call string_concatenate
    
    ; Execute nasm command
    lea rdi, [cmd_buffer]
    call execute_shell_command
    
    test rax, rax
    jnz .minify_failed
    
    mov rsi, minify_ok_msg
    call print_string
    
    ; ========== STEP 3: TEST MINIFIED OUTPUT ==========
    mov rsi, testing_output_msg
    call print_string
    
    ; Check if output.js was created
    mov rax, 2                  ; sys_open
    lea rdi, [default_output_file]
    mov rsi, 0                  ; O_RDONLY
    syscall
    
    cmp rax, 0
    jl .output_not_created
    
    ; Close output file
    mov rdi, rax
    mov rax, 3                  ; sys_close
    syscall
    
    ; Build command: node output.js
    lea rdi, [cmd_buffer]
    
    ; Add node command
    lea rsi, [node_cmd]
    call string_copy
    
    ; Add space
    mov byte [rdi], ' '
    inc rdi
    
    ; Add output.js
    lea rsi, [default_output_file]
    call string_concatenate
    
    ; Execute node command
    lea rdi, [cmd_buffer]
    call execute_shell_command
    
    ; Check result
    cmp rax, 0
    je .test_passed
    
    ; Node failed - determine error type
    cmp rax, 1                  ; Syntax error typically returns 1
    je .syntax_error
    jmp .runtime_error

.test_passed:
    mov rsi, test_pass_msg
    call print_string
    inc dword [tests_passed]
    
    ; Clean up output.js for next test
    lea rdi, [default_output_file]
    call delete_file
    jmp .test_complete

.minify_failed:
    mov rsi, minify_fail_msg
    call print_string
    mov rsi, test_fail_msg
    call print_string
    mov rsi, error_minify_failed
    call print_error_detail
    inc dword [tests_failed]
    jmp .test_complete

.output_not_created:
    mov rsi, minify_fail_msg
    call print_string
    mov rsi, test_fail_msg
    call print_string
    mov rsi, error_minify_failed
    call print_error_detail
    inc dword [tests_failed]
    jmp .test_complete

.syntax_error:
    mov rsi, minify_ok_msg      ; Minification succeeded
    call print_string
    mov rsi, test_fail_msg
    call print_string
    mov rsi, error_syntax
    call print_error_detail
    inc dword [tests_failed]
    
    ; Clean up output.js
    lea rdi, [default_output_file]
    call delete_file
    jmp .test_complete

.runtime_error:
    mov rsi, minify_ok_msg      ; Minification succeeded
    call print_string
    mov rsi, test_fail_msg
    call print_string
    mov rsi, error_runtime
    call print_error_detail
    inc dword [tests_failed]
    
    ; Clean up output.js
    lea rdi, [default_output_file]
    call delete_file

.test_complete:
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; ========== PRINT ERROR DETAIL ==========
print_error_detail:
    push rbp
    mov rbp, rsp
    
    mov rax, 1                  ; sys_write
    mov rdi, 1                  ; stdout
    mov rsi, test_error_detail
    mov rdx, 11                 ; "     Error: "
    syscall
    
    ; Print actual error message
    call print_string
    
    mov rsp, rbp
    pop rbp
    ret

; ========== PRINT TEST SUMMARY ==========
print_test_summary:
    push rbp
    mov rbp, rsp
    
    mov rsi, test_summary_start
    call print_string
    mov rsi, summary_divider
    call print_string
    
    ; Print passed tests
    mov rsi, summary_passed
    call print_string
    mov edi, [tests_passed]
    mov rsi, level_str
    call int_to_string
    mov rsi, level_str
    call print_string
    mov rsi, newline
    call print_string
    
    ; Print failed tests
    mov rsi, summary_failed
    call print_string
    mov edi, [tests_failed]
    mov rsi, level_str
    call int_to_string
    mov rsi, level_str
    call print_string
    mov rsi, newline
    call print_string
    
    ; Print total tests
    mov rsi, summary_total
    call print_string
    mov edi, [total_tests]
    mov rsi, level_str
    call int_to_string
    mov rsi, level_str
    call print_string
    mov rsi, newline
    call print_string
    
    mov rsi, summary_divider
    call print_string
    
    mov rsp, rbp
    pop rbp
    ret

; ========== HELPER FUNCTIONS ==========

; Print string pointed by RSI
print_string:
    push rbp
    mov rbp, rsp
    push rbx
    
    mov rbx, rsi
    call string_length
    
    mov rdx, rax                ; length in RAX
    test rdx, rdx
    jz .print_done
    
    mov rax, 1                  ; sys_write
    mov rdi, 1                  ; stdout
    mov rsi, rbx
    syscall

.print_done:
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; Get string length in RAX
string_length:
    xor rax, rax
.string_length_loop:
    cmp byte [rsi + rax], 0
    je .string_length_done
    inc rax
    jmp .string_length_loop
.string_length_done:
    ret

; Copy string from RSI to RDI
string_copy:
    push rbp
    mov rbp, rsp
.string_copy_loop:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    jz .string_copy_done
    inc rsi
    inc rdi
    jmp .string_copy_loop
.string_copy_done:
    mov rsp, rbp
    pop rbp
    ret

; Concatenate string from RSI to RDI (assumes RDI points to string end)
string_concatenate:
    push rbp
    mov rbp, rsp
.string_concat_loop:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    jz .string_concat_done
    inc rsi
    inc rdi
    jmp .string_concat_loop
.string_concat_done:
    mov rsp, rbp
    pop rbp
    ret

; Convert integer in EDI to string at RSI
int_to_string:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    mov eax, edi
    mov rbx, 10
    mov r12, rsi
    mov rcx, 0
    
    ; Handle zero case
    test eax, eax
    jnz .convert_loop
    mov byte [r12], '0'
    mov byte [r12 + 1], 0
    jmp .int_to_string_done
    
    ; Handle negative numbers (shouldn't happen with levels)
    cmp eax, 0
    jge .positive
    neg eax
    mov byte [r12], '-'
    inc r12
.positive:
    
.convert_loop:
    xor edx, edx
    div ebx
    add dl, '0'
    push rdx
    inc rcx
    test eax, eax
    jnz .convert_loop
    
    ; Pop digits into string
    mov rdi, r12
.pop_digits:
    pop rax
    mov [rdi], al
    inc rdi
    loop .pop_digits
    mov byte [rdi], 0
    
.int_to_string_done:
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; Execute shell command in RDI using /bin/sh -c
; Returns: RAX = exit code (0 = success)
execute_shell_command:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov r12, rdi                ; Save command string
    
    ; Fork process
    mov rax, 57                 ; sys_fork
    syscall
    
    test rax, rax
    jz .child_process
    
    ; Parent process - wait for child
    mov [child_pid], rax
    
    mov rax, 61                 ; sys_wait4
    mov rdi, [child_pid]
    lea rsi, [exit_status]
    xor rdx, rdx
    xor r10, r10
    syscall
    
    ; Get exit status
    mov eax, [exit_status]
    shr eax, 8                  ; Exit code is in high byte
    jmp .execute_done

.child_process:
    ; Child process - execute command via /bin/sh
    ; Prepare arguments for execve
    
    ; argv[0] = "sh"
    lea rax, [sh_path]
    mov [argv_ptr], rax
    
    ; argv[1] = "-c"
    lea rax, [sh_c_flag]
    mov [argv_ptr + 8], rax
    
    ; argv[2] = command string
    mov [argv_ptr + 16], r12
    
    ; argv[3] = NULL
    mov qword [argv_ptr + 24], 0
    
    ; envp[0] = NULL
    mov qword [env_ptr], 0
    
    ; Execute /bin/sh -c "command"
    mov rax, 59                 ; sys_execve
    lea rdi, [sh_path]
    lea rsi, [argv_ptr]
    lea rdx, [env_ptr]
    syscall
    
    ; If execve fails, exit with error
    mov rax, 60                 ; sys_exit
    mov rdi, 1
    syscall

.execute_done:
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; Delete file at path in RDI
delete_file:
    push rbp
    mov rbp, rsp
    
    mov rax, 87                 ; sys_unlink
    syscall
    
    mov rsp, rbp
    pop rbp
    ret

; ========== SYSTEM COMMAND DATA ==========
section .data
    sh_path db '/bin/sh', 0
    sh_c_flag db '-c', 0
    and_bash db '&&', 0
