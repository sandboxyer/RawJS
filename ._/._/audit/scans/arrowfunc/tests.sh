#!/bin/bash

# Arrow Function Syntax Error Test Generator
# Creates 50 JavaScript files with various arrow function syntax errors

mkdir -p basics_tests
cd basics_tests

echo "Generating 50 JavaScript files with arrow function syntax errors..."

cat > 01_missing_arrow.js << 'EOF'
// Missing arrow token
const func = (x, y) { return x + y; }
EOF

cat > 02_wrong_arrow_symbol.js << 'EOF'
// Wrong arrow symbol
const func = (x, y) -> x + y;
EOF

cat > 03_wrong_equals.js << 'EOF'
// Using = instead of =>
const func = (x, y) = x + y;
EOF

cat > 04_double_arrow.js << 'EOF'
// Double arrow
const func = x => => y;
EOF

cat > 05_arrow_at_start.js << 'EOF'
// Arrow at start
const func = => x + y;
EOF

cat > 06_missing_parens_single_param.js << 'EOF'
// Single parameter without parentheses but with comma
const func = x, y => x + y;
EOF

cat > 07_zero_params_no_parens.js << 'EOF'
// Zero parameters without parentheses
const greet = => "Hello";
EOF

cat > 08_multiple_params_no_parens.js << 'EOF'
// Multiple parameters without parentheses
const add = x, y => x + y;
EOF

cat > 09_empty_params_with_comma.js << 'EOF'
// Empty parameter list with comma
const func = (,) => {};
EOF

cat > 10_double_comma_params.js << 'EOF'
// Double comma in parameters
const func = (x,,) => x;
EOF

cat > 11_missing_param_name.js << 'EOF'
// Missing parameter name
const func = (x, , z) => x + z;
EOF

cat > 12_duplicate_parameters.js << 'EOF'
// Duplicate parameter names
const func = (x, x) => x * 2;
EOF

cat > 13_destructuring_no_parens.js << 'EOF'
// Destructuring without parentheses
const func = {x, y} => x + y;
EOF

cat > 14_array_destructure_no_parens.js << 'EOF'
// Array destructuring without parentheses
const func = [x, y] => x + y;
EOF

cat > 15_incomplete_destructuring.js << 'EOF'
// Incomplete destructuring pattern
const func = ({x: , y}) => x + y;
EOF

cat > 16_malformed_destructuring.js << 'EOF'
// Malformed destructuring with arrow in wrong place
const func = ({x, y} =>) x + y;
EOF

cat > 17_block_body_no_return.js << 'EOF'
// Block body with implicit return attempt
const double = x => { x * 2 };
EOF

cat > 18_block_body_with_operator.js << 'EOF'
// Block body followed by operator
const func = x => { x * 2 } + 5;
EOF

cat > 19_block_body_with_property.js << 'EOF'
// Trying to call method on block body
const func = x => { x * 2 }.toString();
EOF

cat > 20_object_return_no_parens.js << 'EOF'
// Returning object literal without parentheses
const getUser = () => { name: "John", age: 30 };
EOF

cat > 21_label_in_block.js << 'EOF'
// Block with label (interpreted as label, not object)
const getUser = () => { name: "John" };
EOF

cat > 22_method_missing_parens.js << 'EOF'
// Object method without parentheses
const obj = {
    method: => {}
};
EOF

cat > 23_async_wrong_position.js << 'EOF'
// Async in wrong position
const fetchData = () async => fetch();
EOF

cat > 24_async_missing_parens.js << 'EOF'
// Async arrow without parentheses
const fetchData = async => url => fetch(url);
EOF

cat > 25_async_await_only.js << 'EOF'
// Async with only await keyword
const fetchData = async () => await;
EOF

cat > 26_generator_arrow.js << 'EOF'
// Arrow function trying to be generator
const gen = *() => { yield 1; };
EOF

cat > 27_yield_in_arrow.js << 'EOF'
// Yield in regular arrow function
const gen = () => { yield 1; };
EOF

cat > 28_yield_star_in_arrow.js << 'EOF'
// Yield* in regular arrow function
const gen = () => { yield* [1, 2, 3]; };
EOF

cat > 29_rest_param_wrong_position.js << 'EOF'
// Rest parameter only
const func = ...args => args;
EOF

cat > 30_rest_param_after_comma.js << 'EOF'
// Rest parameter not last
const func = (...args, last) => args;
EOF

cat > 31_immediate_invoke_wrong.js << 'EOF'
// Wrong IIFE syntax
() => console.log("IIFE")();
EOF

cat > 32_block_iife_wrong.js << 'EOF'
// Block body IIFE wrong syntax
() => { console.log("IIFE") }();
EOF

cat > 33_conditional_missing_function.js << 'EOF'
// Conditional with missing function
const func = condition ? x => x * 2 : ;
EOF

cat > 34_conditional_arrow_at_start.js << 'EOF'
// Arrow at start in conditional
const func = condition ? => x * 2 : y => y * 3;
EOF

cat > 35_default_param_arrow_wrong.js << 'EOF'
// Default parameter with wrong arrow syntax
const func = (callback = => x * 2) => callback;
EOF

cat > 36_nested_arrow_wrong.js << 'EOF'
// Nested arrow function error
const func = x => => y => z;
EOF

cat > 37_missing_param_after_default.js << 'EOF'
// Missing parameter after default value
const func = (x = 5, ) => x;
EOF

cat > 38_trailing_comma_error.js << 'EOF'
// Trailing comma without preceding parameter
const func = (, x) => x;
EOF

cat > 39_comma_only.js << 'EOF'
// Only comma as parameter
const func = (,) => {};
EOF

cat > 40_missing_arrow_after_parens.js << 'EOF'
// Missing arrow after parentheses
const func = (x, y)
  x + y;
EOF

cat > 41_arrow_in_wrong_context.js << 'EOF'
// Arrow in class method without field syntax
class MyClass {
    method() => console.log("test");
}
EOF

cat > 42_missing_body.js << 'EOF'
// Missing function body
const func = x => ;
EOF

cat > 43_missing_body_with_brace.js << 'EOF'
// Missing body after brace
const func = x => {;
EOF

cat > 44_extra_brace.js << 'EOF'
// Extra closing brace
const func = x => { return x; }};
EOF

cat > 45_array_method_missing_param.js << 'EOF'
// Array method with missing parameter
const doubled = [1,2,3].map(=> n * 2);
EOF

cat > 46_promise_missing_param.js << 'EOF'
// Promise chain with missing parameter
fetch(url).then(=> response.json());
EOF

cat > 47_event_handler_error.js << 'EOF'
// Event handler with missing parentheses for object return
const handler = () => {count: count + 1};
EOF

cat > 48_multiline_arrow_error.js << 'EOF'
// Multiline arrow with missing return
const func = x => {
    x * 2
    // No return statement
};
EOF

cat > 49_arrow_with_semicolon_error.js << 'EOF'
// Semicolon in wrong place
const func = x => ; x * 2;
EOF

cat > 50_complex_nested_error.js << 'EOF'
// Complex nested error
const func = x => y => => z;
EOF

echo "Generated 50 JavaScript files with arrow function syntax errors in basics_tests/"
echo "Run: ./arrowfunc.sh --test to test the scanner"
