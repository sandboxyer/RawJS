#!/bin/bash

# Generator Function Syntax Error Test Generator
# Creates 50 JavaScript files with generator-related syntax errors

mkdir -p generator_tests
cd generator_tests

echo "Generating 50 JavaScript files with generator syntax errors..."

# 1. Missing asterisk in generator function
cat > 01_missing_asterisk.js << 'EOF'
function generator() {
    yield 1;
}
EOF

# 2. Asterisk in wrong position
cat > 02_wrong_asterisk_position.js << 'EOF'
function generator*() {
    yield 1;
}
EOF

# 3. Multiple asterisks
cat > 03_double_asterisk.js << 'EOF'
function** generator() {
    yield 1;
}
EOF

# 4. yield in normal function
cat > 04_yield_in_normal_function.js << 'EOF'
function normalFunc() {
    yield 42;
}
EOF

# 5. yield at top level
cat > 05_yield_top_level.js << 'EOF'
yield 42;
EOF

# 6. yield in arrow function
cat > 06_yield_in_arrow.js << 'EOF'
const arrow = () => {
    yield 42;
};
EOF

# 7. yield* without expression
cat > 07_yield_star_no_expr.js << 'EOF'
function* gen() {
    yield*;
}
EOF

# 8. yield with bad precedence
cat > 08_yield_bad_precedence.js << 'EOF'
function* gen() {
    yield 1 + yield 2;
}
EOF

# 9. Generator method with asterisk after name
cat > 09_method_asterisk_wrong.js << 'EOF'
const obj = {
    generator*() {
        yield 1;
    }
};
EOF

# 10. Class generator method error
cat > 10_class_method_error.js << 'EOF'
class MyClass {
    generator*() {
        yield 1;
    }
}
EOF

# 11. yield as variable name in generator
cat > 11_yield_as_variable.js << 'EOF'
function* gen() {
    let yield = 5;
}
EOF

# 12. return as variable in generator
cat > 12_return_as_variable.js << 'EOF'
function* gen() {
    let return = 5;
}
EOF

# 13. throw as variable in generator
cat > 13_throw_as_variable.js << 'EOF'
function* gen() {
    let throw = "error";
}
EOF

# 14. Async without asterisk
cat > 14_async_no_asterisk.js << 'EOF'
async function generator() {
    yield 1;
}
EOF

# 15. Asterisk without function
cat > 15_asterisk_no_function.js << 'EOF'
* generator() {
    yield 1;
}
EOF

# 16. Generator with no body
cat > 16_no_body.js << 'EOF'
function* generator();
EOF

# 17. yield in parameter default
cat > 17_yield_in_param.js << 'EOF'
function* gen(x = yield 42) {
    yield x;
}
EOF

# 18. yield* in parameter default
cat > 18_yield_star_in_param.js << 'EOF'
function* gen(x = yield* [1,2,3]) {
    yield x;
}
EOF

# 19. await yield mixup
cat > 19_await_yield_mix.js << 'EOF'
async function* gen() {
    await yield 1;
}
EOF

# 20. yield await yield error
cat > 20_yield_await_yield.js << 'EOF'
async function* gen() {
    yield await yield 2;
}
EOF

# 21. Generator expression missing asterisk
cat > 21_gen_expr_no_asterisk.js << 'EOF'
const gen = function() {
    yield 1;
};
EOF

# 22. Arrow generator attempt
cat > 22_arrow_generator.js << 'EOF'
const gen = *() => {
    yield 1;
};
EOF

# 23. yield in finally with return
cat > 23_yield_finally_return.js << 'EOF'
function* gen() {
    try {
        return 1;
    } finally {
        yield 2;
    }
}
EOF

# 24. yield in eval in strict mode
cat > 24_yield_in_eval.js << 'EOF'
"use strict";
function* gen() {
    eval("yield 1;");
}
EOF

# 25. New generator constructor
cat > 25_new_generator.js << 'EOF'
function* Generator() {
    yield 1;
}
new Generator();
EOF

# 26. yield* with non-iterable
cat > 26_yield_star_non_iterable.js << 'EOF'
function* gen() {
    yield* 42;
}
EOF

# 27. yield* null
cat > 27_yield_star_null.js << 'EOF'
function* gen() {
    yield* null;
}
EOF

# 28. yield* undefined
cat > 28_yield_star_undefined.js << 'EOF'
function* gen() {
    yield* undefined;
}
EOF

# 29. Missing yield expression
cat > 29_missing_yield_expr.js << 'EOF'
function* gen() {
    yield ;
}
EOF

# 30. yield with spread error
cat > 30_yield_spread_error.js << 'EOF'
function* gen() {
    yield ...[1,2,3];
}
EOF

# 31. Generator with computed property wrong
cat > 31_computed_property_wrong.js << 'EOF'
const obj = {
    *["gen"] { }
};
EOF

# 32. Generator property missing parens
cat > 32_missing_parens.js << 'EOF'
const obj = {
    *gen { }
};
EOF

# 33. yield in template tag
cat > 33_yield_template_tag.js << 'EOF'
function* gen() {
    yield`test`;
}
EOF

# 34. yield* with await
cat > 34_yield_star_await.js << 'EOF'
async function* gen() {
    yield* await getGenerator();
}
EOF

# 35. Generator in if statement
cat > 35_gen_in_if.js << 'EOF'
if (function*() { yield 1; }) {
    // 
}
EOF

# 36. yield in for loop initializer
cat > 36_yield_in_for_init.js << 'EOF'
function* gen() {
    for (let i = yield 0; i < 10; i++) {
        yield i;
    }
}
EOF

# 37. yield in while condition
cat > 37_yield_in_while.js << 'EOF'
function* gen() {
    while (yield true) {
        yield 1;
    }
}
EOF

# 38. Generator with rest param yield
cat > 38_rest_param_yield.js << 'EOF'
function* gen(...yield args) {
    yield args.length;
}
EOF

# 39. yield with label
cat > 39_yield_with_label.js << 'EOF'
function* gen() {
    label: yield 1;
}
EOF

# 40. Complex yield expression error
cat > 40_complex_yield_error.js << 'EOF'
function* gen() {
    yield function*() {
        yield 1;
    };
}
EOF

# 41. Async generator missing yield
cat > 41_async_gen_no_yield.js << 'EOF'
async function* gen() {
    await Promise.resolve(1);
    return 2;
}
EOF

# 42. yield* in arrow in generator
cat > 42_yield_star_in_arrow.js << 'EOF'
function* outer() {
    const inner = () => {
        yield* [1,2,3];
    };
}
EOF

# 43. Generator with illegal break
cat > 43_illegal_break.js << 'EOF'
function* gen() {
    break;
    yield 1;
}
EOF

# 44. yield in switch case
cat > 44_yield_in_case.js << 'EOF'
function* gen(x) {
    switch (x) {
        case yield 1:
            yield 2;
    }
}
EOF

# 45. Generator with continue error
cat > 45_continue_error.js << 'EOF'
function* gen() {
    continue;
    yield 1;
}
EOF

# 46. yield in do-while
cat > 46_yield_in_do_while.js << 'EOF'
function* gen() {
    do {
        yield 1;
    } while (yield true);
}
EOF

# 47. Generator with debugger yield
cat > 47_debugger_yield.js << 'EOF'
function* gen() {
    debugger yield 1;
}
EOF

# 48. yield with new.target
cat > 48_yield_new_target.js << 'EOF'
function* gen() {
    yield new.target;
}
EOF

# 49. Generator with import.meta
cat > 49_yield_import_meta.js << 'EOF'
function* gen() {
    yield import.meta.url;
}
EOF

# 50. Complex nested yield error
cat > 50_complex_nested_error.js << 'EOF'
function* gen() {
    yield function*() {
        yield* yield 1;
    };
}
EOF

echo "Generated 50 JavaScript files with generator syntax errors in generator_tests/"
echo "Run: ./generator.sh --test"
