/* eslint-disable @typescript-eslint/no-require-imports */
const { compilerOptions } = require('./tsconfig.test')

const sharedConfig = require('@summerfi/jest-config/jest.base')

module.exports = {
  ...sharedConfig(compilerOptions),
  roots: ['<rootDir>/src'],
}
