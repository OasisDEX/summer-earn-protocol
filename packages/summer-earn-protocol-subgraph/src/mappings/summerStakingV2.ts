import {
  StakedWithLockup,
  UnstakedWithPenalty,
} from '../../generated/SummerStakingV2/SummerStakingV2'
import { BigDecimalConstants, BigIntConstants } from '../common/constants'

import { Address, BigInt, log, store } from '@graphprotocol/graph-ts'
import {
  getOrCreateAccount,
  getOrCreateGovernanceStakingV2,
  getOrCreateStakeLockup,
} from '../common/initializers'
import { formatAmount } from '../common/utils'
import { Account, StakeLockup } from '../../generated/schema'
import { addresses } from '../common/addressProvider'

/**
 * Mapping overview
 *
 * The on‑chain contract (`SummerStaking.sol`) keeps, per user, an array of `UserStake`
 * structs (`stakesByOwner[owner]`). Index semantics:
 *  - Index 0 (`NO_LOCKUP_INDEX`) aggregates ALL no‑lockup stake.
 *  - Indices > 0 each represent a single lockup position.
 *
 * On full exit of a locked stake (index > 0), the contract uses "swap‑and‑pop":
 *  - `_stakes[_index] = _stakes[_stakes.length - 1];`
 *  - `_stakes.pop();`
 *
 * This file mirrors that behavior in the subgraph by:
 *  - Using a deterministic `StakeLockup.id` of
 *      `{stakingAddress}-{receiver}-{stakeIndex}`
 *  - Tracking `StakeLockup.index` (the logical user‑visible index)
 *  - On full exit of a locked stake, either:
 *      * Just remove the last index (pop), or
 *      * Move the "last" stake entity into the emptied index and delete the old one,
 *        exactly like the contract does.
 *
 * All aggregate metrics on `GovernanceStaking` (`summerStaked`, `averageLockupPeriod`,
 * `weightedAverageLockupPeriod`, `amountOfLockedStakes`) are updated using the same
 * formulas as the contract and always in terms of the *logical* indices, not the
 * underlying entity IDs.
 */

/**
 * Handles a `StakedWithLockup` event.
 *
 * Responsibilities:
 *  - Create / update the per‑user `StakeLockup` entity for this (stakingAddress, user, index).
 *  - Mirror the contract’s rule that index 0 aggregates all no‑lockup stakes, while
 *    indices > 0 are independent positions that overwrite any previous value.
 *  - Update the global `GovernanceStaking` aggregates to match the contract’s
 *    average and weighted‑average lockup period formulas.
 */
export function handleStaked(event: StakedWithLockup): void {
  const processedStakeId = _getStakeLockupId(
    event.address,
    event.params.receiver,
    event.params.stakeIndex,
  )
  const processedStake = getOrCreateStakeLockup(processedStakeId)
  const isNoLockupStake = _isNoLockupStake(event.params.stakeIndex)
  const lockupPeriod = event.params.lockupPeriod
  const account = getOrCreateAccount(event.params.receiver.toHexString())

  if (!isNoLockupStake) {
    if (event.address != addresses.STAKING_V2_PROD) {
      if (account.lastLockupIndex) {
        account.lastLockupIndex = account.lastLockupIndex!.plus(BigIntConstants.ONE)
      } else {
        account.lastLockupIndex = BigIntConstants.ONE
      }
    } else {
      if (account.lastLockupIndexProd) {
        account.lastLockupIndexProd = account.lastLockupIndexProd!.plus(BigIntConstants.ONE)
      } else {
        account.lastLockupIndexProd = BigIntConstants.ONE
      }
    }
    account.save()
    _ensureNoLockupStake(account, event)
  }

  _processStakeLockupOnStake(account, processedStake, event)
  _processGovernanceStakingOnStake(event, isNoLockupStake, lockupPeriod)
}

/**
 * Handles an `UnstakedWithPenalty` event.
 *
 * Responsibilities:
 *  - Update the `StakeLockup` for this (stakingAddress, user, index) by subtracting
 *    the raw and weighted amounts (pro‑rata, same as the contract).
 *  - If the stake was fully emptied AND it is not the no‑lockup index, mirror the
 *    contract’s `_removeStake` swap‑and‑pop behavior in `_removeStake`.
 *  - Update the global `GovernanceStaking` aggregates, including the average and
 *    weighted‑average lockup periods, using the same formulas as the contract.
 */
export function handleUnstaked(event: UnstakedWithPenalty): void {
  const processedStakeId = _getStakeLockupId(
    event.address,
    event.params.receiver,
    event.params.stakeIndex,
  )
  const processedStake = getOrCreateStakeLockup(processedStakeId)
  const isNoLockupStake = _isNoLockupStake(event.params.stakeIndex)
  const lockupPeriod = processedStake.lockupPeriod

  const wasStakeEmptied = _processStakeLockupOnUnstake(processedStake, event)

  if (wasStakeEmptied && !isNoLockupStake) {
    _removeStake(event, processedStakeId)
  }

  _processGovernanceStakingOnUnstake(event, isNoLockupStake, lockupPeriod, wasStakeEmptied)
}

/**
 * Build a stable ID for a `StakeLockup` entity.
 *
 * We key by:
 *  - staking contract address (to support multiple `SummerStaking` instances),
 *  - receiver address,
 *  - and current stake index (the same index used by the Solidity contract).
 *
 * This ensures:
 *  - Unambiguous identification of a stake in the subgraph.
 *  - Correct mirroring of the contract’s `stakesByOwner[owner][index]` layout.
 */
function _getStakeLockupId(stakingAddress: Address, receiver: Address, stakeIndex: BigInt): string {
  return (
    stakingAddress.toHexString() + '-' + receiver.toHexString() + '-' + stakeIndex.toHexString()
  )
}

function _isNoLockupStake(stakeIndex: BigInt): boolean {
  return stakeIndex.equals(BigIntConstants.ZERO)
}

function _isStakeEmpty(stake: StakeLockup): boolean {
  return stake.amount.equals(BigIntConstants.ZERO)
}

/**
 * Create or update the per‑user `StakeLockup` state on stake.
 *
 * Mirrors `_stakeLockup` in the contract:
 *  - For no‑lockup (`index == 0`), we *aggregate* into a single `StakeLockup` by
 *    adding raw and weighted amounts on each stake.
 *  - For lockup positions (`index > 0`), we treat each index as a standalone stake
 *    and overwrite the amounts with the latest event (same as contract appending/
 *    overwriting the array entry).
 */
function _processStakeLockupOnStake(
  account: Account,
  processedStake: StakeLockup,
  event: StakedWithLockup,
): void {
  processedStake.index = event.params.stakeIndex
  processedStake.account = account.id
  processedStake.lockupPeriod = event.params.lockupPeriod
  processedStake.startTimestamp = event.block.timestamp
  processedStake.endTimestamp = event.block.timestamp.plus(event.params.lockupPeriod)

  if (_isNoLockupStake(event.params.stakeIndex)) {
    processedStake.amount = processedStake.amount.plus(event.params.amount)
    processedStake.amountNormalized = processedStake.amountNormalized.plus(
      formatAmount(event.params.amount, BigInt.fromI32(18)),
    )
    processedStake.weightedAmount = processedStake.weightedAmount.plus(event.params.weightedAmount)
    processedStake.weightedAmountNormalized = processedStake.weightedAmountNormalized.plus(
      formatAmount(event.params.weightedAmount, BigInt.fromI32(18)),
    )
  } else {
    processedStake.amount = event.params.amount
    processedStake.amountNormalized = formatAmount(event.params.amount, BigInt.fromI32(18))
    processedStake.weightedAmount = event.params.weightedAmount
    processedStake.weightedAmountNormalized = formatAmount(
      event.params.weightedAmount,
      BigInt.fromI32(18),
    )
  }
  processedStake.save()
}

/**
 * Update the `StakeLockup` balances on unstake.
 *
 * Mirrors the contract’s proportional removal logic:
 *    weightedAmountToRemove = processedStake.weightedAmount * unstakedAmount / amount
 *
 * After the subtraction, `processedStake.amount` may hit zero, in which case we
 * return `true` so the caller can mirror `_removeStake` swap‑and‑pop for
 * lockup positions.
 */
function _processStakeLockupOnUnstake(
  processedStake: StakeLockup,
  event: UnstakedWithPenalty,
): boolean {
  const weightedAmountToRemove = processedStake.weightedAmount
    .times(event.params.unstakedAmount)
    .div(processedStake.amount)

  processedStake.amount = processedStake.amount.minus(event.params.unstakedAmount)
  processedStake.amountNormalized = processedStake.amountNormalized.minus(
    formatAmount(event.params.unstakedAmount, BigInt.fromI32(18)),
  )
  processedStake.weightedAmount = processedStake.weightedAmount.minus(weightedAmountToRemove)
  processedStake.weightedAmountNormalized = processedStake.weightedAmountNormalized.minus(
    formatAmount(weightedAmountToRemove, BigInt.fromI32(18)),
  )
  processedStake.save()

  return _isStakeEmpty(processedStake)
}

/**
 * Update `GovernanceStaking` aggregates on stake.
 *
 *  - `averageLockupPeriod` is a simple running average over the count of *locked*
 *    stakes (index > 0).
 *  - `weightedAverageLockupPeriod` is weighted by total SUMR staked into lockups.
 *  - `amountOfLockedStakes` increments only for lockup positions, not for index 0.
 */
function _processGovernanceStakingOnStake(
  event: StakedWithLockup,
  isNoLockupStake: boolean,
  lockupPeriod: BigInt,
): void {
  const governanceStaking = getOrCreateGovernanceStakingV2(event.address)
  if (!isNoLockupStake) {
    governanceStaking.averageLockupPeriod = governanceStaking
      .averageLockupPeriod!.times(governanceStaking.amountOfLockedStakes!)
      .plus(lockupPeriod)
      .div(governanceStaking.amountOfLockedStakes!.plus(BigIntConstants.ONE))

    governanceStaking.weightedAverageLockupPeriod = governanceStaking.summerStaked
      .times(governanceStaking.weightedAverageLockupPeriod!)
      .plus(event.params.amount.times(lockupPeriod))
      .div(governanceStaking.summerStaked.plus(event.params.amount))

    governanceStaking.amountOfLockedStakes = governanceStaking.amountOfLockedStakes!.plus(
      BigIntConstants.ONE,
    )
  }
  governanceStaking.summerStaked = governanceStaking.summerStaked.plus(event.params.amount)
  governanceStaking.summerStakedNormalized = governanceStaking.summerStakedNormalized.plus(
    formatAmount(event.params.amount, BigInt.fromI32(18)),
  )

  governanceStaking.save()
}

/**
 * Update `GovernanceStaking` aggregates on unstake.
 *
 * Mirrors the Solidity math for:
 *  - Decreasing `weightedAverageLockupPeriod` by subtracting the contribution of
 *    the unstaked amount at the given `lockupPeriod`.
 *  - When a locked position is fully exited (`wasStakeEmptied == true`), updating
 *    `averageLockupPeriod` by removing that lockup from the running average and
 *    decrementing `amountOfLockedStakes`.
 *
 * Note: this operates purely on aggregates; the actual index layout changes are
 * handled separately in `_removeStake`, just like `_removeStake` in the
 * contract is independent of the aggregate math.
 */
function _processGovernanceStakingOnUnstake(
  event: UnstakedWithPenalty,
  isNoLockupStake: boolean,
  lockupPeriod: BigInt,
  wasStakeEmptied: boolean,
): void {
  const governanceStaking = getOrCreateGovernanceStakingV2(event.address)
  if (!isNoLockupStake) {
    governanceStaking.weightedAverageLockupPeriod = governanceStaking
      .weightedAverageLockupPeriod!.times(governanceStaking.summerStaked)
      .minus(event.params.unstakedAmount.times(lockupPeriod))
      .div(governanceStaking.summerStaked.minus(event.params.unstakedAmount))
    if (wasStakeEmptied) {
      governanceStaking.averageLockupPeriod = governanceStaking
        .amountOfLockedStakes!.times(governanceStaking.averageLockupPeriod!)
        .minus(lockupPeriod)
        .div(governanceStaking.amountOfLockedStakes!.minus(BigIntConstants.ONE))
      governanceStaking.amountOfLockedStakes = governanceStaking.amountOfLockedStakes!.minus(
        BigIntConstants.ONE,
      )
    }
  }
  governanceStaking.summerStaked = governanceStaking.summerStaked.minus(event.params.unstakedAmount)
  governanceStaking.summerStakedNormalized = governanceStaking.summerStakedNormalized.minus(
    formatAmount(event.params.unstakedAmount, BigInt.fromI32(18)),
  )
  governanceStaking.save()
}

/**
 * Mirror the contract’s `_removeStake` swap‑and‑pop behavior in the subgraph.
 *
 * Contract behavior (`SummerStaking.sol`):
 *
 *    if (processedStake.amount == 0 && !_isNoLockupStakeIndex(_stakeIndex)) {
 *        _removeStake(stakes, _stakeIndex);
 *    }
 *
 * where:
 *
 *    function _removeStake(UserStake[] storage _stakes, uint256 _index) internal {
 *        _stakes[_index] = _stakes[_stakes.length - 1];
 *        _stakes.pop();
 *    }
 *
 * We mirror this as follows:
 *  - If the emptied index is already the last index, we simply `store.remove`
 *    that `StakeLockup` (pop semantics).
 *  - Otherwise, we:
 *      1. Load the `StakeLockup` at the last index.
 *      2. Remove the emptied stake entity (`processedStakeId`).
 *      3. Reuse its ID and index for the last stake (swap).
 *      4. Delete the old "last" entity under its previous ID (pop).
 *
 * This keeps:
 *  - The logical indices (`StakeLockup.index`) in sync with `stakesByOwner`.
 *  - The number of `StakeLockup` entities equal to the number of lockup positions.
 */
function _removeStake(event: UnstakedWithPenalty, processedStakeId: string): void {
  const account = getOrCreateAccount(event.params.receiver.toHexString())
  // Load the current number of `StakeLockup` entities for this account; this
  // includes both index 0 and all lockup indices > 0.

  let lastStakeIndex: BigInt | null = null

  if (event.address != addresses.STAKING_V2_PROD) {
    lastStakeIndex = account.lastLockupIndex
    account.lastLockupIndex = lastStakeIndex!.minus(BigIntConstants.ONE)
    account.save()
  } else {
    lastStakeIndex = account.lastLockupIndexProd
    account.lastLockupIndexProd = lastStakeIndex!.minus(BigIntConstants.ONE)
    account.save()
  }
  // Case 1: emptied stake was already the last index → just pop/remove it.
  if (event.params.stakeIndex.equals(lastStakeIndex!)) {
    store.remove('StakeLockup', processedStakeId)
    return
  }

  const lastStakeLockupId = _getStakeLockupId(event.address, event.params.receiver, lastStakeIndex!)
  const maybeLastStakeLockup = StakeLockup.load(lastStakeLockupId)
  if (!maybeLastStakeLockup) {
    log.error('Last stake lockup not found: {}', [lastStakeLockupId])
    return
  }
  const lastStakeLockup = maybeLastStakeLockup

  store.remove('StakeLockup', processedStakeId)
  lastStakeLockup.index = event.params.stakeIndex
  lastStakeLockup.id = processedStakeId
  lastStakeLockup.save()
  if (lastStakeLockupId != lastStakeLockup.id) {
    // Delete the old "last index" entity; after this, the moved stake only
    // exists under the new ID/index, exactly like `_stakes.pop()` in Solidity.
    store.remove('StakeLockup', lastStakeLockupId)
  }
}

function _ensureNoLockupStake(account: Account, event: StakedWithLockup): void {
  const amountOfStakes = account.stakeLockups.load().length
  if (amountOfStakes == 0) {
    const noLockupStake = getOrCreateStakeLockup(
      _getStakeLockupId(event.address, event.params.receiver, BigIntConstants.ZERO),
    )
    noLockupStake.index = BigIntConstants.ZERO
    noLockupStake.account = account.id
    noLockupStake.lockupPeriod = BigIntConstants.ZERO
    noLockupStake.startTimestamp = event.block.timestamp
    noLockupStake.endTimestamp = event.block.timestamp
    noLockupStake.amount = BigIntConstants.ZERO
    noLockupStake.amountNormalized = BigDecimalConstants.ZERO
    noLockupStake.weightedAmount = BigIntConstants.ZERO
    noLockupStake.weightedAmountNormalized = BigDecimalConstants.ZERO
    noLockupStake.save()
  }
}
