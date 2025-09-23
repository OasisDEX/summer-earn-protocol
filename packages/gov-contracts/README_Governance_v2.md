## Executive Summary for Auditors

This audit covers **new contracts** that extend previously audited functionality. The focus is on:
- **StakedSummerToken.sol** - Governance token with controlled minting
- **SummerGovernorV2.sol** - Governance without voting decay (vs V1 with decay)
- **SummerVestingWalletsEscrow.sol** - MVP staking bridge for vesting wallets
- **SummerStaking.sol** - Advanced staking with lockup periods and weighted rewards

## Key Architectural Changes

### 1. StakedSummerToken.sol - Governance Token Design

**Purpose**: This is the **governance token** (xSUMR) that represents staked SUMMER tokens with voting power.

**Critical Security Features**:
- **Controlled Minting**: Only `MINTER_ROLE` holders can mint
- **Role Management**: Direct `grantRole`/`revokeRole` are **disabled**; only governor can add/remove staking modules or (emergency) grant/revoke minter role
- **Non-transferable**: xSUMR disables user-to-user transfers. Only mint (from address(0)) and burn (to address(0)) are allowed
- **Pausable**: Governor/Guardian can pause, which blocks mint/burn while paused
**Multiple Staking Modules Support**:
- **Before**: Single `stakingModule` address with direct role assignment
- **After**: Multiple staking modules can be added/removed dynamically

**Role Assignment Flow**:
```solidity
addStakingModule() → 
  - Grants MINTER_ROLE to new staking module
  - Grants BURNER_ROLE to new staking module
  - Emits StakingModuleAdded event

removeStakingModule() → 
  - Revokes MINTER_ROLE from staking module
  - Revokes BURNER_ROLE from staking module  
  - Emits StakingModuleRemoved event

// Emergency (governor-only, not part of normal flow)
grantMinterRole(_minter)
revokeMinterRole(_minter)
```

### **Security Implications**

**Enhanced Flexibility**:
- ✅ Multiple staking contracts can mint xSUMR tokens
- ✅ Each staking module has independent minting/burning authority
- ✅ Governor can add/remove staking modules without redeployment

**Risk Considerations**:
- 🔴 **Multiple Minters**: More attack surface - each staking module can mint
- 🔴 **Role Proliferation**: Each added module gets both MINTER and BURNER roles
- 🔴 **Governance Control**: Only governor can add/remove modules

**Authorization Nuances**:
- Burning uses `burnFrom(from, amount)` and enforces standard ERC20 allowances. Having `BURNER_ROLE` does not bypass allowances unless burning own balance. This reduces blast radius of a compromised burner.

**Audit Focus Areas**:
- Role escalation prevention (direct role granting disabled)
- Staking module address validation
- Minting/burning authorization flow (BURNER_ROLE + allowance model)
- Pause semantics impact on mint/burn and governance snapshots

### 2. SummerGovernorV2.sol vs SummerGovernor.sol

**Key Difference**: **V2 removes voting decay functionality**

| Feature | V1 (Audited) | V2 (New) |
|---------|---------------|-----------|
| Voting Decay | ✅ `DecayController` | ❌ Removed |
| `updateDecay` modifier | ✅ Present | ❌ Removed |
| Cross-chain messaging | ✅ LayerZero | ✅ LayerZero |
| Guardian system | ✅ Active | ✅ Active |

**Why This Matters**: V2 simplifies governance by removing time-based voting power decay.

**Hub/Satellite Model**:
- Proposals, votes, execute, cancel: restricted to the hub chain via `onlyHubChain`
- Cross-chain distribution: `sendProposalToTargetChain()` (hub-only) sends to satellites using LayerZero OApp
- Satellite chains queue received proposals via `_queueCrossChainProposal` guarded by `onlySatelliteChain`
- Contract `receive()` accepts ETH only from LayerZero endpoint or the timelock; others revert (`GovernorDisabledDeposit`)

**Thresholds and Guardians**:
- `MIN_PROPOSAL_THRESHOLD = 1,000e18`, `MAX_PROPOSAL_THRESHOLD = 100,000e18` (validated at construction)
- Proposers below threshold can still propose if they are active guardians (`isActiveGuardian` via `accessManager`)

### 3. SummerVestingWalletsEscrow.sol - MVP Staking Bridge

**Purpose**: Temporary staking solution that allows users to stake from vesting wallets.

**Critical Flows**:
```solidity
stakeVesting(address[] factories) →
  - Requires each `factory` is enabled
  - For each factory: resolve `vestingWallets(user)` (initial owner), require nonzero and escrow already owns it
  - Mint xSUMR equal to current SUMR balance in that vesting wallet
  - Track staked amount and the `released(token)` snapshot per factory -> cases where `release()` has been called permisionlessly while staked

unstakeVesting(address[] factories) →
  - For each factory: compute SUMR released while staked and forward to the user (if any)
  - Transfer vesting wallet ownership back to the user
  - Burn recorded xSUMR
  - remove `released` and `balance` tracking for factory/user pair - to enable consequent stakes
```

**Security Considerations**:
- **Ownership Expectations**: Escrow must already own the vesting wallets to stake from them; this contract does not transfer ownership during stake
- **Factory Validation**: Only pre-approved vesting factories allowed
- **Granular Operations**: Users may stake/unstake per-Factory by passing a list of factories

**Audit Focus Areas**:
- Vesting wallet ownership management
- Factory whitelist validation
- Token release calculations during staking

**User/Operator API**:
- `addVestingFactory(address)` / `removeVestingFactory(address)`: governor-only
- `rescueWallet(wallet, newOwner)`: governor-only safety valve
- `rescueToken(token, to)`: governor-only
- Views: `vestingFactories()`, `getVestingFactory(index)`, `userStakedVestingFactories(user)`, `getUserStakedVestingFactory(user, index)`

**Events**:
- `StakedVestingWallet(user, factory, balance, releasedAtStake)`
- `UnstakedVestingWallet(user, factory, balance, releasedAtUnstake)`

### 4. SummerStaking.sol - Advanced Staking with Lockups

**Purpose**: Main staking contract with lockup periods, weighted rewards, and bucket-based caps.

**Key Features**:
- **Lockup Periods**: 0 to 3 years (0 = no lockup via a dedicated aggregated stake at index 0)
- **Weighted Staking**: Longer lockups = higher reward multipliers (quadratic in time)
- **Bucket System**: Configurable caps per lockup duration
- **Penalty System**: Early unstaking incurs time-based penalties (governor can toggle penalties on/off)
- **Stake Portfolio Management**: One portfolio per address; index 0 aggregates no-lockup stake; up to 1000 stakes; full-portfolio transfer supported via `transferStakes(to)` to a fresh target
- **Default Caps**:
  - `NoLockup`: cap = unlimited (by default - can be changed at a later date)
  - `ShortTerm` (1 sec – 14 days): cap = 0 (disabled by default)
  - `TwoWeeksToThreeMonths` (>14 days – 90 days): cap = unlimited (will have an initial cap hardcoded in the contract)
  - `ThreeToSixMonths` (>90 – 180 days): cap = unlimited (will have an initial cap hardcoded in the contract)
  - `SixToTwelveMonths` (>180 – 365 days): cap = unlimited (will have an initial cap hardcoded in the contract)
  - `OneToTwoYears` (>365 – 730 days): cap = unlimited (will have an initial cap hardcoded in the contract)
  - `TwoToThreeYears` (>730 – 1095 days): cap = unlimited


**Critical Calculations**:
```ts
// Weighted stake formula (UD60x18 fixed-point; time in seconds)
// WEIGHTED_STAKE_BASE = 1.0
// WEIGHTED_STAKE_COEFFICIENT = 7e-16
weightedAmount = amount * (1 + 7e-16 * time^2)

// Penalty calculation  
// If penalties disabled → 0
// If lockup expired → 0
// If timeRemaining < 110 days → 2% flat (according to the `formula` the fee is 2% at 9460800 seconds - 109.5days - but it was rounded up)
// Else → 20% * (timeRemaining / 3 years)
penaltyPct = remainingLockup < 110 days ? 2% : 20% * (remainingLockupTime / 3 years);
penaltyAmount = penaltyPct * amount;
```

<img width="2208" height="1370" alt="image" src="https://github.com/user-attachments/assets/9d52f110-42a5-405d-9555-99458c5bcedb" />


**Rewards Accounting**:
- The `totalSupply` used for rewards is actually the weighted total supply. Because the base rewards manager requires `rewardPerToken()` to use `totalSupply`, this staking contract accounts `totalSupply` as the sum of weighted amounts to ensure correct reward distribution.

**Token Flows**:
- On stake: transfer SUMR → contract, approve and deposit into `WrappedStakingToken`, mint xSUMR 1:1 to receiver
- On unstake: burn xSUMR, withdraw wrapped SUMR; if a penalty applies, send penalty to `treasury()` and remainder to user

**Security Model**:
- **Bucket Caps**: Governor-controlled limits per lockup duration
- **Penalty Enforcement**: Penalties sent to treasury, not burned
- **Wrapped Token Integration**: Uses `WrappedStakingToken` for internal accounting

**Audit Focus Areas**:
- Weighted stake calculation precision
- Bucket cap enforcement
- Penalty calculation accuracy
- Wrapped token integration security

**User/Operator API**:
- Stake: `stakeLockup(amount, lockupPeriod)`; `stakeLockupOnBehalf(receiver, amount, lockupPeriod)`
- Unstake: `unstakeLockup(stakeIndex, amount)`
- Transfer portfolio: `transferStakes(to)` (to must have no stakes, no xSUMR, and no reward markers)
- Admin: `updateLockupBucketCap(bucket, newCap)`, `updatePenaltyEnabled(bool)`, `rescueToken(token, to)`
- Views: `getUserStakesCount(user)`, `getUserStake(user, index)`, `weightedBalanceOf(user)`, bucket getters
- Disabled (reverts): `stake()`, `unstake()`, `exit()`, `stakeOnBehalfOf()`, `unstakeAndWithdrawOnBehalfOf()`

## Integration Points & Dependencies

### Staking Flow
```
User → SummerStaking.stakeLockup() → 
  - Transfers SUMMER tokens
  - Wraps via WrappedStakingToken
  - Mints xSUMR via StakedSummerToken.mint()
  - Updates weighted balances for rewards
```

### Governance Flow
```
xSUMR holders → SummerGovernorV2.propose() → 
  - Cross-chain proposal distribution
  - Timelock execution
  - No voting decay (unlike V1)
  - Propose/vote/execute/cancel only on hub chain
```

### Vesting Integration
```
Vesting Wallets → SummerVestingWalletsEscrow → 
  - Vesting wallet ownership must be transferred to escrow prior to staking
  - xSUMR minting/burning
  - Release tracking during staking
  - Per-factory granular stake/unstake with validation
```

## Critical Security Considerations

1. **Role Management**: StakedSummerToken disables direct role granting - only governor can manage
2. **Staking Module Control**: The staking module has both minting and burning authority
3. **Vesting Wallet Ownership**: Escrow takes temporary ownership - ensure proper return
4. **Weighted Calculations**: `weightedAmount = amount * (1 + 7e-16 * t^2)` and penalties include a fixed 2% floor near expiry; verify precision and edge cases
5. **Bucket Caps**: Governor-controlled limits that could affect staking economics; ShortTerm bucket disabled by default
6. **Cross-chain Governance**: V2 maintains LayerZero integration; enforce hub/satellite constraints
7. **Pause Behavior**: Pausing xSUMR halts mint/burn; consider operational runbooks

## Previous Audit Coverage

**Already Audited**:
- `StakingRewardsManagerBase.sol` - Base reward distribution logic
- `SummerGovernor.sol` - V1 with voting decay

**New Audit Scope**:
- Role management changes in StakedSummerToken
- Removal of voting decay in V2
- Vesting wallet escrow mechanics
- Advanced staking with lockups and penalties

The contracts build upon proven patterns but introduce new complexity around lockup periods, weighted rewards, and vesting wallet management that requires careful review.

---

## Appendix: Quick API Reference (for implementers and auditors)

### StakedSummerToken (xSUMR)
- Transfers: disabled (only mint/burn allowed)
- Roles: `MINTER_ROLE`, `BURNER_ROLE`
- Governance: `addStakingModule(address)`, `removeStakingModule(address)`, `pause()`, `unpause()`
- Emergency: `grantMinterRole(address)`, `revokeMinterRole(address)` (direct `grantRole`/`revokeRole` are disabled and revert)
- Mint/Burn: `mint(to, amount)` (minter only), `burn(amount)`, `burnFrom(from, amount)` (owner or burner + allowance)

### SummerStaking
- Stake: `stakeLockup(amount, lockupPeriod)`; `stakeLockupOnBehalf(receiver, amount, lockupPeriod)`
- Unstake: `unstakeLockup(stakeIndex, amount)`
- Transfer: `transferStakes(to)` (strict preconditions)
- Admin: `updateLockupBucketCap(bucket, cap)`, `updatePenaltyEnabled(bool)`, `rescueToken(token, to)`
- Views: stake getters, bucket getters, `weightedBalanceOf(user)`
- Disabled: `stake()`, `unstake()`, `exit()`, `stakeOnBehalfOf()`, `unstakeAndWithdrawOnBehalfOf()`

### SummerVestingWalletsEscrow
- Configure factories (gov): `addVestingFactory(address)`, `removeVestingFactory(address)`
- User flows: `stakeVesting(address[] factories)`, `unstakeVesting(address[] factories)`
- Safety: `rescueWallet(wallet, newOwner)`, `rescueToken(token, to)` (gov)
- Views: `vestingFactories()`, `getVestingFactory(i)`, `userStakedVestingFactories(user)`, `getUserStakedVestingFactory(user, i)`

### SummerGovernorV2
- Hub-only: `propose(...)`, `castVote(proposalId, support)`, `execute(...)`, `cancel(...)`, `sendProposalToTargetChain(...)`
- Satellite: queue via cross-chain receive
- Params: voting delay/period, quorum fraction, proposal threshold validated within `[1,000; 100,000] SUMR`