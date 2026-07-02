# @summerfi/dependencies

Vendored third-party Solidity libraries published as a single workspace package.

## What it contains

`lib/` holds pinned source trees for:

- `forge-std` — Foundry test/script utilities
- `openzeppelin-contracts` and `openzeppelin-contracts-upgradeable` — OZ v5 stable
- `openzeppelin-next` — OZ next preview
- `prb-math` — fixed-point math
- `pendle-core-v2-public` — Pendle protocol interfaces
- `morpho-blue-local` and `metamorpho-local` — local Morpho copies
- `solmate` — minimal ERC implementations

## Cross-package connections

**Consumed by:** every Solidity package in the repo. Forge remappings (in each package's
`remappings.txt`) resolve `forge-std/`, `@openzeppelin/contracts/`, `morpho-blue/`, `metamorpho/`,
`@prb/math/`, `@pendle/core-v2/`, `solmate/`, etc. to paths under
`node_modules/@summerfi/dependencies/lib/`.

**Gotchas:**

- This package is the single version-pin for all of the above libraries. Do not add a separate
  `@openzeppelin/contracts` (or other vendored lib) npm dependency to a contracts package —
  `packages/price-utils` already does this and is a pre-existing inconsistency to avoid repeating.
- There are no build or test scripts; it is a passive file container.
