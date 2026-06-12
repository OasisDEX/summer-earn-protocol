# @summerfi/constants

Shared Solidity constants library for the Summer.fi protocol.

## Contents

`src/Constants.sol` — a single `Constants` library exposing:

- `WAD` (1e18), `RAY` (1e27), `WAD_TO_RAY` (1e9) — fixed-point precision units
- `SECONDS_PER_DAY`, `SECONDS_PER_YEAR` — time constants
- `MAX_UINT256` — type max
- `ACTIVE_MASK`, `FROZEN_MASK`, `PAUSED_MASK` — Aave V3 pool config data masks

## Who uses it

`core-contracts`, `gov-contracts`, `rewards-contracts`, `voting-decay`, `intent-system`, and
`deployment` all consume this package via a Foundry remapping:

```
@summerfi/constants/=node_modules/@summerfi/constants/src/
```

## Gotcha

`package.json` declares `main`/`types` pointing to a `dist/` directory and defines only
`format`/`format:fix` scripts targeting `*.ts` files — there is no build step and no TypeScript
source. The package is Solidity-only; the dist fields and TS-targeting scripts are unused artifacts.
