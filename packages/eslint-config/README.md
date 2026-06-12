# `@summerfi/eslint-config`

Shared ESLint flat-config presets for the monorepo. Three named exports:

| Export                             | File           | Intended for                                                                     |
| ---------------------------------- | -------------- | -------------------------------------------------------------------------------- |
| `@summerfi/eslint-config/next`     | `next.mjs`     | Next.js apps (adds React + react-hooks plugins)                                  |
| `@summerfi/eslint-config/library`  | `library.mjs`  | TypeScript libraries (adds import-x cycle detection, stricter `no-explicit-any`) |
| `@summerfi/eslint-config/function` | `function.mjs` | Serverless / Node functions (minimal rules, Jest globals included)               |

All three configs require ESLint 9+ (flat config) and TypeScript 5.4+.

## Usage

In a consumer package's `eslint.config.mjs`:

```js
import nextConfig from '@summerfi/eslint-config/next'
export default [...nextConfig]
```

## Cross-package connections

Used by `packages/` and `apps/` across the repo, including `core-contracts`, `gov-contracts`,
`math-utils`, `percentage`, `price-utils`, `deployment`, `tenderly-utils`, `dutch-auction`,
`intent-system`, `summer-earn-rwa-app`, `summer-earn-dca-app`, and `summer-earn-auctions-frontend`.

**Gotcha:** the `library` config enforces `import-x/no-cycle` at the `error` level; circular imports
that compile fine will fail linting.
