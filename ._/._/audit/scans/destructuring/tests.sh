#!/bin/bash

mkdir -p destructuring_tests
cd destructuring_tests

cat > 01_empty_destructuring.js << 'EOF'
const = obj;
EOF

cat > 02_incomplete_object_pattern.js << 'EOF'
const { = obj;
EOF

cat > 03_incomplete_array_pattern.js << 'EOF'
const [ = arr;
EOF

cat > 04_double_comma_object.js << 'EOF'
const {a,,b} = obj;
EOF

cat > 05_leading_comma_object.js << 'EOF'
const {,a,b} = obj;
EOF

cat > 06_triple_comma_array.js << 'EOF'
const [a,,,b] = arr;
EOF

cat > 07_middle_rest_array.js << 'EOF'
const [...rest, last] = arr;
EOF

cat > 08_middle_rest_object.js << 'EOF'
const {...rest, age} = obj;
EOF

cat > 09_multiple_rest.js << 'EOF'
const [...a, ...b] = arr;
EOF

cat > 10_empty_rest_array.js << 'EOF'
const [...] = arr;
EOF

cat > 11_empty_rest_object.js << 'EOF'
const {...} = obj;
EOF

cat > 12_rest_with_default.js << 'EOF'
const [...rest = []] = arr;
EOF

cat > 13_missing_property_name.js << 'EOF'
const {:value} = obj;
EOF

cat > 14_missing_alias.js << 'EOF'
const {name:} = obj;
EOF

cat > 15_double_colon.js << 'EOF'
const {name::alias} = obj;
EOF

cat > 16_triple_colon.js << 'EOF'
const {name:alias:extra} = obj;
EOF

cat > 17_computed_property_error.js << 'EOF'
const {["key"]} = obj;
EOF

cat > 18_computed_missing_bracket.js << 'EOF'
const {[key} = obj;
EOF

cat > 19_string_as_alias.js << 'EOF'
const {name: "firstName"} = obj;
EOF

cat > 20_number_as_property.js << 'EOF'
const {5: value} = obj;
EOF

cat > 21_boolean_as_property.js << 'EOF'
const {true: value} = obj;
EOF

cat > 22_null_as_property.js << 'EOF'
const {null: value} = obj;
EOF

cat > 23_missing_default_value.js << 'EOF'
const {name = } = obj;
EOF

cat > 24_missing_array_default.js << 'EOF'
const [item = ] = arr;
EOF

cat > 25_double_equals.js << 'EOF'
const {name == "default"} = obj;
EOF

cat > 26_default_before_alias.js << 'EOF'
const {name = alias: "default"} = obj;
EOF

cat > 27_missing_alias_with_default.js << 'EOF'
const {name: = "default"} = obj;
EOF

cat > 28_nested_missing_pattern.js << 'EOF'
const {user: } = obj;
EOF

cat > 29_nested_empty_colon.js << 'EOF'
const {user: {:name}} = obj;
EOF

cat > 30_nested_missing_alias.js << 'EOF'
const {user: {name:}} = obj;
EOF

cat > 31_array_in_object_error.js << 'EOF'
const {items: [} = obj;
EOF

cat > 32_nested_rest_error.js << 'EOF'
const {users: [...rest, last]} = obj;
EOF

cat > 33_nested_default_error.js << 'EOF'
const {users: [{} = obj]} = obj;
EOF

cat > 34_assignment_no_parentheses.js << 'EOF'
let x, y;
{x, y} = obj;
EOF

cat > 35_invalid_assignment_target.js << 'EOF'
[5, 6] = arr;
EOF

cat > 36_number_assignment_target.js << 'EOF'
({5: value} = obj);
EOF

cat > 37_mixed_declaration_error.js << 'EOF'
const [x], y = arr;
EOF

cat > 38_multiple_const_destructuring.js << 'EOF'
const {a} = obj, {b} = obj2;
EOF

cat > 39_function_param_missing_default.js << 'EOF'
function foo({x, y =}) {}
EOF

cat > 40_function_param_rest_error.js << 'EOF'
function foo({...}) {}
EOF

cat > 41_arrow_no_parentheses_object.js << 'EOF'
const func = {x, y} => x + y;
EOF

cat > 42_arrow_no_parentheses_array.js << 'EOF'
const func = [a, b] => a + b;
EOF

cat > 43_arrow_param_rest_error.js << 'EOF'
const func = ({...} = {}) => {};
EOF

cat > 44_middle_comma_rest_param.js << 'EOF'
function foo([a, ... , b]) {}
EOF

cat > 45_for_of_destructuring_error.js << 'EOF'
for ({x, y} of points) {}
EOF

cat > 46_for_of_multi_declaration.js << 'EOF'
for (let x, y of points) {}
EOF

cat > 47_catch_multiple_params.js << 'EOF'
try {} catch (error, {stack}) {}
EOF

cat > 48_destructuring_with_operator.js << 'EOF'
const {name} + {age} = obj;
EOF

cat > 49_typeof_destructuring.js << 'EOF'
typeof {x, y} = obj;
EOF

cat > 50_getter_in_pattern.js << 'EOF'
const {get value} = obj;
EOF

echo "Generated 50 destructuring JavaScript error files in destructuring_tests/"
