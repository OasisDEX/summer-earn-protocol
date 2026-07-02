# @summerfi/constants

Shared Solidity constants library for the Summer.fi protocol.

## Contents

`src/Constants.sol` — a single `Constants` library exposing:

- `WAD` (1e18), `RAY` (1e27), `WAD_TO_RAY` (1e9) — fixed-point precision units
- `SECONDS_PER_DAY`, `SECONDS_PER_YEAR` — time constants
- `MAX_UINT256` — type max
- `ACTIVE_MASK`, `FROZEN_MASK`, `PAUSED_MASK` — Aave V3 pool config data masks

## Cross-package connections

**Consumed by** (via the Foundry remapping
`@summerfi/constants/=node_modules/@summerfi/constants/src/`):

- `packages/core-contracts`
- `packages/gov-contracts`
- `packages/rewards-contracts`
- `packages/voting-decay`
- `packages/intent-system`
- `packages/deployment`

**Gotchas:**

- `package.json` declares `main`/`types` pointing to a `dist/` directory and defines only
  `format`/`format:fix` scripts targeting `*.ts` files — there is no build step and no TypeScript
  source. The package is Solidity-only; the dist fields and TS-targeting scripts are unused
  artifacts.
