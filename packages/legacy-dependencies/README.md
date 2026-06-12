# @summerfi/legacy-dependencies

A dependency-pinning package that holds the exact `@layerzerolabs/*` and `solidity-bytes-utils`
versions that the deployed governance contracts were built with.

## What it contains

| Package                                    | Version |
| ------------------------------------------ | ------- |
| `@layerzerolabs/lz-definitions`            | 2.3.39  |
| `@layerzerolabs/lz-evm-messagelib-v2`      | 2.3.39  |
| `@layerzerolabs/lz-evm-protocol-v2`        | 2.3.39  |
| `@layerzerolabs/lz-evm-v1-0.7`             | 2.3.39  |
| `@layerzerolabs/lz-v2-utilities`           | 2.3.39  |
| `@layerzerolabs/oapp-evm`                  | 0.0.4   |
| `@layerzerolabs/oft-evm`                   | 0.0.11  |
| `@layerzerolabs/test-devtools-evm-foundry` | 0.2.11  |
| `@layerzerolabs/toolbox-foundry`           | 0.1.9   |
| `solidity-bytes-utils`                     | 0.8.4   |

## Who uses it

`gov-contracts` and `deployment` depend on this package. `gov-contracts` remaps `@layerzerolabs/` to
`node_modules/@summerfi/legacy-dependencies/node_modules/@layerzerolabs/` via `remappings.txt`, so
Foundry resolves LayerZero imports from here rather than from the workspace root.

## Gotcha

`core-contracts` resolves `@layerzerolabs/` from the root `node_modules` and therefore sees
different LayerZero versions. Do not update `gov-contracts` to use the root versions — the two
packages are intentionally pinned separately.
