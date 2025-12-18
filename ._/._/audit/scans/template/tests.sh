#!/bin/bash

mkdir -p template_tests
cd template_tests

echo "Generating 100 unified JavaScript test files..."

# ===== BASIC TOKEN ERRORS (1-50) =====
echo "Creating basic token error tests (1-50)..."

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

# ===== TEMPLATE LITERAL ERRORS (51-100) =====
echo "Creating template literal error tests (51-100)..."

cat > 51_unmatched_backtick.js << 'EOF'
const message = `Hello world;
EOF

cat > 52_malformed_placeholder.js << 'EOF'
const name = "John";
const msg = `Hello ${name`;
EOF

cat > 53_empty_placeholder.js << 'EOF'
const msg = `Hello ${}`;
EOF

cat > 54_nested_no_close.js << 'EOF'
const msg = `Outer ${`inner`;
EOF

cat > 55_statement_in_placeholder.js << 'EOF'
const msg = `Result: ${let x = 5}`;
EOF

cat > 56_if_in_placeholder.js << 'EOF'
const msg = `Result: ${if (true) "yes"}`;
EOF

cat > 57_loop_in_placeholder.js << 'EOF'
const msg = `Result: ${for (;;) {}}`;
EOF

cat > 58_try_in_placeholder.js << 'EOF'
const msg = `Result: ${try { } catch(e) { }}`;
EOF

cat > 59_number_tag.js << 'EOF'
const msg = 123`Hello`;
EOF

cat > 60_invalid_unicode.js << 'EOF'
const msg = `Bad: \u{invalid}`;
EOF

cat > 61_incomplete_unicode.js << 'EOF'
const msg = `Bad: \u123`;
EOF

cat > 62_invalid_hex.js << 'EOF'
const msg = `Bad: \x`;
EOF

cat > 63_incomplete_hex.js << 'EOF'
const msg = `Bad: \xG`;
EOF

cat > 64_invalid_octal.js << 'EOF'
const msg = `Bad: \012`;
EOF

cat > 65_lonely_backslash.js << 'EOF'
const msg = `Bad: \`;
EOF

cat > 66_unterminated_escaped.js << 'EOF'
const msg = `Bad: \${`;
EOF

cat > 67_bad_escape_sequence.js << 'EOF'
const msg = `Bad: \c`;
EOF

cat > 68_tag_function_wrong.js << 'EOF'
const msg = String.raw(`Hello`);
EOF

cat > 69_template_property_key.js << 'EOF'
const obj = {
    `key`: "value"
};
EOF

cat > 70_import_template.js << 'EOF'
import * as mod from `./module.js`;
EOF

cat > 71_import_interpolated.js << 'EOF'
import * as mod from `./${module}.js`;
EOF

cat > 72_export_template.js << 'EOF'
export `test`;
EOF

cat > 73_directive_template.js << 'EOF'
function test() {
    `use strict`;
    let x = 0177;
}
EOF

cat > 74_over_nested.js << 'EOF'
const msg = `Level1 ${`Level2 ${`Level3 ${`}`;
EOF

cat > 75_mismatched_braces.js << 'EOF'
const msg = `Result: ${(x => x}(5)}`;
EOF

cat > 76_missing_operand.js << 'EOF'
const msg = `Result: ${5 + }`;
EOF

cat > 77_unexpected_comma.js << 'EOF'
const msg = `Result: ${x, }`;
EOF

cat > 78_spread_no_id.js << 'EOF'
const arr = [1, 2, 3];
const msg = `Items: ${...arr}`;
EOF

cat > 79_new_no_con_in_placeholder.js << 'EOF'
const msg = `Result: ${new }`;
EOF

cat > 80_delete_no_operand.js << 'EOF'
const msg = `Result: ${delete }`;
EOF

cat > 81_void_no_expr.js << 'EOF'
const msg = `Result: ${void }`;
EOF

cat > 82_typeof_no_op.js << 'EOF'
const msg = `Result: ${typeof }`;
EOF

cat > 83_instanceof_no_right.js << 'EOF'
const msg = `Result: ${x instanceof }`;
EOF

cat > 84_in_no_right.js << 'EOF'
const msg = `Result: ${"x" in }`;
EOF

cat > 85_arrow_no_body.js << 'EOF'
const msg = `Result: ${() => }`;
EOF

cat > 86_function_call_no_close.js << 'EOF'
const msg = `Result: ${Math.max(1, 2}`;
EOF

cat > 87_array_no_close.js << 'EOF'
const msg = `Array: ${[1, 2, 3}`;
EOF

cat > 88_object_no_close.js << 'EOF'
const msg = `Object: ${{x: 1}`;
EOF

cat > 89_template_in_string.js << 'EOF'
const msg = "Template: `Hello ${name}`";
EOF

cat > 90_backtick_no_escape.js << 'EOF'
const msg = `Bad backtick: ` inside`;
EOF

cat > 91_multiple_errors.js << 'EOF'
const msg = `Hello ${name} ${`Nested ${`Deep}`;
EOF

cat > 92_expr_line_terminator.js << 'EOF'
const msg = `Result: ${x
+ y}`;
EOF

cat > 93_tag_line_break.js << 'EOF'
tag
`Hello`;
EOF

cat > 94_invalid_raw_access.js << 'EOF'
`Hello`.raw;
EOF

cat > 95_computed_property_error.js << 'EOF'
const obj = {
    [`key` + ]: "value"
};
EOF

cat > 96_method_name_error.js << 'EOF'
const obj = {
    [`method${}`]() {}
};
EOF

cat > 97_class_property_template.js << 'EOF'
class Test {
    `prop` = "value";
}
EOF

cat > 98_getter_template_name.js << 'EOF'
const obj = {
    get `prop`() { return "value"; }
};
EOF

cat > 99_setter_template_name.js << 'EOF'
const obj = {
    set `prop`(value) { this._prop = value; }
};
EOF

cat > 100_complex_nested.js << 'EOF'
const msg = `Level1: ${`Level2: ${`Level3: ${new }`}${`Extra: ${}`}`;
EOF

echo "========================================"
echo "Generated 100 JavaScript test files:"
echo "- Tests 1-50: Basic token errors"
echo "- Tests 51-100: Template literal errors"
echo "All files saved in 'template_tests/' directory"
echo "========================================"
