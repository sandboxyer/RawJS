#!/bin/bash

mkdir -p async_tests
cd async_tests

cat > 01_missing_async_keyword_semicolon.js << 'EOF'
async;
EOF

cat > 02_async_function_missing_name.js << 'EOF'
async function;
EOF

cat > 03_async_const_no_function.js << 'EOF'
async const x = 5;
EOF

cat > 04_async_let_no_function.js << 'EOF'
async let y = await fetch();
EOF

cat > 05_async_console_no_function.js << 'EOF'
async console.log("test");
EOF

cat > 06_function_async_wrong_order.js << 'EOF'
function async test() {}
EOF

cat > 07_double_async_keyword.js << 'EOF'
async async function foo() {}
EOF

cat > 08_async_async_arrow.js << 'EOF'
async async () => {}
EOF

cat > 09_await_outside_async.js << 'EOF'
await fetch('/api');
EOF

cat > 10_await_in_regular_function.js << 'EOF'
function regularFunction() {
  await fetch('/api');
}
EOF

cat > 11_await_in_arrow_no_async.js << 'EOF'
const arrowFn = () => {
  await getData();
}
EOF

cat > 12_await_in_class_constructor.js << 'EOF'
class MyClass {
  constructor() {
    await this.init();
  }
}
EOF

cat > 13_await_in_getter.js << 'EOF'
class Example {
  get data() {
    await fetch();
  }
}
EOF

cat > 14_await_in_setter.js << 'EOF'
class Example {
  set value(val) {
    await process(val);
  }
}
EOF

cat > 15_await_in_eval.js << 'EOF'
eval('await Promise.resolve()');
EOF

cat > 16_await_no_expression.js << 'EOF'
async function test() {
  await;
}
EOF

cat > 17_await_space_no_expression.js << 'EOF'
async function test() {
  await ;
}
EOF

cat > 18_double_await.js << 'EOF'
async function test() {
  await await fetch();
}
EOF

cat > 19_async_arrow_missing_paren_await.js << 'EOF'
async x await fetch(x);
EOF

cat > 20_async_arrow_missing_arrow.js << 'EOF'
async (x) fetch(x);
EOF

cat > 21_async_arrow_missing_param.js << 'EOF'
async (x, , z) => {}
EOF

cat > 22_async_arrow_invalid_param.js << 'EOF'
async (x y) => {}
EOF

cat > 23_async_arrow_rest_with_await.js << 'EOF'
async (...rest await) => {}
EOF

cat > 24_async_arrow_await_concise_no_paren.js << 'EOF'
async x => await fetch(x);
EOF

cat > 25_async_class_getter.js << 'EOF'
class MyClass {
  async get data() {}
}
EOF

cat > 26_async_class_setter.js << 'EOF'
class MyClass {
  async set value(v) {}
}
EOF

cat > 27_async_constructor.js << 'EOF'
class MyClass {
  async constructor() {}
}
EOF

cat > 28_async_object_literal_invalid.js << 'EOF'
const obj = {
  "async method"() {}
}
EOF

cat > 29_async_generator_wrong_order.js << 'EOF'
async * function gen() {}
EOF

cat > 30_async_function_star_missing_name.js << 'EOF'
async function*() {}
EOF

cat > 31_async_star_arrow.js << 'EOF'
async*() => {}
EOF

cat > 32_async_generator_yield_await.js << 'EOF'
async function* mixed() {
  yield await;
}
EOF

cat > 33_async_generator_await_yield.js << 'EOF'
async function* mixed() {
  await yield 5;
}
EOF

cat > 34_async_iife_missing_paren.js << 'EOF'
async function() {}();
EOF

cat > 35_async_arrow_iife_missing_paren.js << 'EOF'
async () => {}();
EOF

cat > 36_async_iife_extra_paren.js << 'EOF'
(async function() {})());
EOF

cat > 37_async_iife_invalid_syntax.js << 'EOF'
(async () => {};())
EOF

cat > 38_async_param_await_default.js << 'EOF'
async function test(a = await getDefault()) {}
EOF

cat > 39_async_param_destructure_await.js << 'EOF'
async function test({ data = await fetch() }) {}
EOF

cat > 40_async_param_rest_await.js << 'EOF'
async function test(...await args) {}
EOF

cat > 41_async_catch_param_await_default.js << 'EOF'
async function test() {
  try {
    await riskyOperation();
  } catch (e = await getDefaultError()) {
    console.error(e);
  }
}
EOF

cat > 42_async_catch_await_param.js << 'EOF'
async function test() {
  try {
    await operation();
  } catch (await e) {
    console.error(e);
  }
}
EOF

cat > 43_array_map_missing_async.js << 'EOF'
const results = data.map(item => {
  return await process(item);
});
EOF

cat > 44_event_handler_missing_async.js << 'EOF'
button.addEventListener('click', function() {
  await fetchData();
});
EOF

cat > 45_promise_then_missing_async.js << 'EOF'
async function process() {
  return fetch(url)
    .then(response => response.json())
    .then(data => {
      await processMore(data);
    });
}
EOF

cat > 46_async_with_label.js << 'EOF'
async: function test() {}
EOF

cat > 47_async_in_for_loop.js << 'EOF'
for (async let i = 0; i < 10; i++) {}
EOF

cat > 48_async_in_switch.js << 'EOF'
switch (async x) {
  case await y:
    break;
}
EOF

cat > 49_async_with_void.js << 'EOF'
void async = 5;
EOF

cat > 50_async_in_template_literal.js << 'EOF'
`Result: ${async x => x}`
// This is actually valid, testing edge case
async function test() {
  return `Result: ${await fetch()}`;
}
EOF

echo "Generated 50 JavaScript files with async function syntax errors in async_tests/"
