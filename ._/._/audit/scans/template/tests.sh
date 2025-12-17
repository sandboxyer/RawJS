#!/bin/bash

mkdir -p template_tests
cd template_tests

# 1. Unmatched backticks
cat > 01_unmatched_backtick.js << 'EOF'
const message = `Hello world;
EOF

# 2. Malformed placeholder - missing closing }
cat > 02_malformed_placeholder.js << 'EOF'
const name = "John";
const msg = `Hello ${name`;
EOF

# 3. Empty placeholder
cat > 03_empty_placeholder.js << 'EOF'
const msg = `Hello ${}`;
EOF

# 4. Nested template without closing
cat > 04_nested_no_close.js << 'EOF'
const msg = `Outer ${`inner`;
EOF

# 5. Statement in placeholder
cat > 05_statement_in_placeholder.js << 'EOF'
const msg = `Result: ${let x = 5}`;
EOF

# 6. Control flow in placeholder
cat > 06_if_in_placeholder.js << 'EOF'
const msg = `Result: ${if (true) "yes"}`;
EOF

# 7. Loop in placeholder
cat > 07_loop_in_placeholder.js << 'EOF'
const msg = `Result: ${for (;;) {}}`;
EOF

# 8. Try-catch in placeholder
cat > 08_try_in_placeholder.js << 'EOF'
const msg = `Result: ${try { } catch(e) { }}`;
EOF

# 9. Invalid tag - number before template
cat > 09_number_tag.js << 'EOF'
const msg = 123`Hello`;
EOF

# 10. Invalid Unicode escape
cat > 10_invalid_unicode.js << 'EOF'
const msg = `Bad: \u{invalid}`;
EOF

# 11. Incomplete Unicode escape
cat > 11_incomplete_unicode.js << 'EOF'
const msg = `Bad: \u123`;
EOF

# 12. Invalid hex escape
cat > 12_invalid_hex.js << 'EOF'
const msg = `Bad: \x`;
EOF

# 13. Incomplete hex escape
cat > 13_incomplete_hex.js << 'EOF'
const msg = `Bad: \xG`;
EOF

# 14. Invalid octal escape (not allowed in template literals in strict mode)
cat > 14_invalid_octal.js << 'EOF'
const msg = `Bad: \012`;
EOF

# 15. Lonely backslash at end
cat > 15_lonely_backslash.js << 'EOF'
const msg = `Bad: \`;
EOF

# 16. Unterminated escaped placeholder
cat > 16_unterminated_escaped.js << 'EOF'
const msg = `Bad: \${`;
EOF

# 17. Multiple backslashes issues
cat > 17_bad_escape_sequence.js << 'EOF'
const msg = `Bad: \c`;
EOF

# 18. Tag function called wrong
cat > 18_tag_function_wrong.js << 'EOF'
const msg = String.raw(`Hello`);
EOF

# 19. Template as property key
cat > 19_template_property_key.js << 'EOF'
const obj = {
    `key`: "value"
};
EOF

# 20. Import with template
cat > 20_import_template.js << 'EOF'
import * as mod from `./module.js`;
EOF

# 21. Import with interpolated template
cat > 21_import_interpolated.js << 'EOF'
import * as mod from `./${module}.js`;
EOF

# 22. Export with template
cat > 22_export_template.js << 'EOF'
export `test`;
EOF

# 23. Directive prologue with template
cat > 23_directive_template.js << 'EOF'
function test() {
    `use strict`;
    let x = 0177;
}
EOF

# 24. Nested too deep with errors
cat > 24_over_nested.js << 'EOF'
const msg = `Level1 ${`Level2 ${`Level3 ${`}`;
EOF

# 25. Mismatched braces in expression
cat > 25_mismatched_braces.js << 'EOF'
const msg = `Result: ${(x => x}(5)}`;
EOF

# 26. Missing operand in expression
cat > 26_missing_operand.js << 'EOF'
const msg = `Result: ${5 + }`;
EOF

# 27. Unexpected comma in expression
cat > 27_unexpected_comma.js << 'EOF'
const msg = `Result: ${x, }`;
EOF

# 28. Spread without identifier
cat > 28_spread_no_id.js << 'EOF'
const arr = [1, 2, 3];
const msg = `Items: ${...arr}`;
EOF

# 29. New without constructor in placeholder
cat > 29_new_no_con_in_placeholder.js << 'EOF'
const msg = `Result: ${new }`;
EOF

# 30. Delete in placeholder without operand
cat > 30_delete_no_operand.js << 'EOF'
const msg = `Result: ${delete }`;
EOF

# 31. Void without expression
cat > 31_void_no_expr.js << 'EOF'
const msg = `Result: ${void }`;
EOF

# 32. Typeof without operand
cat > 32_typeof_no_op.js << 'EOF'
const msg = `Result: ${typeof }`;
EOF

# 33. Instanceof without right operand
cat > 33_instanceof_no_right.js << 'EOF'
const msg = `Result: ${x instanceof }`;
EOF

# 34. In without right operand
cat > 34_in_no_right.js << 'EOF'
const msg = `Result: ${"x" in }`;
EOF

# 35. Arrow function without body
cat > 35_arrow_no_body.js << 'EOF'
const msg = `Result: ${() => }`;
EOF

# 36. Function call without closing paren
cat > 36_function_call_no_close.js << 'EOF'
const msg = `Result: ${Math.max(1, 2}`;
EOF

# 37. Array literal without closing bracket
cat > 37_array_no_close.js << 'EOF'
const msg = `Array: ${[1, 2, 3}`;
EOF

# 38. Object literal without closing brace
cat > 38_object_no_close.js << 'EOF'
const msg = `Object: ${{x: 1}`;
EOF

# 39. Template in template string position
cat > 39_template_in_string.js << 'EOF'
const msg = "Template: `Hello ${name}`";
EOF
# Note: This one might be valid depending on context

# 40. Backtick inside without escape
cat > 40_backtick_no_escape.js << 'EOF'
const msg = `Bad backtick: ` inside`;
EOF

# 41. Multiple interpolation errors
cat > 41_multiple_errors.js << 'EOF'
const msg = `Hello ${name} ${`Nested ${`Deep}`;
EOF

# 42. Expression with line terminator
cat > 42_expr_line_terminator.js << 'EOF'
const msg = `Result: ${x
+ y}`;
EOF
# Note: This might be valid with expression continuation

# 43. Tagged template with line break before
cat > 43_tag_line_break.js << 'EOF'
tag
`Hello`;
EOF
# Note: This might be valid

# 44. Invalid raw property access
cat > 44_invalid_raw_access.js << 'EOF'
`Hello`.raw;
EOF

# 45. Computed property with error
cat > 45_computed_property_error.js << 'EOF'
const obj = {
    [`key` + ]: "value"
};
EOF

# 46. Method name with template error
cat > 46_method_name_error.js << 'EOF'
const obj = {
    [`method${}`]() {}
};
EOF

# 47. Class property with template
cat > 47_class_property_template.js << 'EOF'
class Test {
    `prop` = "value";
}
EOF

# 48. Getter with template name
cat > 48_getter_template_name.js << 'EOF'
const obj = {
    get `prop`() { return "value"; }
};
EOF

# 49. Setter with template name
cat > 49_setter_template_name.js << 'EOF'
const obj = {
    set `prop`(value) { this._prop = value; }
};
EOF

# 50. Complex nested with multiple issues
cat > 50_complex_nested.js << 'EOF'
const msg = `Level1: ${`Level2: ${`Level3: ${new }`}${`Extra: ${}`}`;
EOF

echo "Generated 50 JavaScript files with template literal syntax errors in template_tests/"
