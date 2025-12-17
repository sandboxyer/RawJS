#!/bin/bash

mkdir -p declaration_tests
cd declaration_tests

cat > 01_duplicate_let.js << 'EOF'
let x = 5;
let x = 10;
EOF

cat > 02_duplicate_const.js << 'EOF'
const y = 5;
const y = 10;
EOF

cat > 03_mixed_declaration.js << 'EOF'
let a = 5;
var a = 10;
EOF

cat > 04_const_no_initializer.js << 'EOF'
const PI;
EOF

cat > 05_function_reserved_word.js << 'EOF'
function let() {}
EOF

cat > 06_duplicate_function_param.js << 'EOF'
function sum(a, a) {
  return a + a;
}
EOF

cat > 07_generator_invalid.js << 'EOF'
function*() {
  yield 5;
}
EOF

cat > 08_yield_outside_generator.js << 'EOF'
function regular() {
  yield 5;
}
EOF

cat > 09_async_invalid.js << 'EOF'
function async test() {}
EOF

cat > 10_await_outside_async.js << 'EOF'
function regularFunc() {
  await promise;
}
EOF

cat > 11_class_no_name.js << 'EOF'
class {}
EOF

cat > 12_class_invalid_name.js << 'EOF'
class 123 {}
EOF

cat > 13_class_duplicate_constructor.js << 'EOF'
class Rectangle {
  constructor() {}
  constructor() {}
}
EOF

cat > 14_constructor_generator.js << 'EOF'
class BadClass {
  constructor*() {}
}
EOF

cat > 15_constructor_async.js << 'EOF'
class AnotherClass {
  async constructor() {}
}
EOF

cat > 16_class_extends_invalid.js << 'EOF'
class B extends 123 {}
EOF

cat > 17_class_extends_object.js << 'EOF'
class C extends {}
EOF

cat > 18_class_circular_inheritance.js << 'EOF'
class D extends D {}
EOF

cat > 19_class_missing_super.js << 'EOF'
class Parent {}
class Child extends Parent {
  constructor() {
    this.property = 5;
  }
}
EOF

cat > 20_class_this_before_super.js << 'EOF'
class Parent {}
class Child extends Parent {
  constructor() {
    this.property = 5;
    super();
  }
}
EOF

cat > 21_import_invalid_syntax.js << 'EOF'
import from "module";
EOF

cat > 22_import_mixed_default_namespace.js << 'EOF'
import defaultExport, * as namespace from "./module.js";
EOF

cat > 23_export_invalid.js << 'EOF'
export 5;
EOF

cat > 24_export_mixed_declaration.js << 'EOF'
export let x = 5, const y = 10;
EOF

cat > 25_export_conflicting.js << 'EOF'
const x = 5;
export { x };
export let x = 10;
EOF

cat > 26_export_default_const.js << 'EOF'
export default const x = 5;
EOF

cat > 27_object_destructure_invalid.js << 'EOF'
const { x: } = obj;
EOF

cat > 28_object_destructure_missing_name.js << 'EOF'
const { :y } = obj;
EOF

cat > 29_object_destructure_default_error.js << 'EOF'
const { x = } = obj;
EOF

cat > 30_object_rest_not_last.js << 'EOF'
const { x, ...y, z } = obj;
EOF

cat > 31_array_destructure_invalid.js << 'EOF'
const [ ... ] = arr;
EOF

cat > 32_array_rest_not_last.js << 'EOF'
const [ x, ...y, z ] = arr;
EOF

cat > 33_array_destructure_default_error.js << 'EOF'
const [ x = ] = arr;
EOF

cat > 34_for_loop_mixed_declarations.js << 'EOF'
for (let i = 0, let j = 0; i < 10; i++) {}
EOF

cat > 35_for_loop_var_let_mix.js << 'EOF'
for (var i = 0, let j = 0; i < 10; i++) {}
EOF

cat > 36_switch_duplicate_let.js << 'EOF'
switch (value) {
  case 1:
    let x = 5;
    break;
  case 2:
    let x = 10;
    break;
}
EOF

cat > 37_function_param_duplicate.js << 'EOF'
function test(param) {
  let param = 5;
}
EOF

cat > 38_function_param_destructure_error.js << 'EOF'
function test({ x: }) {}
EOF

cat > 39_function_param_default_error.js << 'EOF'
function test(x = ) {}
EOF

cat > 40_function_rest_param_error.js << 'EOF'
function test(...) {}
EOF

cat > 41_function_rest_not_last.js << 'EOF'
function test(x, ...y, z) {}
EOF

cat > 42_arrow_function_no_param.js << 'EOF'
const fn = => x * 2;
EOF

cat > 43_arrow_destructure_no_parens.js << 'EOF'
const fn = {x} => x;
EOF

cat > 44_let_in_same_scope_block.js << 'EOF'
{
  let x = 5;
  let x = 10;
}
EOF

cat > 45_const_reassignment.js << 'EOF'
const obj = {a: 1, b: 2};
for (const prop in obj) {
  prop = "changed";
}
EOF

cat > 46_variable_after_function.js << 'EOF'
function test() {
  var x = 5;
  function x() {}
}
EOF

cat > 47_strict_mode_implicit_global.js << 'EOF'
"use strict";
x = 5;
EOF

cat > 48_strict_mode_octal.js << 'EOF'
"use strict";
const octal = 0123;
EOF

cat > 49_invalid_label.js << 'EOF'
function test() {
  label: const x = 5;
  break label;
}
EOF

cat > 50_async_generator_invalid.js << 'EOF'
async static method() {}
EOF

echo "Generated 50 JavaScript files with declaration syntax errors in declaration_tests/"
