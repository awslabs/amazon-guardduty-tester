module.exports = {
    parser: '@typescript-eslint/parser', // Specifies the ESLint parser
    plugins: ['simple-import-sort', 'import'], // Add 'simple-import-sort' and 'import' in plugins section to enable simpe-import-sort configs in rules section
    extends: [
        'plugin:@typescript-eslint/recommended', // Uses the recommended rules from the @typescript-eslint/eslint-plugin
        // https://github.com/prettier/eslint-plugin-prettier#recommended-configuration
        // Unfolds to extending 'prettier' directly, and now one prettier rules them all, so no other plugins are required.
        // https://github.com/prettier/eslint-config-prettier/blob/main/CHANGELOG.md#version-800-2021-02-21
        // Enables eslint-plugin-prettier and eslint-config-prettier. This will display prettier errors as ESLint errors. Make sure this is always the last configuration in the extends array
        'plugin:prettier/recommended', 
    ],
    ignorePatterns: ['build/*', 'dist/*', 'node_modules/*'],
    rules: {
        /* Error Section */

        'object-shorthand': ['error'], // Enforce consistency of {key: value} when they have the same name to simplify to just {value}
        'no-var': 'error', // Do not use var -- use let or const instead
        'simple-import-sort/imports': 'error', // Enable import order autofix
        'simple-import-sort/exports': 'error', // Enable export order autofix
        'import/first': 'error', // Require imports at top of the file
        'import/exports-last': 'error', // Require exports at end of each file
        'import/no-duplicates': 'error', // Prevent duplicate imports
        'import/newline-after-import': 'error', // Require newline after imports
        'no-restricted-syntax': [
            'error',
            {
                'selector': 'CallExpression[callee.name="require"]',
                'message': 'require() is not allowed'
            }
        ],

        /* Warning Section */

        'no-console': 'warn', // Warn for console statements
        '@typescript-eslint/no-use-before-define': 'warn', // Declarations before usage within file
        '@typescript-eslint/no-shadow': 'warn', // Warn about outer-scope declaration (same variable name in inner-scope)
        'prefer-destructuring': ['warn', {'object': true, 'array': true}],

        /* Allowed Syntax Section */

        '@typescript-eslint/no-non-null-assertion': 'off', // Allow use of non-null assertion
        'no-plusplus': 'off', // Allow unary ++
        'max-classes-per-file': 'off', // Allow more than one class per file
        'class-methods-use-this': 'off', // Allow nonstatic methods that do not use `this`
        'no-new': 'off', // Allow using 'new' keyword without assigning to a variable
        'import/prefer-default-export': 'off', // Allow non default exports
        'no-template-curly-in-string': 'off', // Allow strings to have curly braces

        // Allow imports from devDependencies
        'import/no-extraneous-dependencies': [
            'error',
            {
                'devDependencies': true,
            },
        ],
    },
};


