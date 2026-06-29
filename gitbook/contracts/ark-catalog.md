---
description:
  A reference listing of every live Ark integration, grouped by category and showing base type and
  key behavioural traits.
---

# Ark Catalog

An **Ark** is the atomic yield-source adapter in the Summer Earn Protocol. Each Ark connects one
Fleet to one external protocol, handling deposits, withdrawals, reward harvesting, and position
accounting. Arks extend one of three base contracts — `Ark` (synchronous), `ArkWithSwap` (sync with
an integrated token swap path), or `ArkWithWithdrawalRequest` (async, queued-withdrawal flow) — and
are composed into Fleets by the `FleetCommander`. For a conceptual overview see
[Fleets and Arks](../concepts/fleets-and-arks.md).

Generated NatSpec reference pages for each contract live under
`contracts/core/reference/contracts/arks/`. The filenames used in all links below match the real
on-disk filenames verified at the time this page was written.

---

## Lending Markets

Supply-side integrations with on-chain money markets that earn variable borrow-rate yield.

| Contract                                                                       | Protocol / Venue              | Base Type              | Notable Traits                                                                               |
| ------------------------------------------------------------------------------ | ----------------------------- | ---------------------- | -------------------------------------------------------------------------------------------- |
| [AaveV3Ark](core/reference/contracts/arks/aave-v3-ark.md)                      | Aave V3                       | `Ark`                  | Sync; deposits into Aave V3 aTokens; supports `IRewardsController` harvest                   |
| [SparkArk](core/reference/contracts/arks/spark-ark.md)                         | Spark Protocol (Aave V3 fork) | `Ark`                  | Sync; uses Aave V3 pool interface; spTokens as position receipt                              |
| [CompoundV3Ark](core/reference/contracts/arks/compound-v3-ark.md)              | Compound V3 (Comet)           | `Ark`                  | Sync; deposits into a Comet market; harvests via `ICometRewards`                             |
| [MoonwellArk](core/reference/contracts/arks/moonwell-ark.md)                   | Moonwell                      | `Ark`                  | Sync; Compound V2-style mToken interface; validates mint/redeem return codes                 |
| [MorphoArk](core/reference/contracts/arks/morpho-ark.md)                       | Morpho Blue (isolated market) | `Ark`                  | Sync; targets a single `MarketParams` market; rewards via `IUniversalRewardsDistributor`     |
| [MorphoVaultArk](core/reference/contracts/arks/morpho-vault-ark.md)            | MetaMorpho vault              | `Ark`                  | Sync; wraps a MetaMorpho ERC4626 vault; supports URD reward claims                           |
| [MorphoV2VaultArk](core/reference/contracts/arks/morpho-v2-vault-ark.md)       | MetaMorpho V2 vault           | `ERC4626Ark` (→ `Ark`) | Sync; extends `ERC4626Ark` for V2 vault ABI; adapts V1 via `IMorphoVaultV1Adapter`           |
| [SiloVaultArk](core/reference/contracts/arks/silo-vault-ark.md)                | Silo Finance (V1 silo)        | `Ark`                  | Sync; interacts with `ISilo`; harvests via `ISiloIncentivesController`                       |
| [SiloVaultArkV2](core/reference/contracts/arks/silo-vault-ark-v2.md)           | Silo Finance V2 silo          | `Ark`                  | Sync; updated silo interface; streamlined reward handling                                    |
| [SiloManagedVaultArk](core/reference/contracts/arks/silo-managed-vault-ark.md) | Silo managed vault            | `Ark`                  | Sync; targets `ISiloVault` with gauge/hook receiver incentives                               |
| [FluidFTokenArk](core/reference/contracts/arks/fluid-f-token-ark.md)           | Fluid fToken                  | `ERC4626Ark` (→ `Ark`) | Sync; extends `ERC4626Ark`; harvests Fluid Merkle distributor rewards                        |
| [HyperlendArk](core/reference/contracts/arks/hyperlend-ark.md)                 | Hyperlend                     | `Ark`                  | Sync; Aave V3-compatible pool interface (`IHyperlendPool`); rewards via `IRewardsController` |
| [HypurrfiArk](core/reference/contracts/arks/hypurrfi-ark.md)                   | Hypurrfi                      | `Ark`                  | Sync; Aave V3-compatible pool interface (`IHypurrfiPool`); rewards via `IRewardsController`  |

---

## Staking / LST

Liquid-staking and staking-rewards strategies.

| Contract                                                                     | Protocol / Venue               | Base Type                  | Notable Traits                                                                                                            |
| ---------------------------------------------------------------------------- | ------------------------------ | -------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| [OriginETHArk](core/reference/contracts/arks/origin-eth-ark.md)              | Origin Protocol — OETH         | `ArkWithWithdrawalRequest` | Async; queued withdrawals via ARM contract; unwraps WETH before deposit                                                   |
| [OriginSuperOETHArk](core/reference/contracts/arks/origin-super-oeth-ark.md) | Origin Protocol — Super OETH   | `ArkWithWithdrawalRequest` | Async; same pattern as `OriginETHArk` but targets the Super OETH vault                                                    |
| [OriginUSDArk](core/reference/contracts/arks/origin-usd-ark.md)              | Origin Protocol — OUSD         | `ArkWithWithdrawalRequest` | Async; 18-decimal OUSD against 6-decimal USDC; decimal offset handled internally                                          |
| [ArmArk](core/reference/contracts/arks/arm-ark.md)                           | Origin ARM                     | `ArkWithWithdrawalRequest` | Async; deposits ETH/WETH via the ARM contract; single tracked request ID                                                  |
| [FluidLiteArk](core/reference/contracts/arks/fluid-lite-ark.md)              | Fluid Lite + Lido stETH        | `ArkWithWithdrawalRequest` | Async; stakes WETH → stETH via Lido then deposits into the FluidLite ETH vault; redemptions go through `IWithdrawalQueue` |
| [SkyRewardsArk](core/reference/contracts/arks/sky-rewards-ark.md)            | Sky Protocol — staking rewards | `Ark`                      | Sync; swaps fleet asset to USDS via Lite PSM, then stakes in `IStakingRewards`                                            |
| [SkyUsdsArk](core/reference/contracts/arks/sky-usds-ark.md)                  | Sky Protocol — sUSDS           | `Ark`                      | Sync; swaps fleet asset → USDS via Lite PSM, deposits into sUSDS ERC4626                                                  |
| [SkyUsdsPsm3Ark](core/reference/contracts/arks/sky-usds-psm3-ark.md)         | Sky Protocol — PSM3 + sUSDS    | `Ark`                      | Sync; uses PSM3 for the swap leg; single-contract sUSDS deposit                                                           |

---

## Fixed Yield (Pendle)

Pendle-based strategies that lock assets into fixed-rate principal tokens or LP positions.

| Contract                                                                   | Protocol / Venue              | Base Type                           | Notable Traits                                                                                               |
| -------------------------------------------------------------------------- | ----------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| [PendlePTArk](core/reference/contracts/arks/pendle-pt-ark.md)              | Pendle — Principal Token      | `BasePendleArk` (→ `ArkWithSwap`)   | Swap-based; buys PT before expiry, redeems at maturity; handles both pre- and post-expiry paths              |
| [PendleLPArk](core/reference/contracts/arks/pendle-lp-ark.md)              | Pendle — LP token             | `BasePendleArk` (→ `ArkWithSwap`)   | Swap-based; adds/removes single-sided liquidity to Pendle markets; post-expiry liquidity removal supported   |
| [PendlePtOracleArk](core/reference/contracts/arks/pendle-pt-oracle-ark.md) | Pendle — PT with Curve oracle | `Ark` + `CurveExchangeRateProvider` | Sync; prices PT position via the Pendle TWAP oracle and a Curve swap pool; configurable TWAP duration bounds |

---

## RWA / Institutional

Off-chain or permissioned assets tokenised on-chain, typically with settlement delays.

| Contract                                                                            | Protocol / Venue                                           | Base Type                                          | Notable Traits                                                                                                                                                                     |
| ----------------------------------------------------------------------------------- | ---------------------------------------------------------- | -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [SuperstateStandardArk](core/reference/contracts/arks/superstate-standard-ark.md)   | Superstate (USTB / USCC)                                   | `BaseSuperstateArk` (→ `ArkWithWithdrawalRequest`) | Async; T+1/T+2 settlement; tracks pending USDC subscriptions; uses Chainlink oracle for NAV                                                                                        |
| [SuperstateSubscribeArk](core/reference/contracts/arks/superstate-subscribe-ark.md) | Superstate (USTB)                                          | `BaseSuperstateArk` (→ `ArkWithWithdrawalRequest`) | Async; calls `ISuperstateToken.subscribe` directly; synchronous subscription path where supported                                                                                  |
| [MapleInstitutionalArk](core/reference/contracts/arks/maple-institutional-ark.md)   | Maple Finance — Institutional pools                        | `ArkWithWithdrawalRequest`                         | Async; queued redemptions via `ISyrupWithdrawalManagerV2`; targets permissioned Maple institutional pool                                                                           |
| [SyrupArk](core/reference/contracts/arks/syrup-ark.md)                              | Maple Finance — Syrup (V1)                                 | `ArkWithWithdrawalRequest`                         | Async; uses `ISyrupRouter` for permissioned entry; withdrawal manager resolves through pool manager                                                                                |
| [SyrupArkV2](core/reference/contracts/arks/syrup-ark-v2.md)                         | Maple Finance — Syrup (V2)                                 | `ArkWithWithdrawalRequest`                         | Async; V2 withdrawal manager; `authorizeAndDeposit` guard prevents double-permission deposits                                                                                      |
| [WisdomTreeArk](core/reference/contracts/arks/wisdom-tree-ark.md)                   | WisdomTree — tokenised assets (e.g. WTBTC)                 | `ArkWithWithdrawalRequest`                         | Async; off-chain custodial pattern; Chainlink oracle for NAV; custodian wallet set post-deploy                                                                                     |
| [SecuritizeArk](core/reference/contracts/arks/securitize-ark.md)                    | Securitize DS Protocol `DSToken` (e.g. VBILL, ACRED, STAC) | `ArkWithWithdrawalRequest`                         | Async; off-chain custodial pattern; on-ramp subscription mints the DSToken, redemptions sent to a Securitize-controlled wallet; external NAV oracle with heartbeat staleness check |
| [BenjiArk](core/reference/contracts/arks/benji-ark.md)                              | Franklin Templeton — iBENJI (MoneyMarketFund)              | `ArkWithSwap`                                      | Swap-based; mints/redeems iBENJI shares via `IBenjiToken`; uses `ISwapPool` for stablecoin entry/exit                                                                              |
| [AeraArk](core/reference/contracts/arks/aera-ark.md)                                | Aera / Gauntlet Alpha vaults                               | `ArkWithWithdrawalRequest`                         | Async; 24-hour request deadline; Chainlink-priced deposits/redeems via `IProvisioner`; configurable solver tip and slippage                                                        |
| [UpshiftArk](core/reference/contracts/arks/upshift-ark.md)                          | Upshift — TokenizedAccount                                 | `ArkWithWithdrawalRequest`                         | Async; epoch-based redemption (year/month/day tracking); single active request constraint                                                                                          |
| [SiUSDArk](core/reference/contracts/arks/si-usd-ark.md)                             | InfiniFi — siUSD vault                                     | `Ark`                                              | Sync; routes USDC through `IInfiniFiGateway` then deposits into the siUSD ERC4626 vault                                                                                            |

---

## PSM / Stablecoin Conversion

Peg Stability Module wrappers that convert between stablecoins before depositing into a yield vault.

| Contract                                                                   | Protocol / Venue     | Base Type | Notable Traits                                                                       |
| -------------------------------------------------------------------------- | -------------------- | --------- | ------------------------------------------------------------------------------------ |
| [Psm3ERC4626Ark](core/reference/contracts/arks/psm3-erc4626-ark.md)        | Sky PSM3 + sUSDS     | `Ark`     | Sync; PSM3 swap (e.g. USDC → sUSDS), then ERC4626 deposit; atomic single transaction |
| [PsmLiteERC4626Ark](core/reference/contracts/arks/psm-lite-erc4626-ark.md) | Sky Lite PSM + sUSDS | `Ark`     | Sync; LitePSM swap (USDC → USDS), then sUSDS ERC4626 deposit                         |

---

## Generic Adapters

Protocol-agnostic adapters for any vault that implements a standard interface.

| Contract                                                   | Protocol / Venue            | Base Type | Notable Traits                                                                                              |
| ---------------------------------------------------------- | --------------------------- | --------- | ----------------------------------------------------------------------------------------------------------- |
| [ERC4626Ark](core/reference/contracts/arks/erc4626-ark.md) | Any ERC4626-compliant vault | `Ark`     | Sync; pure pass-through to `IERC4626`; reusable base extended by `FluidFTokenArk`, `MorphoV2VaultArk`       |
| [BufferArk](core/reference/contracts/arks/buffer-ark.md)   | Fleet internal buffer       | `Ark`     | Sync; no-op board/disembark/harvest; holds idle liquidity within the Fleet rather than deploying externally |

---

## Cross-Chain

Arks that bridge assets to remote chains for yield.

| Contract                                                                   | Protocol / Venue | Base Type | Notable Traits                                                                                                                                            |
| -------------------------------------------------------------------------- | ---------------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [StargateV2PoolArk](core/reference/contracts/arks/stargate-v2-pool-ark.md) | Stargate V2      | `Ark`     | Sync deposit/withdraw on local pool; stakes LP tokens via `IStargateStaking`; multi-token rewards via `IMultiRewarder`; WETH unwrap handled for ETH pools |
