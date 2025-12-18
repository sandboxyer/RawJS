#!/bin/bash

mkdir -p imports_tests
cd imports_tests

cat > 01_import_missing_specifier.js << 'EOF'
import;
EOF

cat > 02_import_missing_from.js << 'EOF'
import { name };
EOF

cat > 03_import_missing_source.js << 'EOF'
import { name } from ;
EOF

cat > 04_import_empty_braces.js << 'EOF'
import { } from "./module.js";
EOF

cat > 05_import_comma_no_identifier.js << 'EOF'
import { , } from "./module.js";
EOF

cat > 06_import_trailing_comma.js << 'EOF'
import { name, , } from "./module.js";
EOF

cat > 07_import_number_identifier.js << 'EOF'
import { 123 } from "./module.js";
EOF

cat > 08_import_string_identifier.js << 'EOF'
import { "name" } from "./module.js";
EOF

cat > 09_import_default_keyword.js << 'EOF'
import { default } from "./module.js";
EOF

cat > 10_import_duplicate_identifiers.js << 'EOF'
import { name, name } from "./module.js";
EOF

cat > 11_import_missing_comma.js << 'EOF'
import { name age } from "./module.js";
EOF

cat > 12_import_namespace_missing_as.js << 'EOF'
import * from "./module.js";
EOF

cat > 13_import_namespace_missing_identifier.js << 'EOF'
import * as from "./module.js";
EOF

cat > 14_import_default_missing_identifier.js << 'EOF'
import default from "./module.js";
EOF

cat > 15_import_default_as_error.js << 'EOF'
import default as myName from "./module.js";
EOF

cat > 16_export_missing_declaration.js << 'EOF'
export;
EOF

cat > 17_export_comma_no_identifier.js << 'EOF'
export ,;
EOF

cat > 18_export_empty_braces.js << 'EOF'
export { , };
EOF

cat > 19_export_number_identifier.js << 'EOF'
export { 123 };
EOF

cat > 20_export_string_identifier.js << 'EOF'
export { "name" };
EOF

cat > 21_export_missing_closing_brace.js << 'EOF'
export { name ;
EOF

cat > 22_export_missing_comma.js << 'EOF'
export { name age };
EOF

cat > 23_export_default_missing_expression.js << 'EOF'
export default ;
EOF

cat > 24_export_default_incomplete_expression.js << 'EOF'
export default 5 + ;
EOF

cat > 25_export_default_with_let.js << 'EOF'
export default let x = 5;
EOF

cat > 26_export_default_with_const.js << 'EOF'
export default const x = 5;
EOF

cat > 27_export_default_function_incomplete.js << 'EOF'
export default function() {;
EOF

cat > 28_export_star_missing_from.js << 'EOF'
export * ;
EOF

cat > 29_export_star_missing_source.js << 'EOF'
export * from ;
EOF

cat > 30_export_named_missing_from.js << 'EOF'
export { name } ;
EOF

cat > 31_export_as_missing_identifier.js << 'EOF'
export { name as } from "./module.js";
EOF

cat > 32_export_as_number_identifier.js << 'EOF'
export { name as 123 } from "./module.js";
EOF

cat > 33_export_missing_semicolon.js << 'EOF'
export { name } from "./module.js"
let x = 5;
EOF

cat > 34_import_export_combination.js << 'EOF'
import export { name } from "./module.js";
EOF

cat > 35_export_import_combination.js << 'EOF'
export import name from "./module.js";
EOF

cat > 36_import_inside_function.js << 'EOF'
function test() {
    import { name } from "./module.js";
}
EOF

cat > 37_export_inside_function.js << 'EOF'
function test() {
    export { name };
}
EOF

cat > 38_import_inside_if.js << 'EOF'
if (true) {
    import "./module.js";
}
EOF

cat > 39_export_after_code.js << 'EOF'
console.log("test");
export { name };
EOF

cat > 40_import_after_code.js << 'EOF'
console.log("test");
import { name } from "./module.js";
EOF

cat > 41_dynamic_import_missing_paren.js << 'EOF'
import ;
EOF

cat > 42_dynamic_import_missing_quotes.js << 'EOF'
import ("./module.js";
EOF

cat > 43_invalid_module_specifier.js << 'EOF'
import {} from ;
EOF

cat > 44_empty_module_specifier.js << 'EOF'
import {} from "";
EOF

cat > 45_dot_module_specifier.js << 'EOF'
import {} from .;
EOF

cat > 46_double_export_default.js << 'EOF'
export default function() {};
export default class {};
EOF

cat > 47_export_before_declaration.js << 'EOF'
export { name };
let name = "John";
EOF

cat > 48_import_type_error.js << 'EOF'
import type from "./types.js";
EOF

cat > 49_mixed_import_export.js << 'EOF'
import { name } export { age } from "./module.js";
EOF

cat > 50_invalid_path_backslash.js << 'EOF'
import {} from "C:\module.js";
EOF

echo "Generated 50 JavaScript files with Import/Export syntax errors in imports_tests/"
