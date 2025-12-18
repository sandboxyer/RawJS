#!/bin/bash

mkdir -p params_tests
cd params_tests

cat > 01_missing_function_parens.js << 'EOF'
function test { return 5; }
EOF

cat > 02_mismatched_parens.js << 'EOF'
function test) { return 5; }
EOF

cat > 03_extra_comma_empty.js << 'EOF'
function test(,) { return 5; }
EOF

cat > 04_semicolon_in_params.js << 'EOF'
function test(a;b) { return a + b; }
EOF

cat > 05_double_comma.js << 'EOF'
function test(a,,b) { return a + b; }
EOF

cat > 06_missing_comma.js << 'EOF'
function test(a b) { return a + b; }
EOF

cat > 07_invalid_param_name_number.js << 'EOF'
function test(123) { return 123; }
EOF

cat > 08_invalid_param_name_hyphen.js << 'EOF'
function test(my-param) { return my-param; }
EOF

cat > 09_reserved_word_param.js << 'EOF'
function test(let) { return let; }
EOF

cat > 10_trailing_semicolon.js << 'EOF'
function test(a;) { return a; }
EOF

cat > 11_missing_default_value.js << 'EOF'
function test(a = ) { return a; }
EOF

cat > 12_invalid_default_expression.js << 'EOF'
function test(a = let x = 5) { return a; }
EOF

cat > 13_malformed_default_comma.js << 'EOF'
function test(a = , b = 5) { return a + b; }
EOF

cat > 14_object_destructure_missing_comma.js << 'EOF'
function test({name age}) { return name + age; }
EOF

cat > 15_object_destructure_missing_colon.js << 'EOF'
function test({name:}) { return name; }
EOF

cat > 16_object_destructure_empty_rest.js << 'EOF'
function test({...}) { return; }
EOF

cat > 17_rest_not_last_object.js << 'EOF'
function test({...rest, name}) { return; }
EOF

cat > 18_array_destructure_missing_comma.js << 'EOF'
function test([first second]) { return first + second; }
EOF

cat > 19_array_rest_not_last.js << 'EOF'
function test([...rest, last]) { return; }
EOF

cat > 20_rest_param_empty.js << 'EOF'
function test(...) { return; }
EOF

cat > 21_multiple_rest_params.js << 'EOF'
function test(...a, ...b) { return; }
EOF

cat > 22_rest_param_not_last.js << 'EOF'
function test(a, ...b, c) { return; }
EOF

cat > 23_arrow_no_parens_multiple.js << 'EOF'
const test = x, y => { return x + y; }
EOF

cat > 24_arrow_empty_params.js << 'EOF'
const test = => { return 5; }
EOF

cat > 25_arrow_destructure_no_parens.js << 'EOF'
const test = {x} => { return x; }
EOF

cat > 26_arrow_default_no_parens.js << 'EOF'
const test = x = 5 => { return x; }
EOF

cat > 27_method_semicolon_params.js << 'EOF'
class MyClass {
    method(;) { return 5; }
}
EOF

cat > 28_method_missing_comma.js << 'EOF'
class MyClass {
    method(x y) { return x + y; }
}
EOF

cat > 29_constructor_semicolon.js << 'EOF'
class MyClass {
    constructor(;) { }
}
EOF

cat > 30_constructor_missing_comma.js << 'EOF'
class MyClass {
    constructor(x y) { }
}
EOF

cat > 31_constructor_empty_rest.js << 'EOF'
class MyClass {
    constructor(...) { }
}
EOF

cat > 32_generator_missing_comma.js << 'EOF'
function* test(x y) { yield x + y; }
EOF

cat > 33_generator_extra_comma.js << 'EOF'
function* test(,) { yield 5; }
EOF

cat > 34_async_missing_comma.js << 'EOF'
async function test(x y) { return x + y; }
EOF

cat > 35_async_semicolon.js << 'EOF'
async function test(;) { return 5; }
EOF

cat > 36_async_arrow_no_parens.js << 'EOF'
const test = async x, y => { return x + y; }
EOF

cat > 37_async_arrow_empty.js << 'EOF'
const test = async => { return 5; }
EOF

cat > 38_strict_mode_eval_param.js << 'EOF'
"use strict";
function test(eval) { return eval; }
EOF

cat > 39_strict_mode_arguments_param.js << 'EOF'
"use strict";
function test(arguments) { return arguments; }
EOF

cat > 40_duplicate_params_strict.js << 'EOF'
"use strict";
function test(x, x) { return x; }
EOF

cat > 41_duplicate_params_arrow.js << 'EOF'
const test = (x, x) => { return x; }
EOF

cat > 42_getter_with_params.js << 'EOF'
const obj = {
    get value(x) { return x; }
}
EOF

cat > 43_setter_no_params.js << 'EOF'
const obj = {
    set value() { }
}
EOF

cat > 44_setter_too_many_params.js << 'EOF'
const obj = {
    set value(x, y) { }
}
EOF

cat > 45_class_getter_with_params.js << 'EOF'
class MyClass {
    get value(x) { return x; }
}
EOF

cat > 46_class_setter_wrong_params.js << 'EOF'
class MyClass {
    set value() { }
}
EOF

cat > 47_computed_property_malformed.js << 'EOF'
function test({[prop}) { return prop; }
EOF

cat > 48_nested_destructure_error.js << 'EOF'
function test({x: {y z}}) { return y + z; }
EOF

cat > 49_default_with_destructure_error.js << 'EOF'
function test({x = }) { return x; }
EOF

cat > 50_parameter_after_rest.js << 'EOF'
function test(...rest, lastParam) { return; }
EOF

echo "Generated 50 JavaScript files with parameter syntax errors in params_tests/"
