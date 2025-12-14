#!/bin/bash

mkdir -p basics_tests
cd basics_tests

cat > 01_unexpected_semicolon.js << 'EOF'
let x = ;
EOF

cat > 02_multiple_commas_object.js << 'EOF'
const obj = { name: "John", , };
EOF

cat > 03_semicolon_array.js << 'EOF'
const arr = [1; 2, 3];
EOF

cat > 04_number_variable.js << 'EOF'
const 123 = 456;
EOF

cat > 05_hyphen_variable.js << 'EOF'
let my-name = "test";
EOF

cat > 06_at_symbol_variable.js << 'EOF'
let user@host = "email";
EOF

cat > 07_dot_variable.js << 'EOF'
let first.name = "John";
EOF

cat > 08_reserved_word.js << 'EOF'
let class = "math";
EOF

cat > 09_double_plus.js << 'EOF'
let x = 5 ++;
EOF

cat > 10_double_minus.js << 'EOF'
let y = -- 5;
EOF

cat > 11_incomplete_exponent.js << 'EOF'
let z = 2 **;
EOF

cat > 12_chained_equals.js << 'EOF'
let a = b = 5 = 6;
EOF

cat > 13_empty_spread.js << 'EOF'
const obj = {...};
EOF

cat > 14_lone_dot.js << 'EOF'
obj.;
EOF

cat > 15_empty_brackets.js << 'EOF'
obj[];
EOF

cat > 16_open_bracket.js << 'EOF'
obj[;
EOF

cat > 17_unterminated_string.js << 'EOF'
let str = "Hello world;
EOF

cat > 18_quote_mismatch.js << 'EOF'
let str = 'It"s a problem";
EOF

cat > 19_template_no_end.js << 'EOF'
let name = "John";
let msg = `Hello ${name;
EOF

cat > 20_regex_no_end.js << 'EOF'
let regex = /[a-z;
EOF

cat > 21_regex_extra.js << 'EOF'
let regex = /test/g extra;
EOF

cat > 22_backtick_error.js << 'EOF'
let str = `Hello \`;
EOF

cat > 23_if_no_paren.js << 'EOF'
if true { }
EOF

cat > 24_array_no_end.js << 'EOF'
let arr = [1, 2, 3;
EOF

cat > 25_break_error.js << 'EOF'
break;
EOF

cat > 26_continue_error.js << 'EOF'
continue;
EOF

cat > 27_return_error.js << 'EOF'
return;
EOF

cat > 28_comment_no_end.js << 'EOF'
/* Comment without close
EOF

cat > 29_destructure_semicolon.js << 'EOF'
let {x: ;} = {x: 1};
EOF

cat > 30_rest_no_name.js << 'EOF'
let [first, ...] = [1,2,3];
EOF

cat > 31_object_rest_empty.js << 'EOF'
let {...} = {x: 1};
EOF

cat > 32_optional_chain_dot.js << 'EOF'
obj?.;
EOF

cat > 33_optional_chain_bracket.js << 'EOF'
obj?[prop];
EOF

cat > 34_optional_chain_call.js << 'EOF'
obj?();
EOF

cat > 35_unary_plus.js << 'EOF'
let x = +;
EOF

cat > 36_multiply_missing.js << 'EOF'
let y = 5 * ;
EOF

cat > 37_typeof_missing.js << 'EOF'
let z = typeof ;
EOF

cat > 38_colon_missing.js << 'EOF'
let obj = { x 5 };
EOF

cat > 39_await_error.js << 'EOF'
await 5;
EOF

cat > 40_yield_error.js << 'EOF'
yield 5;
EOF

cat > 41_label_no_statement.js << 'EOF'
mylabel:
EOF

cat > 42_case_no_colon.js << 'EOF'
switch(x) { case 1 break; }
EOF

cat > 43_duplicate_default.js << 'EOF'
switch(x) { default: default: }
EOF

cat > 44_try_no_brace.js << 'EOF'
try x = 5; catch(e) {}
EOF

cat > 45_import_missing_brace.js << 'EOF'
import { from "module";
EOF

cat > 46_export_missing.js << 'EOF'
export {;
EOF

cat > 47_function_no_paren.js << 'EOF'
function test { }
EOF

cat > 48_arrow_function_error.js << 'EOF'
const fn = => 5;
EOF

cat > 49_new_no_constructor.js << 'EOF'
new ;
EOF

cat > 50_delete_dot.js << 'EOF'
delete obj.;
EOF

echo "Generated 50 JavaScript files with token errors in basics_tests/"
