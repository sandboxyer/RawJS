#!/bin/bash

mkdir -p regex_tests
cd regex_tests

# Create 50 JavaScript files with regex syntax errors
cat > 01_unclosed_character_class.js << 'EOF'
const regex1 = /[a-z/;
EOF

cat > 02_nothing_to_repeat_star.js << 'EOF'
const regex2 = /*/;
EOF

cat > 03_nothing_to_repeat_plus.js << 'EOF'
const regex3 = /+/;
EOF

cat > 04_nothing_to_repeat_question.js << 'EOF'
const regex4 = /?/;
EOF

cat > 05_invalid_quantifier_range.js << 'EOF'
const regex5 = /a{5,2}/;
EOF

cat > 06_invalid_character_class_range.js << 'EOF'
const regex6 = /[z-a]/;
EOF

cat > 07_unclosed_parentheses.js << 'EOF'
const regex7 = /(abc/;
EOF

cat > 08_empty_character_class.js << 'EOF'
const regex8 = /[]/;
EOF

cat > 09_unescaped_slash_in_regex.js << 'EOF'
const regex9 = /https://example.com/;
EOF

cat > 10_unterminated_regex.js << 'EOF'
const regex10 = /abc
EOF

cat > 11_invalid_flag.js << 'EOF'
const regex11 = /abc/x;
EOF

cat > 12_duplicate_slash.js << 'EOF'
const regex12 = /abc//;
EOF

cat > 13_invalid_unicode_escape.js << 'EOF'
const regex13 = /\u{110000}/u;
EOF

cat > 14_empty_unicode_escape.js << 'EOF'
const regex14 = /\u{}/u;
EOF

cat > 15_missing_unicode_flag.js << 'EOF'
const regex15 = /\u{61}/;
EOF

cat > 16_invalid_backreference.js << 'EOF'
const regex16 = /\10/;
EOF

cat > 17_invalid_named_backreference.js << 'EOF'
const regex17 = /(?<name>a)\k<wrong>/;
EOF

cat > 18_unclosed_named_backreference.js << 'EOF'
const regex18 = /(?<name>a)\k<name/;
EOF

cat > 19_invalid_named_capture.js << 'EOF'
const regex19 = /(?<>)/;
EOF

cat > 20_numeric_named_capture.js << 'EOF'
const regex20 = /(?<123>)/;
EOF

cat > 21_invalid_lookbehind.js << 'EOF'
const regex21 = /(?<*)/;
EOF

cat > 22_unclosed_lookbehind.js << 'EOF'
const regex22 = /(?<=abc/;
EOF

cat > 23_invalid_property_escape.js << 'EOF'
const regex23 = /\p{Invalid}/u;
EOF

cat > 24_missing_property_escape_flag.js << 'EOF'
const regex24 = /\p{Letter}/;
EOF

cat > 25_invalid_character_class_escape.js << 'EOF'
const regex25 = /[\d-a]/;
EOF

cat > 26_empty_quantifier.js << 'EOF'
const regex26 = /{3}/;
EOF

cat > 27_incomplete_quantifier.js << 'EOF'
const regex27 = /a{3/;
EOF

cat > 28_double_quantifier.js << 'EOF'
const regex28 = /a**/;
EOF

cat > 29_invalid_range_start.js << 'EOF'
const regex29 = /[a-]/;
EOF

cat > 30_invalid_range_end.js << 'EOF'
const regex30 = /[-z]/;
EOF

cat > 31_double_dash_in_class.js << 'EOF'
const regex31 = /[a--z]/;
EOF

cat > 32_unclosed_brace_in_quantifier.js << 'EOF'
const regex32 = /a{3,/;
EOF

cat > 33_invalid_non_capturing_group.js << 'EOF'
const regex33 = /(?:/;
EOF

cat > 34_invalid_positive_lookahead.js << 'EOF'
const regex34 = /(?=/;
EOF

cat > 35_invalid_negative_lookahead.js << 'EOF'
const regex35 = /(?!/;
EOF

cat > 36_extra_closing_parenthesis.js << 'EOF'
const regex36 = /abc)/;
EOF

cat > 37_extra_closing_bracket.js << 'EOF'
const regex37 = /abc]/;
EOF

cat > 38_invalid_escape_in_class.js << 'EOF'
const regex38 = /[\cX]/;
EOF

cat > 39_invalid_octal_escape.js << 'EOF'
const regex39 = /\400/;
EOF

cat > 40_invalid_hex_escape.js << 'EOF'
const regex40 = /\xGG/;
EOF

cat > 41_constructor_invalid_pattern.js << 'EOF'
const regex41 = new RegExp("[a-z");
EOF

cat > 42_constructor_invalid_flags.js << 'EOF'
const regex42 = new RegExp("abc", "gx");
EOF

cat > 43_constructor_extra_slashes.js << 'EOF'
const regex43 = new RegExp("/abc/");
EOF

cat > 44_template_literal_regex_error.js << 'EOF'
const pattern = "[a-z";
const regex44 = new RegExp(`${pattern}`);
EOF

cat > 45_dynamic_invalid_class.js << 'EOF'
const start = "[";
const end = "a-z]";
const regex45 = new RegExp(start + end);
EOF

cat > 46_flag_without_regex.js << 'EOF'
const regex46 = /abc/ g;
EOF

cat > 47_multiple_flags_error.js << 'EOF'
const regex47 = /abc/giu;
EOF

cat > 48_invalid_dotall_combination.js << 'EOF'
const regex48 = /./gsu;
EOF

cat > 49_unescaped_dot.js << 'EOF'
const regex49 = new RegExp("example.com");
EOF

cat > 50_complex_nested_error.js << 'EOF'
const regex50 = /([a-z]{2,}?(?<=test)[0-9]+/;
EOF

# Create some valid regex patterns for contrast
cat > valid_01_simple_regex.js << 'EOF'
const regex = /abc/;
EOF

cat > valid_02_with_flags.js << 'EOF'
const regex = /abc/gi;
EOF

cat > valid_03_character_class.js << 'EOF'
const regex = /[a-zA-Z0-9]/;
EOF

cat > valid_04_quantifiers.js << 'EOF'
const regex = /a{3,5}/;
EOF

cat > valid_05_groups.js << 'EOF'
const regex = /(abc)+/;
EOF

echo "Generated 50 JavaScript files with regex syntax errors in regex_tests/"
echo "Also generated 5 valid regex patterns for testing"
