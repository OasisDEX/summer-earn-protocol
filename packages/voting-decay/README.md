# @summerfi/voting-decay

A Solidity library for tracking and managing the decay of voting power in governance systems.

## Overview

`@summerfi/voting-decay` provides two internal libraries used by governance and staking contracts.
`VotingDecayLibrary` manages per-account decay state (`DecayState`, `DecayInfo`) and exposes
functions for initialising accounts, updating/resetting decay factors, querying current and
historical decay factors, and applying decay to a raw voting-power value. `VotingDecayMath` supplies
the underlying fixed-point arithmetic: `linearDecay`, `exponentialDecay`, and `mulDiv`, all using
`@prb/math` UD60x18. The library supports configurable decay-free windows, per-second decay rates,
and both `Linear` and `Exponential` decay functions. Delegation chains up to
`MAX_DELEGATION_DEPTH = 2` are followed when resolving an account's effective decay factor.

## Key contracts / exports

| File                         | What it provides                                                                                                      |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `src/VotingDecayLibrary.sol` | `VotingDecayLibrary` — state types (`DecayState`, `DecayInfo`), errors, events, all state-mutating and view functions |
| `src/VotingDecayMath.sol`    | `VotingDecayMath` — pure math helpers (`linearDecay`, `exponentialDecay`, `mulDiv`)                                   |

Import path used by consumers: `@summerfi/voting-decay/VotingDecayLibrary.sol` (remapped via
`node_modules/`).

## Build and test

```bash
# Build
pnpm build          # forge build --quiet

# Test
pnpm test           # forge test

# Coverage
pnpm coverage       # forge coverage (debug report)
pnpm coverage:lcov  # lcov report

# Generate docs
pnpm docs:gen       # forge doc  →  docs/generated/

# Lint / format
pnpm format         # prettier check
pnpm format:fix     # prettier write
```

## Cross-package connections

**Consumes**

- `@prb/math` — UD60x18 fixed-point arithmetic used in `VotingDecayMath`
- `@openzeppelin/contracts` — `Checkpoints.Trace224` for historical decay-factor snapshots (resolved
  via `@summerfi/dependencies`)
- `@summerfi/dependencies` — provides OZ and forge-std remappings
- `@summerfi/constants` — remapped for any shared constants

**Consumed by** (verified via `package.json` and `.sol` imports)

- `packages/gov-contracts` — `SummerToken.sol` embeds `VotingDecayLibrary.DecayState` and calls all
  major state functions; `DecayController.sol` orchestrates decay updates by calling
  `ISummerToken.updateDecayFactor` (it does not directly embed `DecayState`)
- `packages/rewards-contracts` — imports `VotingDecayLibrary` in staking tests
- `packages/core-contracts` — declares the dependency; used in `FleetCommanderTestBase` tests
- `packages/deployment` — compiles `SummerToken` which transitively includes this library

**Gotchas**

- The `DecayFunction` enum has exactly two variants (`Linear`, `Exponential`); adding a third
  requires updating every `if/else` branch in both `VotingDecayLibrary` and `VotingDecayMath` or the
  `revert InvalidDecayType()` path will be hit.
- `MAX_DELEGATION_DEPTH = 2` is a public constant. Any integration that chains more than two
  delegate hops silently receives a decay factor of 0 — this is intentional but easy to miss.
- The package is `private: true` and is not published to npm; it is consumed only as a workspace
  dependency via Foundry remappings.

## Documentation

GitBook section: [Voting Decay Library](../../gitbook/governance/voting-decay/README.md) (SUMMARY.md
entry: `governance/voting-decay/README.md`).
