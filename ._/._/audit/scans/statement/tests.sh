#!/bin/bash

mkdir -p statement_tests
cd statement_tests

# 1. Declaration and Assignment Errors
cat > 01_missing_identifier.js << 'EOF'
let = 5;
EOF

cat > 02_const_no_init.js << 'EOF'
const x;
EOF

cat > 03_duplicate_declaration.js << 'EOF'
let x = 5;
let x = 10;
EOF

cat > 04_invalid_lhs_assignment.js << 'EOF'
5 = 10;
EOF

cat > 05_expression_lhs.js << 'EOF'
x + y = 15;
EOF

# 2. Function and Method Errors
cat > 06_function_no_name.js << 'EOF'
function () {
    return 5;
}
EOF

cat > 07_function_empty_param.js << 'EOF'
function test(a, , c) {
    return a + c;
}
EOF

cat > 08_rest_not_last.js << 'EOF'
function test(...a, b) {
    return a + b;
}
EOF

cat > 09_duplicate_params.js << 'EOF'
function test(x, x) {
    return x + x;
}
EOF

cat > 10_arrow_missing_arrow.js << 'EOF'
const fn = (x) { return x; };
EOF

# 3. Control Flow Statement Errors
cat > 11_if_no_paren.js << 'EOF'
if x > 5 {
    console.log(x);
}
EOF

cat > 12_if_empty.js << 'EOF'
if () {
    console.log("always?");
}
EOF

cat > 13_for_loop_missing.js << 'EOF'
for (let i = 0; i < 10) {
    console.log(i);
}
EOF

cat > 14_for_in_missing.js << 'EOF'
for (let key in ) {
    console.log(key);
}
EOF

cat > 15_while_empty.js << 'EOF'
while () {
    console.log("loop");
}
EOF

# 4. Switch Statement Errors
cat > 16_switch_statement_outside.js << 'EOF'
switch (x) {
    console.log("before case");
    case 1: break;
}
EOF

cat > 17_duplicate_case.js << 'EOF'
switch (x) {
    case 1: break;
    case 1: break;
}
EOF

cat > 18_case_no_expression.js << 'EOF'
switch (x) {
    case: break;
}
EOF

# 5. Jump Statement Errors
cat > 19_break_outside.js << 'EOF'
break;
EOF

cat > 20_continue_outside.js << 'EOF'
continue;
EOF

cat > 21_throw_no_expression.js << 'EOF'
throw;
EOF

cat > 22_return_outside_function.js << 'EOF'
return 5;
EOF

cat > 23_invalid_label.js << 'EOF'
break nonExistentLabel;
EOF

# 6. Class and OOP Errors
cat > 24_class_no_name.js << 'EOF'
class {
    constructor() {}
}
EOF

cat > 25_duplicate_constructor.js << 'EOF'
class Test {
    constructor() {}
    constructor(x) {}
}
EOF

cat > 26_invalid_method_name.js << 'EOF'
class Test {
    123() {}
}
EOF

cat > 27_missing_super.js << 'EOF'
class Parent {
    constructor() {}
}

class Child extends Parent {
    constructor() {
        console.log("before super");
    }
}
EOF

# 7. Module and Import/Export Errors
cat > 28_import_missing_from.js << 'EOF'
import { x };
EOF

cat > 29_import_missing_alias.js << 'EOF'
import { x as } from "module";
EOF

cat > 30_export_no_expression.js << 'EOF'
export 5;
EOF

cat > 31_export_missing_name.js << 'EOF'
export let;
EOF

cat > 32_export_default_const.js << 'EOF'
export default const x = 5;
EOF

# 8. Try-Catch-Finally Errors
cat > 33_try_no_catch_finally.js << 'EOF'
try {
    riskyOperation();
}
EOF

cat > 34_multiple_finally.js << 'EOF'
try {} catch (e) {} finally {} finally {}
EOF

cat > 35_catch_no_param.js << 'EOF'
try {} catch () {}
EOF

cat > 36_catch_invalid_param.js << 'EOF'
try {} catch (e e) {}
EOF

cat > 37_wrong_order.js << 'EOF'
try {} finally {} catch (e) {}
EOF

# 9. Destructuring Errors
cat > 38_invalid_destructuring.js << 'EOF'
const { x: } = obj;
EOF

cat > 39_rest_not_last_array.js << 'EOF'
const [...x, y] = arr;
EOF

cat > 40_rest_not_last_param.js << 'EOF'
const fn = (...args, last) => {};
EOF

# 10. Object and Property Errors
cat > 41_object_missing_value.js << 'EOF'
const obj = { x: , y: 5 };
EOF

cat > 42_method_with_colon.js << 'EOF'
const obj = {
    async method: function() {}
};
EOF

cat > 43_setter_no_param.js << 'EOF'
const obj = {
    set prop() {}
};
EOF

# 11. Expression Statement Errors
cat > 44_if_with_let.js << 'EOF'
if (let x = 5) { }
EOF

cat > 45_while_with_var.js << 'EOF'
while (var i = 0; i < 10; i++) { }
EOF

# 12. IIFE Errors
cat > 46_iife_missing_parens.js << 'EOF'
function() {
    console.log("IIFE");
}();
EOF

cat > 47_arrow_iife_error.js << 'EOF'
() => {}();
EOF

# 13. Do-While Errors
cat > 48_do_while_no_semicolon.js << 'EOF'
do {
    console.log("loop");
} while (true)
EOF

cat > 49_do_while_empty.js << 'EOF'
do {
    console.log("loop");
} while ();
EOF

# 14. For-Of Errors
cat > 50_for_of_missing.js << 'EOF'
for (item of ) {
    console.log(item);
}
EOF

echo "Generated 50 JavaScript files with statement structure errors in statement_tests/"
