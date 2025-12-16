section .data
    filename db "./build_output.asm", 0
    template db "; =========================================================", 10
             db "; JS-LIKE ASSEMBLY TEMPLATE - Advanced JavaScript Patterns", 10
             db "; =========================================================", 10, 10
             
             db "; 1. CONSTANTS SECTION (like JavaScript const)", 10
             db "; =========================================================", 10
             db "section .data", 10
             db "    ; === COMPILE-TIME CONSTANTS (const in JS) ===", 10
             db "    ; Example: const MAX_SIZE = 100;", 10
             db "    ; const NULL = 0;", 10
             db "    ; const PI = 3.14159265", 10, 10
             
             db "    ; === READ-ONLY STRINGS (const strings) ===", 10
             db "    ; Example: const MSG = 'Hello';", 10
             db "    ; const ERROR_MSG = 'Error occurred';", 10, 10
             
             db "; 2. GLOBAL VARIABLES SECTION", 10
             db "; =========================================================", 10
             db "    ; === GLOBAL LET VARIABLES (let at global scope) ===", 10
             db "    ; Example: let counter = 0;", 10
             db "    ; let isActive = true;", 10
             db "    ; let userName = '';", 10, 10
             
             db "    ; === GLOBAL VAR VARIABLES (var at global scope) ===", 10
             db "    ; Example: var oldStyle = 'hoisted';", 10
             db "    ; var globalState = null;", 10, 10
             
             db "    ; === FUNCTION POINTERS (Function references) ===", 10
             db "    ; Example: const fn = function() {};", 10
             db "    ; let callback = null;", 10
             db "    ; fn_ptr dq 0", 10
             db "    ; cb_ptr dq 0", 10, 10
             
             db "; 3. OBJECT STRUCTURE DEFINITIONS", 10
             db "; =========================================================", 10
             db "    ; === OBJECT LAYOUTS (Struct templates) ===", 10
             db "    ; Example: const person = {name: '', age: 0};", 10
             db "    ; struct Person:", 10
             db "    ;   .name_ptr dq 0   ; string pointer", 10
             db "    ;   .age dq 0        ; integer", 10
             db "    ;   .next dq 0       ; pointer to next object", 10
             db "    ;   .prev dq 0       ; pointer to previous object", 10
             db "    ;   .methods dq 0    ; function table", 10, 10
             
             db "    ; === ARRAY STRUCTURES ===", 10
             db "    ; Example: const arr = [1, 2, 3];", 10
             db "    ; struct Array:", 10
             db "    ;   .data_ptr dq 0   ; pointer to data", 10
             db "    ;   .length dq 0     ; number of elements", 10
             db "    ;   .capacity dq 0   ; allocated capacity", 10, 10
             
             db "; 4. UNINITIALIZED DATA SECTION", 10
             db "; =========================================================", 10
             db "section .bss", 10
             db "    ; === UNINITIALIZED LET VARIABLES ===", 10
             db "    ; Example: let buffer;", 10
             db "    ; let tempValue;", 10, 10
             
             db "    ; === BUFFERS & ARRAYS ===", 10
             db "    ; Example: let buffer = new ArrayBuffer(256);", 10
             db "    ; const arr = new Array(10);", 10, 10
             
             db "    ; === OBJECT INSTANCES ===", 10
             db "    ; Example: let obj = {};", 10
             db "    ; obj_instance: resb person_size", 10
             db "    ; obj_array: resb 100*person_size", 10, 10
             
             db "; 5. CODE SECTION - Functions and Main Program", 10
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
             
             db "; === VARIABLE DECLARATION PATTERNS ===", 10
             db "; Pattern 1: const declaration", 10
             db ";   JavaScript: const MAX = 100;", 10
             db ";   Assembly:   MAX equ 100", 10, 10
             
             db "; Pattern 2: let with initialization", 10
             db ";   JavaScript: let count = 0;", 10
             db ";   Assembly:   count dq 0", 10, 10
             
             db "; Pattern 3: let without initialization", 10
             db ";   JavaScript: let temp;", 10
             db ";   Assembly:   temp resq 1", 10, 10
             
             db "; Pattern 4: var declaration (function-scoped)", 10
             db ";   JavaScript: var globalVar = 'hello';", 10
             db ";   Assembly:   globalVar dq 'hello'", 10, 10
             
             db "; === FUNCTION DECLARATION PATTERNS ===", 10
             db "; Pattern 5: Regular function", 10
             db ";   JavaScript: function add(a, b) { return a + b; }", 10
             db ";   Assembly:", 10
             db ";   add_function:", 10
             db ";       push rbp", 10
             db ";       mov rbp, rsp", 10
             db ";       ; a = [rbp+16], b = [rbp+24] (cdecl calling convention)", 10
             db ";       mov rax, [rbp+16]", 10
             db ";       add rax, [rbp+24]", 10
             db ";       pop rbp", 10
             db ";       ret", 10, 10
             
             db "; Pattern 6: Arrow function assigned to const", 10
             db ";   JavaScript: const multiply = (x, y) => x * y;", 10
             db ";   Assembly:", 10
             db ";   multiply:", 10
             db ";       push rbp", 10
             db ";       mov rbp, rsp", 10
             db ";       mov rax, [rbp+16]    ; x", 10
             db ";       imul rax, [rbp+24]   ; x * y", 10
             db ";       pop rbp", 10
             db ";       ret", 10
             db ";   ; Store function pointer:", 10
             db ";   multiply_ptr dq multiply", 10, 10
             
             db "; Pattern 7: Function expression assigned to let", 10
             db ";   JavaScript: let divide = function(a, b) { return a / b; };", 10
             db ";   Assembly:", 10
             db ";   divide_func:", 10
             db ";       push rbp", 10
             db ";       mov rbp, rsp", 10
             db ";       mov rax, [rbp+16]", 10
             db ";       xor rdx, rdx", 10
             db ";       idiv qword [rbp+24]", 10
             db ";       pop rbp", 10
             db ";       ret", 10
             db ";   divide_ptr dq divide_func", 10, 10
             
             db "; === OBJECT PATTERNS ===", 10
             db "; Pattern 8: Simple object creation", 10
             db ";   JavaScript: const person = {name: 'John', age: 30};", 10
             db ";   Assembly:", 10
             db ";   person_name db 'John', 0", 10
             db ";   person_age dq 30", 10
             db ";   person_next dq 0", 10
             db ";   person_prev dq 0", 10, 10
             
             db "; Pattern 9: Object with methods", 10
             db ";   JavaScript:", 10
             db ";   const calculator = {", 10
             db ";       add: function(a, b) { return a + b; }", 10
             db ";   };", 10
             db ";   Assembly:", 10
             db ";   calc_add_ptr dq add_function", 10
             db ";   calculator dq calc_add_ptr", 10, 10
             
             db "; Pattern 10: Nested objects", 10
             db ";   JavaScript:", 10
             db ";   const company = {", 10
             db ";       name: 'Tech Corp',", 10
             db ";       address: {", 10
             db ";           street: '123 Main',", 10
             db ";           city: 'NYC'", 10
             db ";       }", 10
             db ";   };", 10
             db ";   Assembly:", 10
             db ";   company_name db 'Tech Corp', 0", 10
             db ";   address_street db '123 Main', 0", 10
             db ";   address_city db 'NYC', 0", 10, 10
             
             db "; Pattern 11: Object chain (linked list pattern)", 10
             db ";   JavaScript:", 10
             db ";   const node1 = {value: 1, next: node2};", 10
             db ";   const node2 = {value: 2, next: node3};", 10
             db ";   const node3 = {value: 3, next: null};", 10
             db ";   Assembly:", 10
             db ";   node1_value dq 1", 10
             db ";   node1_next dq node2", 10
             db ";   node2_value dq 2", 10
             db ";   node2_next dq node3", 10
             db ";   node3_value dq 3", 10
             db ";   node3_next dq 0", 10, 10
             
             db "; === CONTROL FLOW PATTERNS ===", 10
             db "; Pattern 12: Simple if statement", 10
             db ";   JavaScript: if (x > 0) { /* do something */ }", 10
             db ";   Assembly:", 10
             db ";       cmp [x], 0", 10
             db ";       jle .skip_if", 10
             db ";       ; if body here", 10
             db ";   .skip_if:", 10, 10
             
             db "; Pattern 13: if-else statement", 10
             db ";   JavaScript:", 10
             db ";   if (x > 0) {", 10
             db ";       // positive", 10
             db ";   } else {", 10
             db ";       // non-positive", 10
             db ";   }", 10
             db ";   Assembly:", 10
             db ";       cmp [x], 0", 10
             db ";       jle .else_block", 10
             db ";       ; if body here", 10
             db ";       jmp .endif", 10
             db ";   .else_block:", 10
             db ";       ; else body here", 10
             db ";   .endif:", 10, 10
             
             db "; Pattern 14: if-else if-else chain", 10
             db ";   JavaScript:", 10
             db ";   if (score >= 90) { grade = 'A'; }", 10
             db ";   else if (score >= 80) { grade = 'B'; }", 10
             db ";   else { grade = 'C'; }", 10
             db ";   Assembly:", 10
             db ";       cmp [score], 90", 10
             db ";       jl .check_b", 10
             db ";       mov [grade], 'A'", 10
             db ";       jmp .grade_done", 10
             db ";   .check_b:", 10
             db ";       cmp [score], 80", 10
             db ";       jl .grade_c", 10
             db ";       mov [grade], 'B'", 10
             db ";       jmp .grade_done", 10
             db ";   .grade_c:", 10
             db ";       mov [grade], 'C'", 10
             db ";   .grade_done:", 10, 10
             
             db "; Pattern 15: Ternary operator", 10
             db ";   JavaScript: const result = condition ? value1 : value2;", 10
             db ";   Assembly:", 10
             db ";       cmp [condition], 0", 10
             db ";       je .false_case", 10
             db ";       mov rax, value1", 10
             db ";       jmp .ternary_end", 10
             db ";   .false_case:", 10
             db ";       mov rax, value2", 10
             db ";   .ternary_end:", 10
             db ";       mov [result], rax", 10, 10
             
             db "; Pattern 16: Switch statement", 10
             db ";   JavaScript:", 10
             db ";   switch(day) {", 10
             db ";       case 1: name = 'Monday'; break;", 10
             db ";       case 2: name = 'Tuesday'; break;", 10
             db ";       default: name = 'Unknown';", 10
             db ";   }", 10
             db ";   Assembly:", 10
             db ";       cmp [day], 1", 10
             db ";       je .case1", 10
             db ";       cmp [day], 2", 10
             db ";       je .case2", 10
             db ";       jmp .default", 10
             db ";   .case1:", 10
             db ";       mov [name], 'Monday'", 10
             db ";       jmp .switch_end", 10
             db ";   .case2:", 10
             db ";       mov [name], 'Tuesday'", 10
             db ";       jmp .switch_end", 10
             db ";   .default:", 10
             db ";       mov [name], 'Unknown'", 10
             db ";   .switch_end:", 10, 10
             
             db "; === LOOP PATTERNS ===", 10
             db "; Pattern 17: Basic for loop", 10
             db ";   JavaScript: for(let i = 0; i < 10; i++) { /* loop body */ }", 10
             db ";   Assembly:", 10
             db ";       mov qword [i], 0          ; i = 0", 10
             db ";   .for_start:", 10
             db ";       cmp qword [i], 10         ; i < 10", 10
             db ";       jge .for_end", 10
             db ";       ; loop body here", 10
             db ";       inc qword [i]             ; i++", 10
             db ";       jmp .for_start", 10
             db ";   .for_end:", 10, 10
             
             db "; Pattern 18: For loop with step", 10
             db ";   JavaScript: for(let i = 0; i < 100; i += 5) { }", 10
             db ";   Assembly:", 10
             db ";       mov qword [i], 0", 10
             db ";   .for_loop:", 10
             db ";       cmp qword [i], 100", 10
             db ";       jge .for_end", 10
             db ";       ; body", 10
             db ";       add qword [i], 5", 10
             db ";       jmp .for_loop", 10
             db ";   .for_end:", 10, 10
             
             db "; Pattern 19: While loop", 10
             db ";   JavaScript: while(condition) { /* loop body */ }", 10
             db ";   Assembly:", 10
             db ";   .while_start:", 10
             db ";       cmp [condition], 0", 10
             db ";       je .while_end", 10
             db ";       ; loop body", 10
             db ";       jmp .while_start", 10
             db ";   .while_end:", 10, 10
             
             db "; Pattern 20: Do-while loop", 10
             db ";   JavaScript: do { /* loop body */ } while(condition);", 10
             db ";   Assembly:", 10
             db ";   .do_while_start:", 10
             db ";       ; loop body", 10
             db ";       cmp [condition], 0", 10
             db ";       jne .do_while_start", 10
             db ";   .do_while_end:", 10, 10
             
             db "; Pattern 21: For-in loop (object iteration)", 10
             db ";   JavaScript: for(let key in obj) { console.log(key); }", 10
             db ";   Assembly:", 10
             db ";       ; Assuming object is an array of key-value pairs", 10
             db ";       mov rsi, [obj_start]      ; start of object", 10
             db ";       mov rcx, [obj_size]       ; number of properties", 10
             db ";   .for_in_loop:", 10
             db ";       test rcx, rcx", 10
             db ";       jz .for_in_end", 10
             db ";       ; rsi points to key-value pair", 10
             db ";       mov rdi, [rsi]            ; key pointer", 10
             db ";       ; process key", 10
             db ";       add rsi, 16               ; move to next pair (key+value)", 10
             db ";       dec rcx", 10
             db ";       jmp .for_in_loop", 10
             db ";   .for_in_end:", 10, 10
             
             db "; Pattern 22: For-of loop (array/iterable)", 10
             db ";   JavaScript: for(let item of array) { console.log(item); }", 10
             db ";   Assembly:", 10
             db ";       mov rsi, [array_ptr]      ; start of array", 10
             db ";       mov rcx, [array_length]   ; length", 10
             db ";   .for_of_loop:", 10
             db ";       test rcx, rcx", 10
             db ";       jz .for_of_end", 10
             db ";       mov rax, [rsi]            ; current item", 10
             db ";       ; process item", 10
             db ";       add rsi, 8                ; next item (64-bit)", 10
             db ";       dec rcx", 10
             db ";       jmp .for_of_loop", 10
             db ";   .for_of_end:", 10, 10
             
             db "; Pattern 23: forEach loop (array method pattern)", 10
             db ";   JavaScript: array.forEach(item => console.log(item));", 10
             db ";   Assembly:", 10
             db ";       mov rsi, [array_ptr]", 10
             db ";       mov rcx, [array_length]", 10
             db ";   .foreach_loop:", 10
             db ";       test rcx, rcx", 10
             db ";       jz .foreach_end", 10
             db ";       mov rdi, [rsi]            ; item", 10
             db ";       ; call callback with item", 10
             db ";       push rdi", 10
             db ";       call [callback_ptr]", 10
             db ";       add rsp, 8", 10
             db ";       add rsi, 8", 10
             db ";       dec rcx", 10
             db ";       jmp .foreach_loop", 10
             db ";   .foreach_end:", 10, 10
             
             db "; === FUNCTION CALL PATTERNS ===", 10
             db "; Pattern 24: Direct function call", 10
             db ";   JavaScript: const result = add(5, 3);", 10
             db ";   Assembly:", 10
             db ";       push 3", 10
             db ";       push 5", 10
             db ";       call add_function", 10
             db ";       add rsp, 16               ; cleanup stack", 10
             db ";       mov [result], rax         ; store return value", 10, 10
             
             db "; Pattern 25: Function call through pointer", 10
             db ";   JavaScript: const fn = add; const result = fn(5, 3);", 10
             db ";   Assembly:", 10
             db ";       push 3", 10
             db ";       push 5", 10
             db ";       call [fn_ptr]             ; indirect call", 10
             db ";       add rsp, 16", 10
             db ";       mov [result], rax", 10, 10
             
             db "; Pattern 26: Method call on object", 10
             db ";   JavaScript: calculator.add(5, 3);", 10
             db ";   Assembly:", 10
             db ";       push 3", 10
             db ";       push 5", 10
             db ";       call [calc_add_ptr]       ; call method pointer", 10
             db ";       add rsp, 16", 10, 10
             
             db "; Pattern 27: Callback function pattern", 10
             db ";   JavaScript: setTimeout(() => console.log('Hello'), 1000);", 10
             db ";   Assembly:", 10
             db ";       ; Store callback and timer", 10
             db ";       mov [callback_ptr], timeout_handler", 10
             db ";       mov [timer_value], 1000", 10
             db ";       ; Later, call the callback", 10
             db ";       call [callback_ptr]", 10, 10
             
             db "; Pattern 28: Immediately Invoked Function Expression (IIFE)", 10
             db ";   JavaScript: (function() { console.log('IIFE'); })();", 10
             db ";   Assembly:", 10
             db ";       call iife_function", 10
             db ";       jmp .after_iife", 10
             db ";   iife_function:", 10
             db ";       push rbp", 10
             db ";       mov rbp, rsp", 10
             db ";       ; IIFE body", 10
             db ";       pop rbp", 10
             db ";       ret", 10
             db ";   .after_iife:", 10, 10
             
             db "; === ASYNCHRONOUS PATTERNS (Simulated) ===", 10
             db "; Pattern 29: Promise-like pattern", 10
             db ";   JavaScript: new Promise((resolve, reject) => { /* async */ })", 10
             db ";   Assembly:", 10
             db ";       ; Store callback pointers", 10
             db ";       mov [resolve_ptr], resolve_handler", 10
             db ";       mov [reject_ptr], reject_handler", 10
             db ";       ; Execute async operation", 10
             db ";       ; When done: call [resolve_ptr] or [reject_ptr]", 10, 10
             
             db "; Pattern 30: Async/await pattern (simulated)", 10
             db ";   JavaScript: async function fetchData() { return await promise; }", 10
             db ";   Assembly:", 10
             db ";       ; Setup async state", 10
             db ";       mov [async_state], ASYNC_PENDING", 10
             db ";       ; Start async operation", 10
             db ";       ; Check completion in loop", 10
             db ";   .await_loop:", 10
             db ";       cmp [async_state], ASYNC_COMPLETE", 10
             db ";       je .async_done", 10
             db ";       ; do other work or yield", 10
             db ";       jmp .await_loop", 10
             db ";   .async_done:", 10, 10
             
             db "; === ERROR HANDLING PATTERNS ===", 10
             db "; Pattern 31: Try-catch pattern", 10
             db ";   JavaScript:", 10
             db ";   try { riskyOperation(); }", 10
             db ";   catch(e) { handleError(e); }", 10
             db ";   Assembly:", 10
             db ";       ; Set up exception handler", 10
             db ";       mov [exception_handler], catch_block", 10
             db ";       ; Try block", 10
             db ";       call risky_operation", 10
             db ";       jmp .try_end", 10
             db ";   catch_block:", 10
             db ";       ; Exception occurred, handle it", 10
             db ";       call handle_error", 10
             db ";   .try_end:", 10, 10
             
             db "; Pattern 32: Throw error", 10
             db ";   JavaScript: throw new Error('Message');", 10
             db ";   Assembly:", 10
             db ";       ; Set error state and jump to handler", 10
             db ";       mov [error_code], ERROR_GENERIC", 10
             db ";       mov rsi, error_message", 10
             db ";       jmp [exception_handler]", 10, 10
             
             db "; === DATA STRUCTURE PATTERNS ===", 10
             db "; Pattern 33: Array operations", 10
             db ";   JavaScript: const arr = [1, 2, 3]; arr.push(4);", 10
             db ";   Assembly:", 10
             db ";       ; Check capacity", 10
             db ";       mov rax, [arr_length]", 10
             db ";       cmp rax, [arr_capacity]", 10
             db ";       jge .resize_array", 10
             db ";       ; Add element", 10
             db ";       mov rbx, [arr_ptr]", 10
             db ";       mov [rbx + rax*8], 4      ; arr[length] = 4", 10
             db ";       inc qword [arr_length]", 10
             db ";   .resize_array:", 10
             db ";       ; Handle resizing", 10, 10
             
             db "; Pattern 34: Object property access", 10
             db ";   JavaScript: const value = obj.property;", 10
             db ";   Assembly:", 10
             db ";       ; Assuming fixed offset for property", 10
             db ";       mov rax, [obj_ptr + property_offset]", 10
             db ";       mov [value], rax", 10, 10
             
             db "; Pattern 35: Dynamic property access", 10
             db ";   JavaScript: const value = obj[key];", 10
             db ";   Assembly:", 10
             db ";       ; Look up key in property table", 10
             db ";       mov rdi, [key_ptr]", 10
             db ";       call find_property", 10
             db ";       test rax, rax", 10
             db ";       jz .property_not_found", 10
             db ";       mov rbx, [rax + 8]        ; value offset", 10
             db ";       mov [value], rbx", 10, 10
             
             db "; === MAIN PROGRAM ===", 10
             db "; =========================================================", 10
             db "_start:", 10
             db "    ; === INITIALIZE GLOBAL VARIABLES ===", 10
             db "    ; Initialize your global variables here", 10
             db "    ; Example:", 10
             db "    ;   mov QWORD [counter], 0", 10
             db "    ;   mov QWORD [is_active], 1", 10
             db "    ;   mov [fn_ptr], default_function", 10, 10
             
             db "    ; === YOUR JAVASCRIPT-LIKE CODE STARTS HERE ===", 10
             db "    ; Add your code following the patterns above", 10
             db "    ; All patterns are commented out by default", 10, 10
             
             db "    ; === EXAMPLE: COMBINING PATTERNS ===", 10
             db "    ; JavaScript equivalent:", 10
             db "    ;   const numbers = [1, 2, 3, 4, 5];", 10
             db "    ;   let sum = 0;", 10
             db "    ;   for(let n of numbers) {", 10
             db "    ;       sum += n;", 10
             db "    ;   }", 10
             db "    ;   console.log(sum);", 10
             db "    ;", 10
             db "    ; Assembly implementation (commented out):", 10
             db "    ;   ; Initialize array", 10
             db "    ;   numbers_ptr: dq 1, 2, 3, 4, 5", 10
             db "    ;   numbers_length dq 5", 10
             db "    ;   sum dq 0", 10
             db "    ;   i dq 0", 10
             db "    ;", 10
             db "    ;   mov qword [sum], 0", 10
             db "    ;   mov rsi, numbers_ptr", 10
             db "    ;   mov rcx, [numbers_length]", 10
             db "    ; .sum_loop:", 10
             db "    ;   test rcx, rcx", 10
             db "    ;   jz .sum_done", 10
             db "    ;   mov rax, [rsi]", 10
             db "    ;   add [sum], rax", 10
             db "    ;   add rsi, 8", 10
             db "    ;   dec rcx", 10
             db "    ;   jmp .sum_loop", 10
             db "    ; .sum_done:", 10
             db "    ;   ; print result would go here", 10, 10
             
             db "    ; === CLEANUP ===", 10
             db "    ; Reset variables if needed", 10, 10
             
             db "    ; === EXIT PROGRAM ===", 10
             db "    mov rax, 60                 ; sys_exit", 10
             db "    xor rdi, rdi                ; exit code 0", 10
             db "    syscall", 10, 10
             
             db "; === QUICK REFERENCE: JS → ASSEMBLY MAPPING ===", 10
             db "; =========================================================", 10
             db "; JavaScript                   Assembly", 10
             db "; -----------                  --------", 10
             db "; const x = 5                  x equ 5", 10
             db "; let y = 10                   y dq 10", 10
             db "; let z;                       z resq 1", 10
             db "; var v = 'hi'                 v db 'hi',0", 10
             db "; function fn() {}             fn: push rbp; mov rbp, rsp; ...", 10
             db "; const arr = []               arr_ptr: dq 0,0,0...", 10
             db "; const obj = {}               obj_prop1 dq 0; obj_prop2 dq 0", 10
             db "; if (x) {}                    cmp [x],0; je .endif; ...", 10
             db "; for(let i=0;i<10;i++){}      mov [i],0;.loop: cmp [i],10; ...", 10
             db "; while(cond) {}               .loop: cmp [cond],0; je .end", 10
             db "; obj.method()                 call [obj_method_ptr]", 10
             db "; arr.forEach(fn)              loop through array, call fn", 10
             db "; try/catch                    Set exception handler, jump on error", 10
             db "; =========================================================", 10
             db "; END OF TEMPLATE - All JavaScript patterns covered!", 10
             db "; =========================================================", 10
    template_len equ $ - template

section .bss
    fd resq 1

section .text
    global _start

_start:
    ; Create the template file
    mov rax, 2                    ; sys_open
    mov rdi, filename
    mov rsi, 0o101                ; O_CREAT | O_WRONLY
    or rsi, 0o100                 ; O_TRUNC
    mov rdx, 0o644                ; permissions
    syscall
    
    cmp rax, 0
    jl exit_error
    
    mov [fd], rax

    ; Write the template content
    mov rax, 1                    ; sys_write
    mov rdi, [fd]
    mov rsi, template
    mov rdx, template_len
    syscall

    ; Close the file
    mov rax, 3                    ; sys_close
    mov rdi, [fd]
    syscall

    ; Exit successfully
    mov rax, 60                   ; sys_exit
    xor rdi, rdi                  ; exit code 0
    syscall

exit_error:
    mov rax, 60                   ; sys_exit
    mov rdi, 1                    ; exit code 1
    syscall
