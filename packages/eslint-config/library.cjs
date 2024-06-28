/** @type {import("eslint").Linter.Config} */
module.exports = {
  parser: '@typescript-eslint/parser',
  plugins: ['unused-imports', 'import'],
  extends: [
    'eslint:recommended',
    'prettier',
    'eslint-config-turbo',
    'plugin:@typescript-eslint/recommended',
    'plugin:import/recommended',
    'plugin:import/typescript',
  ],
  settings: {
    'import/resolver': {
      typescript: true,
      node: true,
    },
  },
  env: {
    node: true,
    jest: true,
  },
  rules: {
    'import/no-cycle': 'error',
    'import/no-absolute-path': 'error',
    'import/no-unresolved': 'off',
    'no-unused-vars': 'off',
    'unused-imports/no-unused-vars': [
      'off',
      { vars: 'all', varsIgnorePattern: '^_', args: 'after-used', argsIgnorePattern: '^_' },
    ],
    '@typescript-eslint/no-explicit-any': 'error',
    '@typescript-eslint/ban-ts-comment': 'off',
  },
  ignorePatterns: [
    // Ignore dotfiles
    'jest.config.js',
    '.*.js',
    'node_modules/',
    'dist/',
  ],
  overrides: [
    {
      files: ['*.(m)js?(x)', '*.(m)ts?(x)'],
    },
  ],
}
