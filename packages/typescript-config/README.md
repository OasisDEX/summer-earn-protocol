# @summerfi/typescript-config

Shared TypeScript compiler configurations for the Summer Earn Protocol monorepo.

## Configs

| File                   | Purpose                                                                                                                                                    |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tsconfig.base.json`   | Base config for Node packages. Targets ES2022, `moduleResolution: Bundler`, strict mode, composite/incremental builds enabled. Extends `@tsconfig/node20`. |
| `tsconfig.nextjs.json` | Extends base; adds `jsx: preserve`, `allowJs`, and the Next.js language-service plugin.                                                                    |
| `tsconfig.test.json`   | Extends base with `noEmit: true`; used by test runners (includes `ts-node` overrides).                                                                     |

## Usage

In a consuming package's `tsconfig.json`:

```json
{ "extends": "@summerfi/typescript-config/tsconfig.base.json" }
```

15 packages in the monorepo consume this package as a `devDependency`.

## Gotcha

`tsconfig.base.json` ships a hardcoded `references` list pointing at specific sibling packages.
Consumers that use `composite: true` project references must keep their own `tsconfig.json`
references in sync; they are not inherited from the base.
