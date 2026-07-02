# @summerfi/jest-config

Shared Jest base configuration for TypeScript packages in this monorepo.

## What it exports

`jest.base.js` exports a factory function that accepts a package's `compilerOptions` (typically from
`tsconfig.test.json`) and returns a `ts-jest` config. It sets roots to `src/` and `tests/`, uses
`ts-jest` with ESM treatment for `.ts` files, runs with a single worker (`maxWorkers: 1`), and maps
TypeScript path aliases via `pathsToModuleNameMapper`.

## Usage

```js
// jest.config.js in a consuming package
const { compilerOptions } = require('./tsconfig.test')
const sharedConfig = require('@summerfi/jest-config/jest.base')

module.exports = {
  ...sharedConfig(compilerOptions),
}
```

## Cross-package connections

**Consumes:** `@summerfi/typescript-config` — a consuming package's `tsconfig.test.json` (which
feeds `compilerOptions` into the factory above) typically extends it.

**Consumed by:** any TypeScript package that runs Jest tests — `tenderly-utils`,
`summer-earn-gov-validator`, `math-utils`, `price-utils`, `percentage`, `dutch-auction`,
`deployment`, `intent-system`, `core-contracts`, `gov-contracts`, and
`summer-earn-auctions-frontend`.

**Gotchas:**

- The base config hard-codes `roots` to `['<rootDir>/src', '<rootDir>/tests']`. Packages that also
  have an `e2e/` directory (e.g. `tenderly-utils`) must spread the base config and override `roots`
  to add the extra directory.
