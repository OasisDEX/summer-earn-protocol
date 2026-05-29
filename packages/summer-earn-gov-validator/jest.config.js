/* eslint-disable @typescript-eslint/no-require-imports */
const { compilerOptions } = require('./tsconfig.test')

const sharedConfig = require('@summerfi/jest-config/jest.base')

module.exports = {
  ...sharedConfig(compilerOptions),
  roots: ['<rootDir>/tests'],
  collectCoverageFrom: [
    'src/utils/proposal-encoding.ts',
    'src/utils/layerzero-options.ts',
  ],
  coverageThreshold: {
    global: {
      lines: 90,
      branches: 90,
      functions: 90,
      statements: 90,
    },
  },
}
