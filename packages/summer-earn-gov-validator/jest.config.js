/* eslint-disable @typescript-eslint/no-require-imports */
const { compilerOptions } = require('./tsconfig.test')

const sharedConfig = require('@summerfi/jest-config/jest.base')

module.exports = {
  ...sharedConfig(compilerOptions),
  roots: ['<rootDir>/tests'],
  collectCoverageFrom: [
    'src/utils/proposal-encoding.ts',
    'src/utils/layerzero-options.ts',
    'src/utils/text.ts',
    'src/utils/timing.ts',
    'src/utils/proposal-transformer.ts',
    'src/services/validation.ts',
  ],
  coverageThreshold: {
    global: {
      lines: 90,
      branches: 90,
      functions: 90,
      statements: 90,
    },
    './src/utils/text.ts': {
      lines: 90,
      branches: 90,
      functions: 90,
      statements: 90,
    },
    './src/utils/timing.ts': {
      lines: 90,
      branches: 90,
      functions: 90,
      statements: 90,
    },
    './src/utils/proposal-transformer.ts': {
      lines: 90,
      branches: 90,
      functions: 90,
      statements: 90,
    },
    './src/services/validation.ts': {
      lines: 90,
      branches: 90,
      functions: 90,
      statements: 90,
    },
  },
}
