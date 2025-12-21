#!/bin/bash

mkdir -p arrays_tests
cd arrays_tests

# 1. Missing closing bracket
cat > 01_missing_closing_bracket.js << 'EOF'
const arr1 = [1, 2, 3;
EOF

# 2. Missing opening bracket
cat > 02_missing_opening_bracket.js << 'EOF'
const arr2 = 1, 2, 3];
EOF

# 3. Lonely closing bracket
cat > 03_lonely_closing_bracket.js << 'EOF'
const arr3 = ];
EOF

# 4. Wrong bracket type (curly)
cat > 04_wrong_bracket_type_curly.js << 'EOF'
const arr4 = {1, 2, 3};
EOF

# 5. Multiple commas without elements (edge case - actually valid)
cat > 05_empty_spread_operator.js << 'EOF'
const arr5 = [...];
EOF

# 6. Spread operator without expression
cat > 06_spread_without_expression.js << 'EOF'
const arr6 = [1, ...];
EOF

# 7. Unterminated string in array
cat > 07_unterminated_string.js << 'EOF'
const arr7 = ["hello", 'world];
EOF

# 8. Unterminated template literal
cat > 08_unterminated_template.js << 'EOF'
const arr8 = [`template, `closed`];
EOF

# 9. Incomplete expression
cat > 09_incomplete_expression.js << 'EOF'
const arr9 = [1 + 2 *;
EOF

# 10. Missing array element after comma (with semicolon)
cat > 10_missing_element_semicolon.js << 'EOF'
const arr10 = [1, 2, ;];
EOF

# 11. Invalid spread on non-iterable
cat > 11_invalid_spread_number.js << 'EOF'
const arr11 = [...1];
EOF

# 12. Missing inner closing bracket
cat > 12_missing_inner_closing.js << 'EOF'
const arr12 = [[1, 2], [3, 4;
EOF

# 13. Unbalanced nested brackets
cat > 13_unbalanced_nested.js << 'EOF'
const arr13 = [[1, 2], [3, 4;];
EOF

# 14. Object syntax in array
cat > 14_object_in_array.js << 'EOF'
const arr14 = [{x: 2], 3];
EOF

# 15. Array syntax in object position
cat > 15_array_in_object.js << 'EOF'
const arr15 = [[1, 2}, 3];
EOF

# 16. Function without body
cat > 16_function_no_body.js << 'EOF'
const arr16 = [function()];
EOF

# 17. Arrow function without body
cat > 17_arrow_no_body.js << 'EOF'
const arr17 = [() =>];
EOF

# 18. Invalid empty spread
cat > 18_invalid_empty_spread.js << 'EOF'
const arr18 = [... ,];
EOF

# 19. Double comma with operator
cat > 19_double_comma_operator.js << 'EOF'
const arr19 = [1, , , +];
EOF

# 20. Method call inside array
cat > 20_method_call_inside.js << 'EOF'
const arr20 = [1, 2, 3.map(x => x*2)];
EOF

# 21. New without constructor
cat > 21_new_no_constructor.js << 'EOF'
const arr21 = [new];
EOF

# 22. Typeof without operand
cat > 22_typeof_no_operand.js << 'EOF'
const arr22 = [typeof];
EOF

# 23. Unary operator without operand
cat > 23_unary_no_operand.js << 'EOF'
const arr23 = [+];
EOF

# 24. Binary operator incomplete
cat > 24_binary_incomplete.js << 'EOF'
const arr24 = [1 +];
EOF

# 25. Multiple trailing commas with operator
cat > 25_trailing_comma_operator.js << 'EOF'
const arr25 = [1, 2, 3, , +];
EOF

# 26. Comma after spread
cat > 26_comma_after_spread.js << 'EOF'
const arr26 = [...[1,2], ,];
EOF

# 27. Spread after comma without element
cat > 27_spread_after_comma.js << 'EOF'
const arr27 = [1, , ...];
EOF

# 28. Nested array with missing comma
cat > 28_nested_missing_comma.js << 'EOF'
const arr28 = [[1, 2] [3, 4]];
EOF

# 29. Array with statement inside
cat > 29_statement_inside.js << 'EOF'
const arr29 = [let x = 5];
EOF

# 30. Multiple dots (invalid spread)
cat > 30_multiple_dots.js << 'EOF'
const arr30 = [....];
EOF

# 31. Dot operator in array
cat > 31_dot_in_array.js << 'EOF'
const arr31 = [obj.];
EOF

# 32. Optional chaining in array
cat > 32_optional_in_array.js << 'EOF'
const arr32 = [obj?.];
EOF

# 33. Bracket access in array
cat > 33_bracket_access.js << 'EOF'
const arr33 = [obj[]];
EOF

# 34. Unterminated regex in array
cat > 34_unterminated_regex.js << 'EOF'
const arr34 = [/regex;
EOF

# 35. Colon in array (object syntax)
cat > 35_colon_in_array.js << 'EOF'
const arr35 = [x: 5];
EOF

# 36. Semicolon inside array
cat > 36_semicolon_inside.js << 'EOF'
const arr36 = [1; 2];
EOF

# 37. Missing comma in multi-line
cat > 37_missing_comma_multiline.js << 'EOF'
const arr37 = [
  1,
  2
  3,
  4
];
EOF

# 38. Dot after number
cat > 38_dot_after_number.js << 'EOF'
const arr38 = [1.];
EOF

# 39. Number with multiple dots
cat > 39_number_multiple_dots.js << 'EOF'
const arr39 = [1..2];
EOF

# 40. Invalid hex number
cat > 40_invalid_hex.js << 'EOF'
const arr40 = [0x];
EOF

# 41. Invalid octal
cat > 41_invalid_octal.js << 'EOF'
const arr41 = [0o];
EOF

# 42. Invalid binary
cat > 42_invalid_binary.js << 'EOF'
const arr42 = [0b];
EOF

# 43. Exponential without number
cat > 43_exponential_no_number.js << 'EOF'
const arr43 = [1e];
EOF

# 44. Exponential with invalid
cat > 44_exponential_invalid.js << 'EOF'
const arr44 = [1e+];
EOF

# 45. Comment inside without close
cat > 45_comment_no_close.js << 'EOF'
const arr45 = [1, /* comment, 2];
EOF

# 46. Label in array
cat > 46_label_in_array.js << 'EOF'
const arr46 = [label:];
EOF

# 47. Break in array
cat > 47_break_in_array.js << 'EOF'
const arr47 = [break];
EOF

# 48. Continue in array
cat > 48_continue_in_array.js << 'EOF'
const arr48 = [continue];
EOF

# 49. Return in array
cat > 49_return_in_array.js << 'EOF'
const arr49 = [return];
EOF

# 50. Yield in array (outside generator)
cat > 50_yield_in_array.js << 'EOF'
const arr50 = [yield];
EOF

echo "Generated 50 JavaScript array literal error files in arrays_tests/"
