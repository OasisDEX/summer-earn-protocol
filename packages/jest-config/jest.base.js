const { pathsToModuleNameMapper } = require('ts-jest')

/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = (pkgCompilerOptions = {}) => {
  const mappings = pathsToModuleNameMapper({ ...pkgCompilerOptions.paths } || {}, {
    prefix: '<rootDir>/',
  })
  return {
    roots: ['<rootDir>/src', '<rootDir>/tests'],
    preset: 'ts-jest',
    extensionsToTreatAsEsm: ['.ts'],
    silent: false,
    maxWorkers: 1,
    testTimeout: 10000,
    testEnvironment: 'node',
    moduleNameMapper: mappings,
    coverageReporters: ['json-summary', 'text', 'lcov'],
    transformIgnorePatterns: ['<rootDir>/node_modules', 'node_modules'],
    transform: {
      '^.+\\.(ts|tsx)$': [
        'ts-jest',
        {
          tsconfig: '<rootDir>/tsconfig.test.json',
          compilerOptions: {},
        },
      ],
    },
  }
}
