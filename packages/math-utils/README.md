# MathUtils Library

`@summerfi/math-utils` is a Solidity library package providing fixed-point exponentiation for use in
other Summer.fi Solidity packages. The single contract `contracts/MathUtils.sol` exposes `rpow`, a
square-and-multiply algorithm (derived from MakerDAO's Pot.sol) used for compound-interest
calculations.

## Key contract

**`contracts/MathUtils.sol`** — `library MathUtils`

- `rpow(Percentage wrappedX, uint256 n, Percentage wrappedBase) internal pure returns (Percentage)`
  — typed overload that accepts and returns `Percentage`-wrapped values.
- `rpow(uint256 x, uint256 n, uint256 base) internal pure returns (uint256)` — raw overload for
  unwrapped values; contains the inline-assembly square-and-multiply loop and reverts on overflow.
  The `Percentage` overload delegates to this one (no direct assembly in the wrapper).

Depends on `@summerfi/percentage-solidity` for the `Percentage` type (see `remappings.txt`).
`forge-std` is resolved through `@summerfi/dependencies`.

## Build and test

```bash
# from the package root
pnpm build          # forge build --quiet
pnpm test           # forge test
pnpm test:coverage  # forge coverage
pnpm docs:gen       # forge doc  (output: docs/generated/)
pnpm format:fix     # prettier --write "**/*.sol"
```

## Cross-package connections

**Consumes:**

- `@summerfi/percentage-solidity` — provides the `Percentage` value type imported in
  `contracts/MathUtils.sol`.
- `@summerfi/dependencies` — supplies `forge-std` at the path used in `remappings.txt`.

**Consumed by** (verified via `remappings.txt` in each package):

- `packages/core-contracts`
- `packages/gov-contracts`
- `packages/deployment`
- `packages/intent-system`

All four packages declare the remapping
`@summerfi/math-utils/contracts/=node_modules/@summerfi/math-utils/contracts/`. Import path to use:

```solidity
import { MathUtils } from '@summerfi/math-utils/contracts/MathUtils.sol';
```

**Gotchas:**

- The `remappings.txt` files in consuming packages must be updated manually whenever this package
  moves or renames `contracts/MathUtils.sol`; there is no automated sync.
- License is `BUSL-1.1`, not MIT.

## Documentation

GitBook reference: [Math Library / MathUtils](../../gitbook/contracts/libraries/math/math-utils.md)
(relative path within the monorepo; published path mirrors `gitbook/SUMMARY.md`).
