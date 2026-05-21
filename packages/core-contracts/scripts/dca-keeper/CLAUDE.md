# DCA keeper

## Protocol

This file is meta-Claude memory. **Update it in the same commit as any
logic or design change here**, and add a line to the Sign-off block at the
bottom. The canonical protocol + DRY rules live in the
[contract CLAUDE.md](../../src/contracts/DCA/CLAUDE.md); read it first.

Siblings: [contract](../../src/contracts/DCA/CLAUDE.md) ·
[subgraph](../../../summer-earn-dca-subgraph/CLAUDE.md) ·
[app](../../../summer-earn-dca-app/CLAUDE.md).

---

Single-process Python bot that polls the DCA subgraph for due strategies and
broadcasts `executeStrategy(strategyId, config, ensoData)` against the
on-chain manager. MVP scope: one signer, one chain (Base), one process.

## Files

- `dca_keeper.py` — entire bot. Self-contained ABI (just `checkUpkeep` +
  `executeStrategy`) so no dependency on the compiled artifact.
- `requirements.txt` — `web3.py`, `aiohttp`, `eth-account`, `python-dotenv`.
- `.env.example` — config surface (RPC, manager address, subgraph URL, Enso
  endpoint, signer key, gas caps).

## Flow per tick

1. **GraphQL** `_SUBGRAPH_QUERY` — `Strategy { status: ACTIVE, nextTriggerAt_lte: now, endDate_gt: now }`.
2. **`checkUpkeep(strategyId, config)`** on-chain re-validation — authoritative
   go/no-go (oracle bounds, exact `nextTriggerAt`, `tradesExecuted < maxTrades`).
3. **POST Enso** `/shortcuts/route` with `tokenIn = sourceVault`,
   `tokenOut = targetVault` (vault SHARES, not underlying — the contract
   approves Enso for source-vault shares and measures target-vault share gain).
4. **`executeStrategy(strategyId, config, ensoData)`** with serialised nonce +
   EIP-1559 gas, capped by `MAX_FEE_CAP_GWEI`.

## Invariants to preserve

- **`StrategyConfig.as_tuple()` field order must match
  `IDCAStrategyManager.StrategyConfig` exactly** — see
  [contract CLAUDE.md](../../src/contracts/DCA/CLAUDE.md). `strategyId` is
  NOT in the tuple; it's a separate top-level arg.
- **Single-flight per strategy** via `self._inflight` — never broadcast two
  txs for the same strategyId concurrently.
- **Nonce reservation** is the critical section (`self._nonce_lock`). On
  `build_transaction` revert (gas estimation failed) we rewind `_next_nonce`
  to avoid permanent gaps; on `send_raw_transaction` failure we set it to
  `None` to force a fresh `eth_getTransactionCount` next tick.
- **Subgraph is advisory, not authoritative.** Always re-run `checkUpkeep`
  before signing — the indexer can lag a block or two and oracle bounds can
  move.

## When the contract changes

Any `StrategyConfig` field reorder/add/remove or any signature change to
`checkUpkeep` / `executeStrategy` requires editing both:
- the inline `DCA_MANAGER_ABI` literal
- the `StrategyConfig` dataclass + `as_tuple()` body
- the `_SUBGRAPH_QUERY` field list if a new field needs indexing

See [subgraph CLAUDE.md](../../../summer-earn-dca-subgraph/CLAUDE.md) for the
indexed entity shape.

## Operations

```
cp .env.example .env  # fill in
pip install -r requirements.txt
python dca_keeper.py
```

Logs go to stdout at `LOG_LEVEL=INFO` by default. Each strategy logs its
`strategyId` so failures are greppable.

## Sign-off

<!-- One line per material change. Most recent on top.
Format: YYYY-MM-DD — author — one-sentence summary. -->

- 2026-05-21 — claude — keeper code unchanged but **semantic of
  `maxPrice` / `minPrice` flipped** to a 1e18-scaled out/in execution-price
  ratio (see [contract CLAUDE.md](../../src/contracts/DCA/CLAUDE.md)).
  Keeper is still unit-blind — `checkUpkeep` enforces it on-chain.
- 2026-05-21 — claude — renamed `executeDCA` → `executeStrategy`; inline ABI
  + dataclass + `as_tuple()` updated; `strategyId` is now a separate top-level
  arg to `checkUpkeep` and `executeStrategy`.
- 2026-05-21 — claude — `StrategyConfig.as_tuple()` dropped `strategyId`
  (field removed from the on-chain struct); keeper still tracks it as a
  dataclass cursor.
- 2026-05-21 — claude — initial CLAUDE.md.
