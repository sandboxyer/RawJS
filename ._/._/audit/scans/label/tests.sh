#!/bin/bash

# Generate test files for JavaScript Label Syntax Errors

mkdir -p label_tests
cd label_tests

# Clear any existing test files
rm -f *.js

echo "Generating 50 JavaScript files with label syntax errors..."

# Basic invalid label placements
cat > 01_label_on_function_stmt.js << 'EOF'
// Labels can't be on function statements
myLabel: function test() {}
EOF

cat > 02_label_on_return.js << 'EOF'
// Labels can't be on return statements
myLabel: return 5;
EOF

cat > 03_label_on_expression.js << 'EOF'
// Labels can't be on expressions
myLabel: x = 5;
EOF

cat > 04_label_on_debugger.js << 'EOF'
// Labels can't be on debugger statements
myLabel: debugger;
EOF

cat > 05_label_on_throw.js << 'EOF'
// Labels can't be on throw statements
myLabel: throw new Error();
EOF

# Invalid label names
cat > 06_reserved_word_label.js << 'EOF'
// Reserved words can't be labels
break: while(true) {}
EOF

cat > 07_numeric_label.js << 'EOF'
// Numbers can't be labels
123: for(let i = 0; i < 5; i++) {}
EOF

cat > 08_label_with_hyphen.js << 'EOF'
// Hyphens not allowed in labels
my-label: while(true) {}
EOF

cat > 09_label_with_dot.js << 'EOF'
// Dots not allowed in labels
label.1: { }
EOF

cat > 10_at_symbol_label.js << 'EOF'
// @ not allowed in labels
@label: for(;;) {}
EOF

# Duplicate labels
cat > 11_duplicate_label_same_scope.js << 'EOF'
// Duplicate label in same scope
myLabel: while(true) {
    myLabel: for(;;) {}
}
EOF

cat > 12_duplicate_label_block.js << 'EOF'
// Duplicate label in block
{
    outer: for(;;) {
        outer: { }
    }
}
EOF

# Invalid break/continue with labels
cat > 13_break_undefined_label.js << 'EOF'
// Break to undefined label
while(true) {
    break nonExistent;
}
EOF

cat > 14_continue_block_label.js << 'EOF'
// Continue with block label (not loop)
myBlock: {
    continue myBlock;
}
EOF

cat > 15_continue_undefined.js << 'EOF'
// Continue to undefined label
for(;;) {
    continue missingLabel;
}
EOF

cat > 16_break_from_if_to_label.js << 'EOF'
// Break from if to label
myLoop: while(true) {
    if (x) {
        break myLoop;
    }
}
// Actually valid, but keeping for pattern
EOF

cat > 17_label_after_use.js << 'EOF'
// Label defined after its use
for(;;) {
    break laterLabel;
}
laterLabel: while(true) {}
EOF

# Strict mode restrictions
cat > 18_strict_mode_function_label.js << 'EOF'
// Can't label functions in strict mode
"use strict";
funcLabel: function test() {}
EOF

cat > 19_strict_mode_reserved_label.js << 'EOF'
// Additional reserved words in strict mode
"use strict";
implements: { }
EOF

cat > 20_strict_mode_interface_label.js << 'EOF'
"use strict";
interface: while(true) {}
EOF

# Empty labeled statements
cat > 21_empty_labeled_stmt.js << 'EOF'
// Empty statement after label
myLabel: ;
EOF

cat > 22_label_only_semicolon.js << 'EOF'
// Label with just semicolon
loopLabel: ;
EOF

# Multiple labels error
cat > 23_multiple_labels_same_stmt.js << 'EOF'
// Multiple labels on same statement
label1: label2: while(true) {}
EOF

# Colon in wrong place
cat > 24_colon_after_for.js << 'EOF'
// Colon in wrong place
for(let i = 0; i < 5; i++): {
    console.log(i);
}
EOF

# Switch statement confusion
cat > 25_break_label_in_switch.js << 'EOF'
// Trying to break to label within switch
switch(x) {
    case 1:
        myLabel:
        break myLabel;
}
EOF

# Cross-scope label errors
cat > 26_cross_function_label.js << 'EOF'
// Label reference across functions
function outer() {
    outerLabel: while(true) {
        inner();
    }
    
    function inner() {
        break outerLabel;
    }
}
EOF

cat > 27_block_scope_label.js << 'EOF'
// Label reference across blocks
{
    blockLabel: for(;;) {}
}
if (true) {
    break blockLabel;
}
EOF

# Invalid continue contexts
cat > 28_continue_from_block.js << 'EOF'
// Continue from labeled block
myBlock: {
    for(;;) {
        continue myBlock;
    }
}
EOF

cat > 29_continue_from_switch.js << 'EOF'
// Continue from switch
myLoop: while(true) {
    switch(x) {
        case 1:
            continue myLoop;
    }
}
// Actually valid, keeping for pattern
EOF

# Label with reserved word break/continue
cat > 30_label_named_break.js << 'EOF'
// Label named 'break'
break: { }
EOF

cat > 31_label_named_continue.js << 'EOF'
// Label named 'continue'
continue: while(true) {}
EOF

# Complex nested errors
cat > 32_nested_duplicate_labels.js << 'EOF'
// Nested duplicate labels
a: {
    a: while(true) {
        break a;
    }
}
EOF

cat > 33_label_on_try.js << 'EOF'
// Label on try statement
myLabel: try {
    // code
} catch(e) {}
EOF

cat > 34_label_on_catch.js << 'EOF'
// Label on catch clause
try {
} catch(e): {
    // Invalid
}
EOF

# Expression statements with labels
cat > 35_label_on_assign.js << 'EOF'
// Label on assignment
myLabel: x = 5;
EOF

cat > 36_label_on_call.js << 'EOF'
// Label on function call
myLabel: console.log("test");
EOF

# Empty loop with label
cat > 37_empty_labeled_loop.js << 'EOF'
// Empty infinite loop with label
myLabel: for(;;);
EOF

# Label with only comment
cat > 38_label_comment_only.js << 'EOF'
// Label with just comment
myLabel: // comment
EOF

# Dynamic label attempt
cat > 39_dynamic_label.js << 'EOF'
// Attempt at dynamic label
const label = "myLabel";
label: while(true) {}
EOF

# Label in object literal (common confusion)
cat > 40_label_in_object.js << 'EOF'
// Colon in object literal mistaken for label
const obj = {
    myLabel: {
        break myLabel;
    }
};
EOF

# Invalid label on import
cat > 41_label_on_import.js << 'EOF'
// Label on import statement
myLabel: import "module";
EOF

# Invalid label on export
cat > 42_label_on_export.js << 'EOF'
// Label on export statement
myLabel: export const x = 5;
EOF

# Label on class statement
cat > 43_label_on_class.js << 'EOF'
// Label on class statement
myLabel: class Test {}
EOF

# Label with line break error
cat > 44_label_line_break.js << 'EOF'
// Label broken across lines
myLabel
: while(true) {}
EOF

# Multiple errors in one
cat > 45_multiple_label_errors.js << 'EOF'
// Multiple label errors
label1: label2: x = 5;
break nonExistent;
EOF

# Label on if statement
cat > 46_label_on_if.js << 'EOF'
// Label on if statement
myLabel: if (true) {}
EOF

# Label on with statement (deprecated)
cat > 47_label_on_with.js << 'EOF'
// Label on with statement
myLabel: with(obj) {}
EOF

# Break from try block
cat > 48_break_from_try.js << 'EOF'
// Break from try block to label
myLoop: while(true) {
    try {
        break myLoop;
    } catch(e) {}
}
// Actually valid, but keeping
EOF

# Label on do-while
cat > 49_label_on_do.js << 'EOF'
// Label on do-while statement
myLabel: do {
    // code
} while(false);
EOF

# Complex scope nesting
cat > 50_complex_scope_error.js << 'EOF'
// Complex scope error
function test() {
    outer: for(;;) {
        function inner() {
            break outer;
        }
    }
}
EOF

echo "Generated 50 test files in label_tests/"
echo ""
echo "Note: Some test files may actually be valid JavaScript."
echo "The label.sh auditor should detect the invalid cases."
