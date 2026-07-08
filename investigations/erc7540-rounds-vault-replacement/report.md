# ERC-7540 as a Replacement for the Rounds Vault — Investigation

> Evaluates replacing the bespoke `RoundsVaultInput`/`RoundsVaultOutput` batching layer with the
> [ERC-7540 Asynchronous Tokenized Vault standard](https://eips.ethereum.org/EIPS/eip-7540), under
> two architectures: **(A)** a major refactor making the FleetCommander itself an ERC-7540 vault,
> or **(B)** an ERC-7540 *entry-point* contract in front of a FleetCommander that stays plain
> ERC-4626. No code is implemented here; this is a design investigation.
>
> Reference material downloaded to [`.resources/`](#appendix-resources) (specs, OpenZeppelin
> community implementation, Centrifuge production vault).

**Status: draft for team review · 2026-07-08**

---

## 1. Executive summary

**Recommendation: Option B — an ERC-7540 entry-point vault with an external share token
(`share() = FleetCommander`), while the FleetCommander stays ERC-4626.**

The load-bearing facts:

1. **ERC-7540 requires ERC-7575, and ERC-7575 explicitly allows the vault's share token to be an
   external ERC-20** (`share() != address(this)`). The share-side `vault()` lookup is only a
   SHOULD, kept optional precisely "to maintain backward compatibility with use cases where the
   `share` is an existing deployed contract." An entry-point vault whose share is the existing
   FleetCommander can therefore be **fully standard-conformant without changing the Fleet at
   all**. This is not a compromise architecture — it is the pattern ERC-7540's authors built it
   for (Centrifuge, who wrote both ERCs, run exactly this in production).

2. **A single ERC-7540 flow (deposit or redeem) cannot be both sync and async.** The spec mandates
   that async-deposit vaults make `previewDeposit`/`previewMint` revert and turn `deposit`/`mint`
   into *claim* functions that transfer no assets. A FleetCommander refactored to async deposits
   breaks every synchronous consumer of its ERC-4626 ABI — AdmiralsQuarters `enterFleet`, the
   subgraphs' preview-based accounting, and any external 4626 integration. The current two-path
   architecture (AQ = sync, RoundsVault = async) is exactly the split ERC-7540 itself forces; the
   standard gives no way to collapse it into one vault without losing the sync path.

3. **The rounds model is already ERC-7540-shaped.** Rounds map 1:1 onto ERC-7540 `requestId`s: the
   spec requires all requests sharing a `requestId` to be fungible, to become claimable together,
   and to settle at one shared exchange rate — which is precisely what `setRoundSettled`'s
   per-round rate snapshot provides. The spec's rationale even blesses tokenizing pending claims
   as ERC-1155. The redesign is largely a *re-skinning of existing, working machinery behind a
   standard ABI*, not a new mechanism.

4. **Option A is the highest-blast-radius change available in this codebase.** The Fleet's
   ERC-4626 surface is entangled with tip accrual (a `totalSupply()` override), transient-storage
   caching, gateway/whitelist enforcement, buffer boarding, and four extra exit entry points, and
   exists in three variants (`FleetCommander`, `FleetCommanderDao`, `FleetCommanderWhitelist`).
   Replacing its share-issuance state machine touches all of it, forks the variant family further,
   and re-opens the audited vault core.

Option B replaces two contracts (`RoundsVaultInput` + `RoundsVaultOutput`) with **one** async
gateway per fleet, presents the standard interface integrators actually consume, and preserves the
operational model (keeper closes/settles epochs, governor emergency paths) nearly unchanged.

---

## 2. What exists today (baseline)

Authoritative in-repo docs:
`packages/core-contracts/src/contracts/rounds-vault/docs/INSTITUTIONAL_REFERENCE.md`.
Contracts: `packages/core-contracts/src/contracts/rounds-vault/` (~1,170 lines across
`RoundsVaultBase`, `RoundsVaultInput`, `RoundsVaultOutput`, `RoundsVaultRegistry`) built on
`packages/core-contracts/src/extensions/` (`ERC4626MultiToken`, `ERC4626MultiTokenWrapper`,
`ERC1155FullSupply`, ~430 lines).

Institutional fleets have **two entry paths** sharing one whitelist context (the Fleet address):

- **Path 1 — AdmiralsQuartersWhitelist (synchronous).** Multicall bundler; calls
  `fleet.deposit/withdraw` directly using its `OPERATOR_ROLE` gateway bypass. Used when the
  fleet's arks settle synchronously (buffer, Benji SwapPool).
- **Path 2 — RoundsVault pair (asynchronous).** Two ERC-1155 receipt vaults per fleet:
  - `RoundsVaultInput`: user deposits USDC → receipt `id = currentRound`; keeper `nextRound()`
    freezes the round, later `setRoundSettled(id)` deposits the frozen USDC into the fleet and
    snapshots `rate = fleetShares/USDC`; user later `redeemExchangeAsset(id, …)` burns receipts
    for fleet shares at that rate.
  - `RoundsVaultOutput`: mirror image — deposits fleet shares, settlement runs `fleet.redeem`,
    receipts exchange into USDC.
  - Round state machine: `NotOpened → Opened → InSettlement → Settled`, with
    `emergencyRollbackRound` (governor) + `retryRound` (keeper) as the stuck-round recovery pair,
    and current-round `redeem` as the user's cancel path.
  - Both vaults hold `OPERATOR_ROLE` on the fleet; users must be whitelisted on the fleet context
    for every operation, including ERC-1155 receipt transfers. `minPositionSize` is enforced
    post-flight on both entry and exit. `RoundsVaultRegistry` is the discovery root for the
    institutions-v2 subgraph.

Why the async layer exists at all (§6.1 of the reference): T+1 arks (WisdomTree, Securitize sell
leg) settle against an off-chain NAV strike. Synchronous deposits/withdrawals around a predictable
NAV update would let users sandwich the strike at existing holders' expense; batching per round and
pricing the batch off the *actual* settlement trade passes NAV drift pro-rata to that round's users
and to nobody else.

**Everything in this paragraph must survive any redesign.** ERC-7540 changes the interface, not
the economics.

---

## 3. ERC-7540 in brief, and the spec constraints that drive the decision

ERC-7540 (Final) extends ERC-4626 with a request lifecycle: `requestDeposit` / `requestRedeem`
place a request in **Pending**; vault-internal fulfillment moves it to **Claimable**; the user then
*claims* using the **existing ERC-4626 verbs** (`deposit`/`mint` claim shares, `redeem`/`withdraw`
claim assets). Spec text in [`.resources/erc-7540.md`](.resources/erc-7540.md).

Constraints that matter for us (all MUSTs in the spec):

| # | Constraint | Consequence for Summer |
|---|---|---|
| C1 | A vault implements async deposit, async redeem, or both. A flow that is async **must** make its preview functions revert, and its claim verbs (`deposit`/`mint` or `redeem`/`withdraw`) **must not** transfer assets/shares in (that happened at request time). A flow cannot be sync and async simultaneously. | An async-deposit FleetCommander loses its synchronous deposit path entirely (breaks AQ, previews, 4626 integrators). This kills the "one vault does both" idea in Option A. |
| C2 | Requests sharing a `requestId` **must** be fungible: they transition Pending→Claimable together and settle at the same rate. Different `requestId`s are unconstrained relative to each other. | Rounds *are* requestIds. `setRoundSettled`'s single per-round rate is exactly the required semantics. |
| C3 | Claims **must not** be pushed; the user **must** pull via the claim function, and Pending/Claimable must be separately observable (no skipping Claimable). | Matches today's model (users call `redeemExchangeAsset`). Keeper-push designs are off the table (they were never on it). |
| C4 | `requestDeposit` must support ERC-20 `approve`/`transferFrom` on `asset`; `requestRedeem` takes control of shares at request time (lock or burn). | Input side identical to today. Output side: entry point pulls fleet shares at request time — works because the entry point holds `OPERATOR_ROLE` (bypasses `transfersEnabled`), same as `RoundsVaultOutput` today. |
| C5 | Operator model: `setOperator(operator, approved)` lets a third party manage and claim a controller's requests. Mandatory interface (`0xe3bc4e65`). | New delegation surface that does not exist today; must be composed with the fleet-context whitelist (see §6.4). Naming collision with the protocol's own `OPERATOR_ROLE` is cosmetic but real — docs must disambiguate. |
| C6 | ERC-165 **must** be implemented, with fixed interface ids for deposit-async (`0xce3bbe50`), redeem-async (`0x620ee8e4`), operators, and ERC-7575 (`0x2f0a18c5`). | Free conformance signaling for integrators; trivial to implement. |
| C7 | ERC-7540 **requires ERC-7575**: the vault exposes `share()`, which **may be an external token**. If external, entry functions must increase `share.balanceOf(receiver)`; exits decrease the owner's. Share-side `vault()` lookup + ERC-165 on the share token are SHOULDs. | The keystone of Option B: `share() = FleetCommander`, `asset() = USDC`, fleet unchanged. Spec: [`.resources/erc-7575.md`](.resources/erc-7575.md). |
| C8 | ERC-7540 deliberately **excludes cancelation**; ERC-7887 (Draft) standardizes async cancel flows on top. | Today's current-round `redeem` (cancel before lock) has no 7540 equivalent. Keep it as an extension, or implement ERC-7887 (Centrifuge already does). Spec: [`.resources/erc-7887.md`](.resources/erc-7887.md). |
| C9 | Rationale sections explicitly permit tokenizing pending claims externally ("Vaults can elect to wrap these claims in any token standard they like, for example ERC-20, ERC-1155, or ERC-721") and note claim-by-id is intentionally left to a future standard. | The ERC-1155 receipts can survive as the *internal representation* of requests; the standard `deposit(assets, receiver, controller)` claim verbs don't take a `requestId`, so multi-round claims need FIFO/aggregation logic (§6.3). |

Also downloaded but secondary: ERC-7887 cancelation (Draft — API may still move) and ERC-7575
multi-asset/pipe patterns.

---

## 4. What the OpenZeppelin community implementation gives us — and where it stops

Source in [`.resources/oz-community-erc7540/`](.resources/oz-community-erc7540/) (MIT; from
`OpenZeppelin/openzeppelin-community-contracts`; docs page:
https://docs.openzeppelin.com/community-contracts/erc7540).

Architecture: an abstract **`ERC7540` base (~925 lines)** that *is its own ERC-20 share*
(`share() == address(this)`), routes each verb sync-vs-async off two pure selectors
(`_isDepositAsync`/`_isRedeemAsync`), handles operator management, the
`totalAssets()/totalSupply()` adjustments for pending amounts, and exposes 14 virtual hooks.
Fulfillment strategies plug in per side:

| Strategy | Fulfillment | Rate | Fit for Summer |
|---|---|---|---|
| `ERC7540AdminDeposit` / `AdminRedeem` | Privileged caller calls `_fulfillDeposit(assets, shares, controller)` **per controller** | Locked at fulfillment; multiple fulfillments **blend to a weighted average** per controller | Right trust model (keeper-fulfilled), wrong granularity: settlement gas is O(number of controllers) per epoch, vs O(1) per round today; blended rates break today's "each round settles at exactly its trade's rate" property |
| `ERC7540DelayDeposit` / `DelayRedeem` | Time-based; claimable after a delay, **rate computed at claim time** from live `convertToShares` | Claim-time | Wrong for NAV-strike fairness — the whole point is locking the rate at the settlement trade, not at claim time |
| `ERC7540SyncDeposit` / `SyncRedeem` | Standard 4626 side | n/a | Used to build half-async combos |

All OZ strategies use `requestId = 0` (pure per-controller accounting). The AdminDeposit NatSpec
itself points at the gap: "Epoch-based batch settlement, FIFO queues … can all be composed on
top", and lists Centrifuge/USDai/Plume Nest/MetaVault as production equivalents.

**Conclusions:**

- For **Option B** the OZ base is *not directly usable*: it hard-wires `share() == address(this)`
  and mints/burns its own ERC-20. An external-share (ERC-7575) vault implements `IERC7540` +
  `IERC7575` directly, Centrifuge-style ([`.resources/prior-art/centrifuge-AsyncVault.sol`](.resources/prior-art/centrifuge-AsyncVault.sol)).
  The OZ code is still valuable as a semantics reference (verb routing, event parameter order,
  max* behavior, ERC-165 wiring).
- For **Option A** the OZ base fits structurally (the Fleet *is* its own share token) but every
  strategy would still need replacement with a custom **epoch strategy** (requestId = round,
  O(1) settlement, per-round rates) — i.e. porting `RoundsVaultBase`'s round machinery into the
  Fleet.
- Either way, **the epoch/round fulfillment strategy is ours to write**; the standard and the OZ
  code confirm it's a legitimate, anticipated pattern rather than a spec bend.

---

## 5. Option A — FleetCommander becomes the ERC-7540 vault

### 5.1 Shape

`FleetCommanderWhitelist` (or a new `FleetCommanderAsync` variant) replaces its OZ `ERC4626` base
with an ERC-7540 implementation. Request queues, epoch settlement, and claim accounting live
inside the Fleet. The RoundsVault pair and its registry disappear. Users hold
pending/claimable positions directly against the vault; `requestId = epoch`.

Sub-variants:

- **A-full**: both flows async. The conformant shape for a fleet holding T+1 arks on both legs
  (WisdomTree). `previewDeposit/previewMint/previewWithdraw/previewRedeem` all revert.
- **A-half**: sync deposit + async redeem (the liquid-staking pattern). Only viable if deposit-side
  NAV-strike risk is acceptable — it is not for stale-NAV RWA fleets (§2), so this fits only
  fleets whose deposit leg is instant (Securitize buy, Benji) but whose exit leg is T+1.

### 5.2 What it breaks / must be rebuilt

- **AdmiralsQuarters sync path dies (C1).** `AQ.enterFleet` calls `fleet.deposit(assets, receiver)`
  expecting an atomic mint; under async-deposit semantics that call becomes a claim of a
  previously fulfilled request and transfers nothing in. Every AQ multicall recipe (deposit,
  Permit2 entry, Aave/Compound/4626 import → enterFleet) stops working against an A-full fleet.
  The Benji-style instant fleets would keep a *separate* sync FleetCommander — meaning the variant
  family grows, not shrinks.
- **ERC-4626 integrations break by construction.** Reverting previews are the spec's *feature*
  (C1) — but the protocol-subgraph, rwa-app position math, the RoundsVault min-position validator
  (`previewRedeem`), and any external integrator currently assume a live-priced 4626 vault.
- **Deep entanglement with the Fleet's internals.** Concretely, in
  `packages/core-contracts/src/contracts/FleetCommanderWhitelist.sol`:
  - every entry point stacks `flushCacheOnExit useCache collectTip whenNotPaused` + gateway
    enforcement; request/claim verbs need the same treatment, decided case-by-case;
  - `totalSupply()` is overridden to fold in previewed tip shares; ERC-7540 accounting also wants
    `totalSupply()` to include pending-redeem shares (see OZ base) — two virtual-supply
    adjustments interacting with fee math and the share price;
  - `totalAssets()` is the cached sum of ark holdings; pending deposit assets awaiting fulfillment
    must be held *outside* that sum (not boarded to the buffer) or explicitly excluded, otherwise
    they dilute/inflate the very rate their fulfillment uses;
  - the four extra exits (`withdrawFromBuffer/redeemFromBuffer/withdrawFromArks/redeemFromArks`)
    are sync-redeem semantics; under A-full they must be removed or re-gated, under A-half they
    conflict with the async redeem queue's fairness (someone who queues waits; someone who calls
    `withdrawFromBuffer` doesn't).
- **ABI change on the most-integrated contract.** HarborCommand-driven subgraph templates,
  gov-validator, interface, rwa-app, deployment scripts, keeper `rebalance` tooling all touch the
  Fleet ABI. (Blast radius detail in §7.)
- **Re-audit of the vault core.** The share-issuance state machine is the most security-critical
  code in the protocol; Option A rewrites it. Today's separation deliberately keeps async
  complexity *outside* the audited 4626 core, with the RoundsVault holding only round-scoped
  funds in flight.

### 5.3 What it buys

- One contract per fleet; no operator-role bridge contracts; requests are first-class on the vault
  integrators see.
- The Fleet itself advertises ERC-7540 via ERC-165 — marginally cleaner discovery than a separate
  entry point.
- No share custody hop: claims mint/transfer shares directly, rather than the entry point holding
  fleet shares between settlement and claim.

These are real but thin — and §6 shows Option B delivers the integrator-facing benefits anyway,
because what integrators consume is the *vault interface + share token*, and B presents both.

---

## 6. Option B — ERC-7540 entry point; FleetCommander stays ERC-4626

### 6.1 Shape

One new contract per fleet — working name **`AsyncFleetGateway`** — implementing
`IERC7540Deposit + IERC7540Redeem + IERC7540Operator + IERC7575` with:

```
asset()  = fleet.asset()          (e.g. USDC)
share()  = address(fleet)         (external share per ERC-7575)
```

It replaces **both** `RoundsVaultInput` and `RoundsVaultOutput` (ERC-7540 hosts both flows in one
contract; deposit epochs and redeem epochs advance independently, exactly as the Input/Output
pair's rounds do today). It holds `OPERATOR_ROLE` on the fleet, same as the pair today.

Flow mapping — nearly mechanical:

| Today (RoundsVault pair) | AsyncFleetGateway (ERC-7540) |
|---|---|
| `Input.deposit(assets, receiver)` → mint receipt `id = round` | `requestDeposit(assets, controller, owner)` → Pending, `requestId = depositEpoch` |
| `Input.redeem(currentRound, …)` (cancel) | non-standard `cancelDepositRequest` extension, or ERC-7887 flow |
| keeper `Input.nextRound()` | keeper `closeDepositEpoch()` (Pending frozen) |
| keeper `Input.setRoundSettled(id)` → `fleet.deposit(frozen)` , snapshot rate | keeper `settleDepositEpoch(id)` → identical trade + per-epoch rate; Pending→Claimable for every request in the epoch (C2 satisfied) |
| user `redeemExchangeAsset(id, …)` → fleet shares | user `deposit(assets, receiver, controller)` / `mint` → transfers fleet shares held by the gateway (ERC-7575 external-share rule: `share.balanceOf(receiver) += shares`) |
| `Output.deposit(fleetShares, …)` | `requestRedeem(shares, controller, owner)` — gateway pulls fleet shares (operator bypass on `transfersEnabled`), `requestId = redeemEpoch` |
| keeper settles Output round → `fleet.redeem(frozen)` | keeper `settleRedeemEpoch(id)` → identical |
| user exchanges Output receipt → USDC | user `redeem(shares, receiver, controller)` / `withdraw` → USDC out |
| `emergencyRollbackRound` / `retryRound` | keep verbatim (non-standard admin surface is unconstrained by the ERC) |
| empty-round fallback rate | unnecessary — an epoch with no requests settles trivially (nothing becomes claimable) |

The settlement core — freeze a liability, execute one trade against the fleet, snapshot
`toPrice(out, in)`, let users pull pro-rata — is `RoundsVaultBase._setRoundSettled` unchanged.
`ERC4626MultiTokenWrapper._depositOnTarget/_redeemFromTarget` carry over as-is.

### 6.2 Conformance status: full

- Vault-side: all MUSTs implementable (C1–C7). ERC-165 ids per C6. `previewDeposit` etc. revert —
  harmless here because *nothing else consumes the gateway's previews*; the Fleet's own previews
  stay live for AQ and integrators.
- Share-side (`FleetCommander` as the ERC-7575 share): `vault(asset)` lookup + `IERC7575Share`
  ERC-165 are SHOULDs, explicitly optional for pre-existing share tokens (C7). Zero fleet changes
  required; a future fleet version could add the ~15-line lookup for polish.
- The ERC-7575 security note about `owner != msg.sender` redeem flows is satisfied without
  ERC-2771 tricks: users grant standard ERC-20 allowance on fleet shares to the gateway (identical
  UX to approving `RoundsVaultOutput` today), or use `setOperator`.

### 6.3 The one real design decision: `requestId` semantics and claim accounting

The standard claim verbs (`deposit(assets, receiver, controller)`, `redeem(shares, receiver,
controller)`) take **no requestId** (C9). Two coherent designs:

- **B-epoch (recommended): `requestId = epoch`, ERC-1155 receipts retained as the request
  representation.** `pendingDepositRequest(id, ctrl)` = receipt balance while epoch open/frozen;
  `claimableDepositRequest(id, ctrl)` = receipt balance once settled; `maxDeposit(ctrl)` = sum
  over settled epochs. Claim verbs consume receipts FIFO across the controller's settled epochs at
  each epoch's snapshotted rate (deterministic, no blending). Receipts stay transferable between
  whitelisted users — a property institutions use today and which pure per-controller accounting
  cannot express. Cost: FIFO iteration needs an enumerable per-controller epoch set (bounded by
  epochs-with-holdings, and a claim-by-ids extension method can bypass iteration entirely).
- **B-zero: `requestId = 0`, per-controller aggregation** (Centrifuge/OZ style). Simpler views, no
  iteration; but multiple epochs' fulfillments **blend into weighted-average rates** per
  controller, receipts (if kept) become non-authoritative, and transferability of claims is lost.
  It also degrades today's exact-rate-per-round auditability, which the subgraph and post-mortem
  tooling rely on.

B-epoch is closer to the existing system, strictly more expressive, and spec-clean under C2.

### 6.4 Carry-over obligations

- **Whitelist**: every user-facing verb keeps `_revertIfNotWhitelisted(fleet, …)` on
  caller/owner/receiver/controller — same contexts as today. ERC-7540's `setOperator` (C5) must
  *not* become a whitelist bypass: claims executed by an approved 7540-operator still check the
  controller's and receiver's whitelist status. Document the `setOperator` vs protocol
  `OPERATOR_ROLE` terminology split.
- **minPositionSize**: enforce at *request* time (request MUST revert if it can't be accepted —
  spec-sanctioned). Avoid gating the *claim* path on it: a user whose whitelist/minimums changed
  mid-flight must still be able to pull settled funds (today's post-flight check on
  `redeemExchangeAsset` would translate poorly; flag for product decision).
- **Cancelation**: keep the current-epoch cancel (today's `redeem` on the open round) as an
  explicit non-standard method, and optionally implement ERC-7887 for standard-shaped cancels.
  7887 is Draft — implement the interface, don't lean on its stability.
- **Fees**: none at the gateway (unchanged — tips accrue in the Fleet).
- **Fleet caps**: settlement `fleet.deposit` can revert on `depositCap` just as today;
  rollback/retry recovery paths carry over verbatim.

### 6.5 What still changes off-chain (see §7 for the full list)

New events replace the rounds-vault event family; the institutions-v2 subgraph needs a new
data-source template + entities (requests, epochs, claims); the rwa-app deposit/withdraw flows and
keeper panels re-target the gateway ABI; deployment gets a new ignition module + zod schema; the
registry either gains a `gatewayVault` field or is superseded by ERC-165-based discovery plus a
slimmer registry (subgraphs still need an on-chain discovery root — keep the registry pattern,
one address per fleet instead of an input/output pair).

---

## 7. Blast radius (off-chain and cross-package)

Both options retire the rounds-vault event/ABI family, so most of this section applies to
**either** option; Option A *adds* the FleetCommander ABI consumers on top. Compiled from a
full-repo sweep.

### 7.1 The de-facto public API being replaced

- **Events**: `RoundAdvanced`, `RoundSettled(uint256,(uint256,uint256))`, `RoundRetried`,
  `EmergencyRoundRolledBack`, `MinPositionSizeUpdated`, `AssetsDeposited`, `SharesRedeemed`,
  `WithdrawExchangeAsset[Batch]`, registry `RoundsVaultPairRegistered/Updated/Deactivated/
  Reactivated`, inherited `DepositWithReceipt`/`RedeemReceipt[Batch]`, and ERC-1155
  `TransferSingle`/`TransferBatch` (receipts). ERC-7540's `DepositRequest`/`RedeemRequest`/
  `Deposit`/`Withdraw`/`OperatorSet` replace all of these with different signatures.
- **Functions** consumed off-chain: user `deposit`/`redeem[Batch]`/`redeemExchangeAsset[Batch]`/
  `setApprovalForAll`; keeper `nextRound`/`setRoundSettled[Batch]`/`retryRound`; governor
  `emergencyRollbackRound`/`setMinPositionSize`; reads `getCurrentRound`/`roundState`/
  `getExchangeRate`/`minPositionSize`/`totalSupply(roundId)`/`vault`/`exchangeAsset`.

### 7.2 Per package

**`packages/deployment`** — `ignition/modules/rounds/rounds-vault.ts` + `rounds-vault-registry.ts`
(modules); `scripts/deploy-rounds-vault-registry.ts`; `scripts/deploy-whitelisted-fleet.ts` +
`-v1.ts` (the main coupling: `operatorType === 'roundsVaults'` deploys the pair, writes
`roundsVaultInput/Output` into fleet config, calls `registerPair`); `scripts/revoke-aq-operator.ts`
(rounds fleets revoke AQ's operator role — AQ vs rounds is a **per-fleet fork**, not always
coexistence); `scripts/helpers/zod-schemas.ts` (`operatorType` enum + vault address fields);
`types/config-types.ts`; `scripts/verify/by-future-filter.ts`; `config/index{,.test}.json`
(`core.roundsVaultRegistry`); institution configs for Avantgarde, ExtDemoCorp_3, ExtDemoCorp_v2,
Orthodox (fleets with `operatorType: roundsVaults` and inlined vault addresses). Note the Ignition
module-name keys (`…#RoundsVaultInput` etc.) in `ignition/deployments/*/deployed_addresses.json`
are copied verbatim into gov-validator, gov-alert-bot and interface config bundles.

**`packages/summer-earn-institutions-v2-subgraph`** — heaviest coupling. `RoundsVaultRegistry` is
a static data source whose `RoundsVaultPairRegistered/Updated` handlers **spawn dynamic templates**
(`RoundsVaultInputTemplate`/`OutputTemplate`) — this auto-discovery is why new institution vaults
need no subgraph config change, and any replacement must emit an equivalent registration event.
12 handlers per flavor (`src/mappings/roundsVault{Input,Output}.ts`), round/receipt state machine
(`src/utils/lifecycle.ts`, `receipt.ts`), entities `RoundsVaultPair`/`RoundsVault`/`Round`/
`Receipt`/`ReceiptActivity` + enums in `schema.graphql`, committed ABIs, and
`rounds-vault-registry-address` in every `config/<network>{,-staging}.json`. Event signatures
(including the `RoundSettled` tuple) are hardcoded in `subgraph.template.yaml`. Full rewrite of
this subgraph's rounds model under either option.

**`packages/summer-earn-rwa-app`** — primary user + admin UI. Deposit/withdraw/receipts pages
under `institutions/[id]/fleets/[fleet]/`; `components/rounds/*` (DepositForm, ReceiptTable,
ExchangeRateDisplay), `components/admin/RoundsControlPanel.tsx`; hooks with hardcoded function
names (`useRoundsActions`, `useKeeperActions`, `useGovernorActions`, `useRoundsVaultState`,
`useRounds`, `useUserReceipts`); `lib/rounds/rate.ts` (mirrors the `Price{base,quote}` math) and
`lib/rounds/roundState.ts` (mirrors the 0–3 enum); SSR loaders, subgraph queries/types, ABIs, and
the hand-maintained `config/institutions.ts` address directory.

**`packages/summer-earn-interface`** — secondary dev dashboard: `app/rounds-vault/[chainId]/`
route, `components/rounds-vault/RoundsVaultDashboard.tsx` + `VaultInteractionForm.tsx` (calls the
full user/keeper/governor surface), ABIs, and copied deployed-address configs.

**`packages/institution-inspector`** — graph node/edge types for input/output vaults, on-chain
reconciliation against `RoundsVaultRegistry.getPair`, prebuilt graph snapshots.

**`packages/summer-earn-gov-validator` / `gov-alert-bot`** — config-only copies of deployed
addresses; no logic.

**`packages/core-contracts` tests** — 7 Foundry files, ~96 tests (`RoundsVaultInput/Output/
Registry/MinPosition/TwoPhaseSettlement/Precision.fuzz` + `RoundsFleet.lifecycle.fork`), plus 11
interface files and the `ERC4626MultiToken*` extensions.

### 7.3 Keeper automation reality check

There is **no off-chain keeper service** for rounds today: `nextRound`/`setRoundSettled[Batch]`/
`retryRound` are called manually from the rwa-app admin panel and the interface dev dashboard.
ark-rebalancer and the other services have zero references. Renaming these entry points is
therefore a UI change, not an automation change — and conversely, the redesign is a natural moment
to decide whether epoch advancement should get real automation.

---

## 8. Comparison

| Dimension | A — Fleet becomes ERC-7540 | B — ERC-7540 entry point |
|---|---|---|
| Standard conformance | Full, on the Fleet itself | Full, on the gateway (external share per ERC-7575) |
| FleetCommander changes | Core rewrite (share machine, previews, exits, tips/cache interplay), variant family forks | **None** |
| Sync path (AQ) coexistence | Broken for async flows (C1); needs a second sync fleet | Preserves today's per-fleet choice (`operatorType` fork: rounds fleets revoke AQ's operator role; sync fleets keep AQ) |
| Contracts per fleet (async path) | 0 extra (in-vault) | 1 (replaces today's 2) |
| Settlement gas model | O(1)/epoch if custom epoch strategy is built in-vault | O(1)/epoch (same machinery relocated) |
| Reuse of existing audited code | Low — round machinery must be rewoven into vault internals | High — `_setRoundSettled` core, wrapper helpers, whitelist, recovery paths carry over |
| Audit surface | Vault core re-audit + new async machinery | New gateway contract only; Fleet audit intact |
| Integrator story | 7540 vault, but Summer-specific everywhere else | 7540 vault + plain 4626 fleet — both standard |
| Off-chain churn | Fleet ABI + rounds stack + subgraphs + apps | Rounds stack + institutions-v2 subgraph + rwa-app; Fleet-facing tooling untouched |
| Migration | Redeploy fleets (institutional fleets are live) or in-place upgrade none of these contracts support | Deploy gateways alongside live rounds pairs; drain and decommission pairs per the existing decommission checklist (INSTITUTIONAL_REFERENCE §12.5) |
| Cancelation | Custom or ERC-7887, entangled with vault state | Custom or ERC-7887, isolated in gateway |

**Recommendation: Option B**, with the B-epoch requestId design (§6.3). Revisit Option A only if a
hard requirement emerges that the FleetCommander contract itself must present ERC-7540 (no such
integrator requirement is visible today — custody platforms and vault aggregators integrate the
vault+share pair, which B provides).

Suggested next steps if the team concurs:

1. Spike `AsyncFleetGateway` (interface + storage layout + epoch strategy) against a fork of a
   live institutional fleet; confirm gas for FIFO claims across ≤4 settled epochs.
2. Decide receipts question (§6.3) and cancel semantics (§6.4) with product.
3. Registry evolution: add gateway registration events so the institutions-v2 subgraph can spawn
   templates (mirror of `RoundsVaultPairRegistered`).
4. Parallel-run one fleet (gateway + legacy pair), then decommission pairs via the documented
   sequence in INSTITUTIONAL_REFERENCE §12.5.

Open questions for the team:

- Do any current institutional integrators consume `RoundsVault` ABI directly (outside our own
  rwa-app)? If yes, deprecation timeline matters more than contract design.
- Should deposit-epoch and redeem-epoch cadence stay independent per fleet (today: yes, via the
  Input/Output split)? The single-gateway design keeps them independent internally; confirm the
  keeper playbook wants that.
- Is claim transferability (receipts) a real institutional requirement or incidental? It decides
  B-epoch vs B-zero.
- ERC-7887 now or later? (Draft status vs Centrifuge already shipping it.)

---

## Appendix: resources

Downloaded to `.resources/` for offline reference. Note `.resources` is **git-ignored repo-wide**
(`.gitignore` `.resources` rule), so these files exist only in the checkout where this
investigation ran — re-fetch from the sources below if needed
(`gh api -H "Accept: application/vnd.github.raw" repos/<org>/<repo>/contents/<path>`):

| Path | What | Source / license |
|---|---|---|
| `erc-7540.md` | ERC-7540 spec (Final) | `ethereum/ERCs` → `ERCS/erc-7540.md` (CC0); rendered at https://eips.ethereum.org/EIPS/eip-7540 |
| `erc-7575.md` | ERC-7575 spec (Final) — external share tokens, multi-asset vaults | `ethereum/ERCs` → `ERCS/erc-7575.md` (CC0) |
| `erc-7887.md` | ERC-7887 spec (Draft) — cancelation extension for 7540 | `ethereum/ERCs` → `ERCS/erc-7887.md` (CC0) |
| `oz-community-erc7540/` | OpenZeppelin community-contracts: `ERC7540.sol` base, Admin/Delay/Sync deposit+redeem strategies, `IERC7540.sol`, docs page (`erc7540-docs.adoc`) | `OpenZeppelin/openzeppelin-community-contracts` → `contracts/token/ERC20/extensions/`, `contracts/interfaces/`, `docs/modules/ROOT/pages/erc7540.adoc` (MIT); rendered at https://docs.openzeppelin.com/community-contracts/erc7540 |
| `prior-art/centrifuge-*.sol` | Centrifuge production `AsyncVault` (+ `BaseVaults`, interface) — external-share ERC-7540 + ERC-7887, epoch fulfillment via manager | `centrifuge/protocol` → `src/vaults/` (BUSL-1.1 — reference only, do not copy code into our contracts) |
