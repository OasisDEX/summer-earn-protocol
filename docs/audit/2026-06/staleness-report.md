# Documentation Staleness Report

Generated from recovered Claude docs-alignment-audit structured outputs plus continued local claim verification. This report currently covers completed groups only.

## Progress

- Completed groups: 10/10 (earn:cross-chain, earn:dca, earn:deployment, earn:governance, earn:institutional, earn:intent-arks, earn:pkg-readmes, mono:bundle-admin, mono:bundle-user, mono:misc)
- Remaining groups: none
- Documents covered: 31
- Claims checked: 1222
- Stale claims recorded: 76

## Document Verdicts

| Group | Document | Verdict | Claims checked | Stale | Unverifiable |
| --- | --- | --- | ---: | ---: | ---: |
| earn:cross-chain | docs/cross-chain/OVERVIEW.md | stale | 15 | 4 | 0 |
| earn:cross-chain | docs/cross-chain/REBALANCING_FLOW.md | obsolete | 22 | 4 | 0 |
| earn:cross-chain | docs/cross-chain/BRIDGE_ROUTER_AND_ADAPTERS.md | partially-stale | 19 | 1 | 0 |
| earn:cross-chain | docs/cross-chain/REGISTRY_AND_SECURITY.md | partially-stale | 15 | 2 | 1 |
| earn:cross-chain | docs/cross-chain/OPERATIONS_PLAYBOOK.md | stale | 12 | 3 | 0 |
| earn:dca | packages/core-contracts/docs/DCAStrategyManager.md | partially-stale | 42 | 6 | 0 |
| earn:dca | packages/core-contracts/src/contracts/DCA/DCAStrategyManager.technical.md | current | 75 | 0 | 0 |
| earn:dca | packages/core-contracts/src/contracts/DCA/DCAStrategyManager.product.md | current | 65 | 0 | 1 |
| earn:dca | packages/summer-earn-dca-app/CLAUDE.md | current | 50 | 0 | 1 |
| earn:dca | packages/summer-earn-dca-subgraph/CLAUDE.md | current | 52 | 0 | 1 |
| earn:deployment | packages/deployment/README.md | partially-stale | 88 | 6 | 0 |
| earn:deployment | packages/deployment/docs/MERGE_PROPOSALS.md | current | 32 | 1 | 0 |
| earn:deployment | packages/deployment/config/cross-chain/README.md | current | 18 | 1 | 1 |
| earn:governance | docs/governance_rules.md | partially-stale | 18 | 3 | 1 |
| earn:governance | packages/gov-contracts/README.md | partially-stale | 30 | 4 | 0 |
| earn:governance | packages/gov-contracts/README_Governance_v2.md | partially-stale | 72 | 2 | 1 |
| earn:governance | packages/gov-contracts/README_VestingV2.md | partially-stale | 42 | 5 | 1 |
| earn:institutional | packages/core-contracts/src/contracts/rounds-vault/docs/INSTITUTIONAL_REFERENCE.md | partially-stale | 110 | 1 | 1 |
| earn:institutional | packages/summer-earn-rwa-app/README.md | boilerplate | 12 | 2 | 1 |
| earn:institutional | packages/summer-earn-rwa-app/AGENTS.md | current | 4 | 0 | 1 |
| earn:institutional | packages/summer-earn-institutions-v2-subgraph/README.md | current | 34 | 0 | 1 |
| earn:intent-arks | packages/intent-system/README.md | partially-stale | 23 | 4 | 1 |
| earn:intent-arks | packages/intent-system/solver-mvp/SOLVER_README.md | partially-stale | 30 | 5 | 3 |
| earn:intent-arks | packages/intent-system/solver-mvp/README.md | obsolete | 10 | 1 | 2 |
| earn:intent-arks | packages/core-contracts/src/contracts/arks/README.md | partially-stale | 45 | 4 | 0 |
| earn:intent-arks | packages/dutch-auction/README.md | partially-stale | 30 | 3 | 1 |
| earn:pkg-readmes | packages/*/README.md inventory | partially-stale | 48 | 6 | 1 |
| mono:bundle-admin | sdk/sdk-client/bundle/README-ADMIN.md | partially-stale | 62 | 2 | 1 |
| mono:bundle-user | sdk/sdk-client/bundle/README.md | partially-stale | 95 | 1 | 1 |
| mono:misc | README.md | partially-stale | 24 | 2 | 1 |
| mono:misc | misc README inventory | partially-stale | 28 | 3 | 1 |

## Group Summaries

### earn:cross-chain

Audited 5 cross-chain docs (83 claims) against packages/chain-bridge/src and packages/core-contracts/src. The bridge layer the docs describe is fully intact and matches precisely: BridgeRouter (1% fee buffer via (fee*101)/100, onlyAuthorizedExecutor gating, explicit BridgeOptions.specifiedAdapter selection, token pull + forceApprove, best-effort IInflightAssetTracking notification, onlyRegisteredAdapter deliver with PEER_RELATIONSHIP peer-mapping check, governance adapter registry, pause/unpause, recoverAssets, nonReentrant), CrossChainRegistry (onlyGovernor register/unregister, ARK_FLEET/PEER/EXECUTOR relationship constants, exact getRelationshipByTarget and isValidCrossChainPair signatures with uint16 chain IDs), and Stargate/LayerZero adapters (estimateFee/transferAsset/sendMessage/readState, refund handling, failedComposes fail-safe, manualRecovery). However, the fleet-level endpoints — CrossChainArk and FleetProxy — were deprecated and moved to .sol.old legacy files in commit 8c0beb15d (2026-02-10), five months after the docs' last update (43ac4ab83, 2025-09-09); functions/state the docs cite (withdrawAndTransfer, notifySourceChain, inflightAssets, lastRemoteAssetBalance, latestIncomingTransferId, the queue/execute flow) exist only in legacy files, with orphan interfaces (ICrossChainArk, IFleetProxy) and no active implementations. A cross-cutting inaccuracy in three docs: registry 'authorized executor' registration applies to the contract calling the router (the Ark/Proxy itself, since originator must equal msg.sender), not keeper addresses, which were gated by the access-manager keeper role. Verdicts: BRIDGE_ROUTER_AND_ADAPTERS and REGISTRY_AND_SECURITY partially-stale; OVERVIEW and OPERATIONS_PLAYBOOK stale; REBALANCING_FLOW obsolete.

### earn:dca

Audited 5 DCA docs against DCAStrategyManager.sol, its interface/events/errors, Permit2/Chainlink/Enso helpers, and the DCA app/subgraph packages (284 claims). The older packages/core-contracts/docs/DCAStrategyManager.md is partially-stale: it still describes a withdrawal/asset approval execution flow, treats the config hash as the strategy ID, lists a 7-day minimum interval, shows maxTrades as uint248, and overstates reuse of the original config after edits. The newer technical and product references are current for the refactored share-swap design, commitment model, Permit2 flows, keeper checks, price guards, and lifecycle behavior. The DCA app and subgraph CLAUDE docs also match the checked package code and config.

### earn:deployment

Audited 3 docs in packages/deployment against scripts, ignition modules, and configs (138 claims total). README.md is partially-stale: all 11 pnpm commands, governance parameters (60s/600s/10k SUMMER/4%), staking constants (0-3yr lockup, 2-20% penalties), core/staking/gov deployment orders, and merkle paths/schema are confirmed, but the prerequisite says Node 16+ (engines require >=20), the example fleet config file usdc-base-USDC-1.json does not exist (actual pattern: base-USDC-1.json with different values), the example deployment file's addresses/values no longer match, the 'Supported Ark Types' list of 5 omits 31 of the 36 ArkType enum members, and the directory tree is far out of date. docs/MERGE_PROPOSALS.md is current: script behavior, error strings, data structures, and merge logic all match scripts/merge-proposals.ts verbatim; only the claimed 'Valid Structure' validation is not actually implemented. config/cross-chain/README.md is current: JSON shape and helper signatures match scripts/helpers/cross-chain-config.ts exactly and CrossChainRegistry.sol exists; one nuance — crossChainArkAddress is recorded via a manual prompt in deploy-fleet-proxy.ts, not by the CrossChainArk deployment itself, and the directory currently holds no committed config files.

### earn:governance

Audited 4 governance docs against gov-contracts source and deployment modules (162 claims). docs/governance_rules.md is partially-stale: its process structure is policy, but the numeric on-chain defaults have drifted (600s voting period, 4% quorum, gov minDelay default 0; 10,000 SUMR threshold still matches deployment defaults). packages/gov-contracts/README.md is a v1-era overview with stale token/vesting/deploy and TBD decay-window claims. README_Governance_v2.md is mostly current for xSUMR, hub/satellite governance, staking, penalties, bucket caps, and escrow mechanics; only exact bucket-boundary wording and the appendix wording about which params are threshold-validated need correction. README_VestingV2.md is mostly aligned with the active V2 factory/wallet contracts, but external goal numbers are 1-based, addNewGoal requires token transfer/allowance, recall transfers the entire remaining wallet balance, and the listed test files do not exist.

### earn:institutional

Audited 4 institutional/RWA docs against rounds-vault contracts, WisdomTreeArk, MapleInstitutionalArk, FleetCommanderWhitelist/AQ whitelist access paths, the RWA app, and the v2 institutions subgraph (160 claims). The main institutional technical reference is mostly current and detailed, with one registry lifecycle drift: there is no removal path that would allow re-registering a pair for the same target; existing pairs are updated/deactivated/reactivated instead. The RWA app README is default create-next-app boilerplate and has stale path/font claims despite the package containing a real institutional UI. The app AGENTS note and the v2 subgraph README are current for their narrow scope.

### earn:intent-arks

Audited 5 docs in group earn:intent-arks. None fully current. (1) intent-system/README.md: partially-stale — architecture, signatures, 10-min BUFFER_TIME, 50% slash and hasCommitted all confirmed, but createBond is keeper-only (doc says solver calls it), resignByUser is keeper-only and also works in Solved state (doc says Ark-only, Created-only), and the state diagram omits the Active state. (2) solver-mvp/SOLVER_README.md: partially-stale — script-facing claims (addresses, menu, gas, API) match simple_solver.py, but requirements.txt doesn't exist, the '1000 SUMMER minimum' isn't an on-chain rule, the documented Intent struct omits the contract's requiredBond field, and createBond is keeper-gated. (3) solver-mvp/README.md: obsolete — a misplaced Next.js interface README (the app lives in packages/simple-interface-app); nothing in solver-mvp matches it. (4) arks/README.md: partially-stale — hook signatures, access roles and slippage constants confirmed, but the ark classification list is missing ~20 arks, the new ArkWithSwap base invalidates the 'Ark or ArkWithWithdrawalRequest' dichotomy, and the withdrawUsingSwap 'amount encoded in data' bullets no longer match SwapData{router,swapCalldata}. (5) dutch-auction/README.md: partially-stale — structure/lifecycle/kicker/deploy claims confirmed, but decay is Linear/Quadratic (not 'exponential'), the structure tree omits DutchAuctionMath/DecayFunctions and extra tests, and the MIT license claim conflicts with BUSL-1.1 SPDX headers in src.

### earn:pkg-readmes

Classified every top-level packages/* README slot in summer-earn-protocol: 15 substantive READMEs, 1 stub, 2 boilerplate templates, and 32 missing READMEs. The package README surface is therefore partially-stale overall. Major remediation buckets: replace core-contracts Foundry boilerplate, replace summer-earn-rwa-app create-next boilerplate, fix eslint-config's stale @turbo package name, add READMEs for 32 missing packages, and clean up stale license/runtime claims in utility READMEs. Several substantive READMEs already have claim-level stale findings in earlier domain groups.

### mono:bundle-admin

Audited the admin SDK bundle README from summerfi-monorepo against sdk-client admin/access-control interfaces (62 claims). The admin method surface is mostly current: makeAdminSDK, rebalance, arkConfig, ark cap/limit setters, role grants/revokes, and whitelist setters all exist. Stale items: the admin README still says latest v2.1.0 while the bundle package is 2.3.0, and the getFeeRevenueConfig example/parameter list uses chainId even though the current interface requires vaultId.

### mono:bundle-user

Audited the user-facing SDK bundle README from summerfi-monorepo against sdk-client/sdk-common exports and interfaces (95 claims). The document is mostly aligned with the v2.3.0 bundle package and current Armada user APIs, including vault info, deposits, withdrawals, cross-chain deposits, positions, Merkl rewards, aggregated rewards, and intent-swap client methods. One material stale claim remains: the README documents a makeSDKWithSigner factory for intent swaps, but the checked sdk-client public index does not export that symbol.

### mono:misc

Audited miscellaneous summerfi-monorepo README surfaces outside the SDK bundle docs (52 claims). The root README is partially-stale: root commands remain valid, but the structure section refers to old app/package names and misses the current apps/ and sdk/package layout. Misc package README inventory found one stale package heading (@turbo/eslint-config), stale hardhat-utils workspace links, and three TBD stubs in database packages. Generated TypeDoc output was intentionally excluded.
