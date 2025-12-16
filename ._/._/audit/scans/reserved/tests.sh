#!/bin/bash

mkdir -p reserved_tests
cd reserved_tests

cat > 01_class_variable_strict.js << 'EOF'
"use strict";
let class = "Math";
EOF

cat > 02_function_variable_strict.js << 'EOF'
"use strict";
const function = "test";
EOF

cat > 03_let_variable.js << 'EOF'
let let = 5;
EOF

cat > 04_const_variable.js << 'EOF'
const const = 10;
EOF

cat > 05_await_outside_async.js << 'EOF'
function test() {
    await Promise.resolve();
}
EOF

cat > 06_yield_outside_generator.js << 'EOF'
function test() {
    yield 5;
}
EOF

cat > 07_import_reserved_no_rename.js << 'EOF'
import { class } from './module.js';
EOF

cat > 08_export_reserved_no_rename.js << 'EOF'
export const default = 5;
EOF

cat > 09_static_method_parameter.js << 'EOF'
"use strict";
function test(static) {
    return static;
}
EOF

cat > 10_implements_variable_strict.js << 'EOF'
"use strict";
let implements = "interface";
EOF

cat > 11_interface_variable_strict.js << 'EOF'
"use strict";
const interface = {};
EOF

cat > 12_package_variable_strict.js << 'EOF'
"use strict";
var package = "com.test";
EOF

cat > 13_private_variable_strict.js << 'EOF'
"use strict";
let private = "secret";
EOF

cat > 14_protected_variable_strict.js << 'EOF'
"use strict";
const protected = "data";
EOF

cat > 15_public_variable_strict.js << 'EOF'
"use strict";
let public = "info";
EOF

cat > 16_enum_variable_strict.js << 'EOF'
"use strict";
const enum = {RED: 1, BLUE: 2};
EOF

cat > 17_await_top_level_non_module.js << 'EOF'
// Not a module
await fetch('/api');
EOF

cat > 18_yield_arrow_function.js << 'EOF'
const fn = () => {
    yield 42;
};
EOF

cat > 19_arguments_in_arrow_strict.js << 'EOF'
"use strict";
const fn = () => {
    let arguments = [1, 2, 3];
};
EOF

cat > 20_eval_variable_strict.js << 'EOF'
"use strict";
let eval = "dangerous";
EOF

cat > 21_arguments_variable_strict.js << 'EOF'
"use strict";
const arguments = [];
EOF

cat > 22_delete_method_parameter.js << 'EOF'
"use strict";
function test(delete) {
    return delete;
}
EOF

cat > 23_new_variable_strict.js << 'EOF'
"use strict";
let new = "object";
EOF

cat > 24_in_variable.js << 'EOF'
let in = "operator";
EOF

cat > 25_of_variable.js << 'EOF'
const of = [1, 2, 3];
EOF

cat > 26_instanceof_variable.js << 'EOF'
let instanceof = "check";
EOF

cat > 27_typeof_variable.js << 'EOF'
const typeof = "operator";
EOF

cat > 28_void_variable.js << 'EOF'
let void = undefined;
EOF

cat > 29_debugger_variable.js << 'EOF'
const debugger = "tool";
EOF

cat > 30_with_variable.js << 'EOF'
let with = "statement";
EOF

cat > 31_export_named_reserved.js << 'EOF'
export let class = "invalid";
EOF

cat > 32_async_outside_function.js << 'EOF'
async = "keyword";
EOF

cat > 33_get_variable.js << 'EOF'
let get = "accessor";
EOF

cat > 34_set_variable.js << 'EOF'
const set = "mutator";
EOF

cat > 35_var_reserved.js << 'EOF'
var yield = "generator";
EOF

cat > 36_break_variable.js << 'EOF'
let break = "statement";
EOF

cat > 37_case_variable.js << 'EOF'
const case = "switch";
EOF

cat > 38_catch_variable.js << 'EOF'
let catch = "error";
EOF

cat > 39_continue_variable.js << 'EOF'
const continue = "loop";
EOF

cat > 40_default_variable.js << 'EOF'
let default = "value";
EOF

cat > 41_do_variable.js << 'EOF'
const do = "while";
EOF

cat > 42_else_variable.js << 'EOF'
let else = "conditional";
EOF

cat > 43_finally_variable.js << 'EOF'
const finally = "cleanup";
EOF

cat > 44_for_variable.js << 'EOF'
let for = "loop";
EOF

cat > 45_if_variable.js << 'EOF'
const if = "conditional";
EOF

cat > 46_return_variable.js << 'EOF'
let return = "value";
EOF

cat > 47_switch_variable.js << 'EOF'
const switch = "statement";
EOF

cat > 48_throw_variable.js << 'EOF'
let throw = "error";
EOF

cat > 49_try_variable.js << 'EOF'
const try = "attempt";
EOF

cat > 50_while_variable.js << 'EOF'
let while = "loop";
EOF

cat > 51_double_await.js << 'EOF'
async function test() {
    let await = "not allowed";
    await Promise.resolve();
}
EOF

cat > 52_class_name_reserved.js << 'EOF'
class let {
    constructor() {}
}
EOF

cat > 53_extend_reserved.js << 'EOF'
class MyClass extends null {
    let() {}
}
EOF

cat > 54_computed_property_reserved.js << 'EOF'
const obj = {
    [class]: "invalid"
};
EOF

cat > 55_strict_mode_eval.js << 'EOF'
"use strict";
eval('var interface = 5;');
EOF

cat > 56_unicode_reserved.js << 'EOF'
"use strict";
const \u0063\u006c\u0061\u0073\u0073 = "Math";
EOF

cat > 57_future_reserved_es3.js << 'EOF'
"use strict";
const int = 5;
EOF

cat > 58_module_export_default.js << 'EOF'
export default = 5;
EOF

cat > 59_import_star_reserved.js << 'EOF'
import * as class from './module.js';
EOF

cat > 60_dynamic_import_reserved.js << 'EOF'
const import = "keyword";
EOF

echo "Generated 60 JavaScript files with reserved word errors in reserved_tests/"
