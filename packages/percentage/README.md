# @summerfi/percentage-solidity

Solidity math library providing two complementary fixed-point ratio types: `Percentage` (18-decimal
precision, `uint256` scaled by `1e18`) and `BPS` (basis-point precision, `uint256` scaled by
`10000`). Both types expose overloaded arithmetic and comparison operators plus utility libraries
(`PercentageUtils`, `BpsUtils`) for add/subtract/apply operations on plain `uint256` amounts.

## Key contracts

All four files live under `contracts/` (Foundry `src = "contracts"`).

| File                  | Exports                                                                                                                                              |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Percentage.sol`      | `Percentage` type, `PERCENTAGE_DECIMALS`, `PERCENTAGE_FACTOR`, `PERCENTAGE_100`, `PERCENTAGE_1`, `toPercentage`, `fromPercentage`                    |
| `PercentageUtils.sol` | `PercentageUtils` library — `addPercentage`, `subtractPercentage`, `applyPercentage`, `isPercentageInRange`, `fromFraction`, `fromIntegerPercentage` |
| `BPS.sol`             | `BPS` type, `BPS_FACTOR`, `BPS_100`, `BPS_1`, `toBps`, `fromBps`                                                                                     |
| `BpsUtils.sol`        | `BpsUtils` library — `addBps`, `subtractBps`, `applyBps`, `isBpsInRange`, `fromFraction`                                                             |

## Build and test

```sh
# from the package root
pnpm build            # forge build --quiet
pnpm test             # forge test
pnpm test:coverage    # forge coverage
pnpm docs:gen         # forge doc  (output: docs/generated/)
```

## Cross-package connections

**Consumes:** `forge-std` (direct `devDependency`; `@summerfi/dependencies` is also a
`devDependency`; no runtime Solidity dependencies).

**Consumed by:** `math-utils`, `dutch-auction`, `intent-system`, `gov-contracts`, `core-contracts`,
`deployment` — all six list `@summerfi/percentage-solidity` as a dependency in their `package.json`.

**Import path gotcha:** every consumer must include the `contracts/` segment because the Foundry
remapping resolves `@summerfi/percentage-solidity/contracts/` specifically. Correct form:

```solidity
import { Percentage } from '@summerfi/percentage-solidity/contracts/Percentage.sol';
import { PercentageUtils } from '@summerfi/percentage-solidity/contracts/PercentageUtils.sol';
```

Omitting `contracts/` will cause a path resolution failure at compile time.

## Documentation

GitBook: [Percentage Library](../../gitbook/contracts/libraries/percentage/README.md) — includes
separate pages for `BPS`, `BpsUtils`, `Percentage`, and `PercentageUtils`.
