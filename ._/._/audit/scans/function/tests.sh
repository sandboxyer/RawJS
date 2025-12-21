#!/bin/bash

mkdir -p function_tests
cd function_tests

cat > 01_missing_function_name.js << 'EOF'
function () {
    return "anonymous";
}
EOF

cat > 02_invalid_number_function.js << 'EOF'
function 123() {
    return "invalid";
}
EOF

cat > 03_hyphen_function_name.js << 'EOF'
function my-function() {
    return "dash";
}
EOF

cat > 04_reserved_word_function.js << 'EOF'
function yield() {
    return "reserved";
}
EOF

cat > 05_let_function_name.js << 'EOF'
function let() {
    return "keyword";
}
EOF

cat > 06_missing_parens.js << 'EOF'
function test {
    return "missing parens";
}
EOF

cat > 07_missing_brace.js << 'EOF'
function test()
    return "missing brace";
EOF

cat > 08_unclosed_paren.js << 'EOF'
function test( {
    return "missing closing paren";
}
EOF

cat > 09_wrong_paren_order.js << 'EOF'
function test) {
    return "wrong order";
}
EOF

cat > 10_double_comma_params.js << 'EOF'
function test(param1, param2,, param3) {
    return "double comma";
}
EOF

cat > 11_semicolon_in_params.js << 'EOF'
function test(param1; param2) {
    return "semicolon instead of comma";
}
EOF

cat > 12_missing_default_value.js << 'EOF'
function test(param1 = ) {
    return "missing default value";
}
EOF

cat > 13_incomplete_rest.js << 'EOF'
function test(...) {
    return "incomplete rest";
}
EOF

cat > 14_rest_not_last.js << 'EOF'
function test(param1, ...rest, param2) {
    return "rest not last";
}
EOF

cat > 15_destructuring_missing_name.js << 'EOF'
function test({name: , age}) {
    return "missing property name";
}
EOF

cat > 16_destructuring_missing_default.js << 'EOF'
function test({name: firstName = }) {
    return "missing default value";
}
EOF

cat > 17_array_destructure_extra_comma.js << 'EOF'
function test([first, ,, fourth]) {
    return "too many commas";
}
EOF

cat > 18_no_braces_function.js << 'EOF'
function test() 
    return "no braces";
EOF

cat > 19_unterminated_function.js << 'EOF'
function test() {
    return "correct";
EOF

cat > 20_reserved_in_function.js << 'EOF'
function test() {
    const function = "reserved";
}
EOF

cat > 21_let_as_variable.js << 'EOF'
function test() {
    let let = 5;
}
EOF

cat > 22_yield_not_generator.js << 'EOF'
function test() {
    yield 5;
}
EOF

cat > 23_generator_wrong_asterisk.js << 'EOF'
function test*() {
    yield 1;
}
EOF

cat > 24_async_wrong_order.js << 'EOF'
function async test() {
    return "wrong order";
}
EOF

cat > 25_missing_async_keyword.js << 'EOF'
async test() {
    return "missing function keyword";
}
EOF

cat > 26_await_not_async.js << 'EOF'
function test() {
    await Promise.resolve(5);
}
EOF

cat > 27_await_in_nested.js << 'EOF'
async function test() {
    function inner() {
        await Promise.resolve(5);
    }
}
EOF

cat > 28_arrow_as_declaration.js << 'EOF'
function test = () => {
    return "mixing syntax";
}
EOF

cat > 29_wrong_arrow_placement.js << 'EOF'
function test() => {
    return "wrong arrow placement";
}
EOF

cat > 30_arrow_missing_parens.js << 'EOF'
const test = param1, param2 => {
    return param1 + param2;
}
EOF

cat > 31_nested_missing_name.js << 'EOF'
function outer() {
    function {
        return "missing name";
    }
}
EOF

cat > 32_iife_missing_wrapper.js << 'EOF'
function() {
    console.log("missing wrapper");
}();
EOF

cat > 33_object_method_wrong.js << 'EOF'
const obj = {
    function wrong() {
        return "syntax error";
    }
};
EOF

cat > 34_getter_missing_parens.js << 'EOF'
const obj = {
    get value {
        return "missing parentheses";
    }
};
EOF

cat > 35_setter_missing_param.js << 'EOF'
const obj = {
    set value() {
        this._value = newVal;
    }
};
EOF

cat > 36_class_method_wrong.js << 'EOF'
class MyClass {
    function constructor() {
        this.value = 5;
    }
}
EOF

cat > 37_class_constructor_no_brace.js << 'EOF'
class MyClass {
    constructor()
        this.value = 5;
    }
}
EOF

cat > 38_duplicate_constructor.js << 'EOF'
class MyClass {
    constructor() {
        this.a = 1;
    }
    
    constructor() {
        this.b = 2;
    }
}
EOF

cat > 39_static_wrong_placement.js << 'EOF'
class MyClass {
    static() {
        return "static as method name";
    }
}
EOF

cat > 40_async_generator_mix.js << 'EOF'
async function* test() {
    await yield 5;
}
EOF

cat > 41_function_in_if.js << 'EOF'
if (true) function test() { }
EOF

cat > 42_function_in_loop.js << 'EOF'
for (let i = 0; i < 10; i++) function test() { }
EOF

cat > 43_default_param_expression_error.js << 'EOF'
function test(a = (() => { return })()) {
    return a;
}
EOF

cat > 44_param_destructure_error.js << 'EOF'
function test({a, b = ) {
    return a + b;
}
EOF

cat > 45_rest_param_destructure.js << 'EOF'
function test(...[a, b]) {
    return a + b;
}
// This is actually valid, but let's test edge cases
function test2(...{a, b}) {
    return a + b;
}
EOF

cat > 46_generator_yield_star_error.js << 'EOF'
function* test() {
    yield*;
}
EOF

cat > 47_async_await_together_error.js << 'EOF'
async function test() {
    async await Promise.resolve();
}
EOF

cat > 48_function_name_unicode_invalid.js << 'EOF'
function .test() {
    return "dot start";
}
EOF

cat > 49_arrow_no_body.js << 'EOF'
const test = () =>
EOF

cat > 50_mixed_function_types.js << 'EOF'
function* async test() {
    yield await 5;
}
EOF

echo "Generated 50 JavaScript files with function declaration errors in function_tests/"
