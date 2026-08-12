import base from '@summerfi/eslint-config/next'
export default [
  {
    ignores: [
      '**/.sst/**',
      '**/.next/**',
      '**/.open-next/**',
      '**/out/**',
      '**/dist/**',
      '**/node_modules/**',
      '**/sst.config.ts',
      '**/sst-env.d.ts',
      '.sst/**',
      '.next/**',
      '.open-next/**',
      'out/**',
      'dist/**',
      'node_modules/**',
      'sst.config.ts',
      'sst-env.d.ts',
    ],
  },
  ...base,
]


