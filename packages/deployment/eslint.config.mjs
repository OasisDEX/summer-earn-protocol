import base from '@summerfi/eslint-config/library'

export default [
  {
    ignores: ['artifacts/**', 'scripts/**'],
  },
  ...base,
  {
    rules: {
      '@typescript-eslint/no-unused-expressions': 'off',
    },
  },
]
