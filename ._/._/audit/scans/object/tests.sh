#!/bin/bash

mkdir -p object_tests
cd object_tests

cat > 01_missing_property_value.js << 'EOF'
const obj = { name: };
EOF

cat > 02_invalid_property_colon.js << 'EOF'
const obj = { : "value" };
EOF

cat > 03_double_colon.js << 'EOF'
const obj = { name:: "value" };
EOF

cat > 04_missing_colon.js << 'EOF'
const obj = { name "value" };
EOF

cat > 05_leading_comma.js << 'EOF'
const obj = { , name: "John" };
EOF

cat > 06_double_comma.js << 'EOF'
const obj = { name: "John", , age: 30 };
EOF

cat > 07_trailing_double_comma.js << 'EOF'
const obj = { name: "John", age: 30,, };
EOF

cat > 08_missing_comma.js << 'EOF'
const obj = { 
  name: "John"
  age: 30
};
EOF

cat > 09_empty_computed_property.js << 'EOF'
const obj = { []: "value" };
EOF

cat > 10_unclosed_computed_property.js << 'EOF'
const obj = { [: "value" };
EOF

cat > 11_method_missing_paren.js << 'EOF'
const obj = { method { return true; } };
EOF

cat > 12_getter_missing_name.js << 'EOF'
const obj = { get { return this._prop; } };
EOF

cat > 13_getter_with_param.js << 'EOF'
const obj = { get prop(param) { return value; } };
EOF

cat > 14_setter_missing_param.js << 'EOF'
const obj = { set prop { this._prop = value; } };
EOF

cat > 15_generator_wrong_star.js << 'EOF'
const obj = { generator*() {} };
EOF

cat > 16_generator_space_star.js << 'EOF'
const obj = { * generator() {} };
EOF

cat > 17_spread_empty.js << 'EOF'
const obj = { ... };
EOF

cat > 18_unclosed_object.js << 'EOF'
const obj = { name: "John", age: 30;
EOF

cat > 19_shorthand_missing_comma.js << 'EOF'
const name = "John";
const age = 30;
const obj = { name age };
EOF

cat > 20_duplicate_proto.js << 'EOF'
const obj = {
  __proto__: null,
  __proto__: {}
};
EOF

cat > 21_numeric_property_dot.js << 'EOF'
const obj = { 1.: "value" };
EOF

cat > 22_property_equals.js << 'EOF'
const obj = { name = "John" };
EOF

cat > 23_method_extra_comma.js << 'EOF'
const obj = { method(param,,) {} };
EOF

cat > 24_getter_no_paren.js << 'EOF'
const obj = { get prop {} };
EOF

cat > 25_setter_no_paren.js << 'EOF'
const obj = { set prop {} };
EOF

cat > 26_invalid_shorthand.js << 'EOF'
const obj = { , };
EOF

cat > 27_computed_no_expression.js << 'EOF'
const obj = { [()]: "value" };
EOF

cat > 28_nested_unclosed.js << 'EOF'
const obj = {
  nested: {
    prop: "value"
};
EOF

cat > 29_object_in_array_error.js << 'EOF'
const arr = [{ name: "John", , }];
EOF

cat > 30_rest_empty.js << 'EOF'
const { ... } = obj;
EOF

cat > 31_mixed_accessor_data.js << 'EOF'
const obj = {
  get prop() { return this._prop; },
  prop: "value"
};
EOF

cat > 32_method_with_arrow.js << 'EOF'
const obj = { method: => {} };
EOF

cat > 33_shorthand_after_colon.js << 'EOF'
const obj = { name: name, };
EOF

cat > 34_computed_with_semicolon.js << 'EOF'
const obj = { [key;]: "value" };
EOF

cat > 35_object_no_comma_between.js << 'EOF'
const obj = { 
  a: 1
  b: 2 
};
EOF

cat > 36_extra_brace.js << 'EOF'
const obj = { name: "John" } };
EOF

cat > 37_missing_brace.js << 'EOF'
const obj = { name: "John" ;
EOF

cat > 38_property_with_operator.js << 'EOF'
const obj = { name +: "value" };
EOF

cat > 39_method_missing_brace.js << 'EOF'
const obj = { method() ;
EOF

cat > 40_async_method_error.js << 'EOF'
const obj = { async method };
EOF

cat > 41_template_in_key.js << 'EOF'
const obj = { `key`: "value" };
EOF

cat > 42_regex_as_key.js << 'EOF'
const obj = { /pattern/: "value" };
EOF

cat > 43_number_as_method.js << 'EOF'
const obj = { 123() {} };
EOF

cat > 44_comment_in_key.js << 'EOF'
const obj = { /* comment */: "value" };
EOF

cat > 45_string_no_quote.js << 'EOF'
const obj = { invalid key: "value" };
EOF

cat > 46_hex_property_error.js << 'EOF'
const obj = { 0x: "value" };
EOF

cat > 47_octal_property_error.js << 'EOF'
const obj = { 0o: "value" };
EOF

cat > 48_binary_property_error.js << 'EOF'
const obj = { 0b: "value" };
EOF

cat > 49_exponential_property.js << 'EOF'
const obj = { 1e2: "value" };
EOF

cat > 50_multiple_errors.js << 'EOF'
const obj = { , name: : age: 30,, };
EOF

echo "Generated 50 JavaScript files with Object Literal Syntax Errors in object_tests/"
