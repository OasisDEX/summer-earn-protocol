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
on-chain manager. The bot itself is single-chain (one `CHAIN_ID` / `RPC_URL` /
`DCA_STRATEGY_MANAGER` / `SUBGRAPH_URL` per process); **multichain is achieved
by running one instance per chain**, not by the bot looping chains. In AWS that
is one Lambda per chain (`infrastructure/modules/lambda_keeper` instantiated
`for_each` chain — Base + Ethereum mainnet today), each with its own schedule,
SSM secret prefix, and `reserved_concurrent_executions = 1`. The same image
serves every chain (it reads its chain from env). One keeper EOA works on all
EVM chains; nonces are independent per chain so there is no cross-chain
collision.

## Files

- `dca_keeper.py` — entire bot. Self-contained ABI (just `checkUpkeep` +
  `executeStrategy`) so no dependency on the compiled artifact.
- `requirements.txt` — `web3.py`, `aiohttp`, `eth-account`, `python-dotenv`,
  `boto3` (Lambda SSM fetch).
- `.env.example` — config surface (RPC, manager address, subgraph URL, Enso
  endpoint, signer key, gas caps).
- `lambda_function.py` — AWS Lambda handler for the **scheduled one-shot** run.
  Fetches SecureString secrets from SSM (prefix `KEEPER_SSM_PREFIX`) into the
  env, then runs `_main(run_once=True)`.
- `Dockerfile` — container image (`public.ecr.aws/lambda/python:3.12`) for the
  Lambda; infra lives in `infrastructure/modules/lambda_keeper` (cadence =
  `var.keeper_schedule_expression`, default every 10 min).

## Run modes

- **Continuous** (default; local/host): `python dca_keeper.py` → `run_forever()`
  loops every `POLL_INTERVAL_SECONDS`.
- **One-shot** (scheduled Lambda): `python dca_keeper.py --once`, or set
  `KEEPER_RUN_ONCE=1` → `run_once()` does a single `_tick()` and exits. The
  in-memory nonce is re-derived from the chain's `pending` count each run, so
  one-shot invocations are safe; `lambda_keeper` sets
  `reserved_concurrent_executions = 1` so passes never overlap.
  - **Known limit:** `_tick()` processes every due strategy with no per-run cap,
    so a large backlog × the per-tx confirmation wait can exceed the Lambda
    timeout and get hard-killed mid-pass (already-broadcast txs still settle; the
    next run re-checks). Mitigated by a short `TX_CONFIRMATION_TIMEOUT_SECONDS`
    and the contract's `nextTriggerAt` guard (a late duplicate reverts). Add a
    per-invocation strategy/time budget if backlogs grow.

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

- 2026-06-30 — claude — **multichain keeper: one Lambda per chain (Base + Ethereum mainnet).** `infrastructure/modules/lambda_keeper` is now instantiated `for_each` over a new `var.keeper_chains` map (chain slug → chain_id / dca_strategy_manager / subgraph_url / rpc_url / schedule / enabled); ECR + the secrets CMK became shared root singletons (`aws_ecr_repository.dca_keeper`, `aws_kms_key.dca_keeper_secrets`) passed into each module instance. Each chain = its own function `summer-earn-dca-keeper-<slug>`, schedule, SSM prefix `/dca-keeper/summer-earn-dca-keeper-<slug>`, IAM role, log group, and `reserved_concurrent_executions = 1`. The signer key + Enso key are shared root vars written into each chain's prefix (one EOA, per-chain nonces); only `RPC_URL` is per-chain. `lambda_function.py` is **unchanged** — each Lambda still reads all three secrets from its single `KEEPER_SSM_PREFIX`. Deploy workflow builds one image and loops `update-function-code` over both functions (bootstrap-guarded); OIDC scope widened to `function:summer-earn-dca-keeper-*`. DCA manager addresses are interim v4 → swapped to v5 post-deploy (bd aphelion-app-4z5). `terraform fmt -check` + `validate` clean.
- 2026-06-30 — claude — CodeRabbit review fixes on PR #878 (cross-checked with Codex). Applied: deploy workflow gained `concurrency { group: deploy-dca-keeper, cancel-in-progress: true }` (no older-run rollback-to-stale-image race); ECR `scan_on_push = true` (CKV_AWS_163); a dedicated customer-managed KMS CMK (`aws_kms_key.secrets`, rotation on) now encrypts the SSM SecureStrings (CKV_AWS_337) and `kms:Decrypt` is scoped to that key ARN (was `["*"]` + ViaService); the handler now clears stale `os.environ` for empty/placeholder/missing SSM params (warm-container reuse safety). Skipped with reason: CodeRabbit's `run_once` try/except (swallowing would hide a failed Lambda invocation from CloudWatch metrics/alarms — propagating is intended; `_tick`'s `gather(return_exceptions=False)` already bounds a batch) and fail-fast-on-missing-`KEEPER_SSM_PREFIX` (handler is Lambda-only, TF always injects the prefix, and `_main` already fails clean). `terraform validate` + `py_compile` clean.
- 2026-06-29 — claude — keeper Lambda hardening (Codex second-opinion). Handler now skips empty/`REPLACE_ME_IN_SSM_CONSOLE` SSM values, so an unset optional `ENSO_API_KEY` no longer becomes a bogus bearer token (and a forgotten required secret fails clean). SSM SecureString params gained `lifecycle { ignore_changes = [value] }` so a console-set secret isn't drift-reverted and the real value never enters tfstate. IAM tightened: `kms:Decrypt` gated by `kms:ViaService = ssm.<region>` ; OIDC deploy perms scoped to the exact `summer-earn-dca-keeper` function (was `summer-earn-*`). Documented the no-work-cap-vs-timeout limit. (Codex F1 "sensitive for_each" was a false positive — the `secrets` map var is intentionally non-sensitive; `terraform validate` passes.)
- 2026-06-29 — claude — added one-shot run mode (`--once` / `KEEPER_RUN_ONCE=1` → `run_once()` does a single `_tick()`); `_main(run_once)` branches between one-shot and `run_forever`. New `lambda_function.py` handler (fetches SSM SecureString secrets → `_main(run_once=True)`) + `Dockerfile` for a container Lambda. Scheduled via new Terraform `infrastructure/modules/lambda_keeper` (`module "dca_keeper"`, EventBridge `var.keeper_schedule_expression` default `rate(10 minutes)`, `reserved_concurrent_executions = 1`). Deploy workflow `.github/workflows/deploy-dca-keeper.yaml`; OIDC role gained `lambda:UpdateFunctionCode`. No change to the ABI / `StrategyConfig` tuple / flow.
- 2026-06-19 — claude — lockstep with contract CL-1: `StrategyConfig` feeds are now
  `ChainlinkFeed (address feed, uint256 maxStaleness)` tuples. Inline `DCA_MANAGER_ABI`
  feed components nested in both `checkUpkeep`/`executeStrategy`; `StrategyConfig`
  dataclass gained `in/outAssetFeedStaleness`; `as_tuple()` emits `(feed, maxStaleness)`
  for each feed; `from_subgraph` + `_SUBGRAPH_QUERY` read the staleness fields.
  `ast.parse` + ABI-JSON checks pass.
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
