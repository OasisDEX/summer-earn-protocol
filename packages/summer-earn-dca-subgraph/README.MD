# summer-earn-dca-subgraph

Subgraph that indexes the `DCAStrategyManager` contract — recurring vault-to-vault swap strategies.

## What it tracks

- **User** — owner address with derived list of strategies.
- **Strategy** — full `StrategyConfig` snapshot + state machine (`ACTIVE` / `PAUSED` / `CANCELLED` / `COMPLETED`) + aggregated trade totals.
- **Execution** — immutable record of every `ExecutionCompleted` event with `amountIn` / `amountOut`.

Status is **stateful**: handlers maintain it directly. `COMPLETED` is deduced inside `handleExecutionCompleted` whenever `tradesExecuted >= maxTrades` or `block.timestamp >= endDate`, since the contract never emits a dedicated event for that transition.

## Handlers

| Event | Handler | Effect |
|---|---|---|
| `StrategyCreated(strategyId, config)` | `handleStrategyCreated` | New `Strategy` (status `ACTIVE`, aggregates 0), new `User` if needed. `nextTriggerAt` mirrors the contract's hourly alignment. |
| `StrategyEdited(strategyId, config)` | `handleStrategyEdited` | Update configurable fields. Aggregates and `tradesExecuted` are **not** touched. |
| `StrategyPaused(strategyId, nextTriggerAt)` | `handleStrategyPaused` | Status → `PAUSED`, mirror `nextTriggerAt`. |
| `StrategyResumed(strategyId, nextTriggerAt)` | `handleStrategyResumed` | Status → `ACTIVE`, mirror `nextTriggerAt`. |
| `StrategyCancelled(strategyId)` | `handleStrategyCancelled` | Status → `CANCELLED`. |
| `ExecutionCompleted(strategyId, tradesExecuted, inAmount, outAmount, nextTriggerAt)` | `handleExecutionCompleted` | Append `Execution`, update `tradesExecuted`/`nextTriggerAt`/`lastScheduledAt`, increment aggregates, auto-complete check. |

## Local build

```sh
pnpm install
pnpm prepare:base          # render subgraph.yaml for Base
pnpm exec graph codegen
pnpm exec graph build
```

## Deploy

Set `GOLDSKY_API_KEY` in `../../.env`, then:

```sh
pnpm deploy:base
pnpm deploy:mainnet
```

## Open items

- `config/{base,mainnet}.json` carry placeholder `dca-strategy-manager-address` / `dca-strategy-manager-start-block` — fill in when the contract is deployed on each chain.
