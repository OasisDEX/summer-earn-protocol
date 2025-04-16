import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { Ark as ArkContract } from '../../../generated/HarborCommand/Ark'
import { Ark } from '../../../generated/schema'
import { BigDecimalConstants, BigIntConstants } from '../../common/constants'
import { getOrCreateArk, getOrCreateVault } from '../../common/initializers'
import { getAprForTimePeriod } from '../../common/utils'
import { ArkDetails } from '../../types'

export function updateArk(
  arkDetails: ArkDetails,
  block: ethereum.Block,
  shouldUpdateApr: boolean,
): void {
  const arkAddress = Address.fromString(arkDetails.arkId)
  const vault = getOrCreateVault(Address.fromString(arkDetails.vaultId), block)
  const ark = getOrCreateArk(vault, arkAddress, block)

  const arkContract = ArkContract.bind(arkAddress)
  const currentTotalAssets = arkContract.totalAssets()

  if (shouldUpdateApr) {
    // Calculate earnings since last update
    const timeDiff = block.timestamp.minus(ark.lastUpdateTimestamp)
    const assetDiff = currentTotalAssets.minus(ark._lastUpdateInputTokenBalance)

    // Adjust for known deposits and withdrawals
    const netDeposits = ark._cumulativeDeposits.minus(ark._cumulativeWithdrawals)
    const earnings = assetDiff.minus(netDeposits)
    // Update cumulative earnings
    ark.cumulativeEarnings = ark.cumulativeEarnings.plus(earnings)
    // Calculate annualized APR based on earnings
    if (
      timeDiff.gt(BigIntConstants.ZERO) &&
      ark.inputTokenBalance.gt(BigIntConstants.ZERO) &&
      ark._lastUpdateInputTokenBalance.gt(BigIntConstants.ZERO)
    ) {
      ark.calculatedApr = getAprForTimePeriod(
        ark._lastUpdateInputTokenBalance.toBigDecimal(),
        ark._lastUpdateInputTokenBalance.plus(earnings).toBigDecimal(),
        timeDiff.toBigDecimal(),
      )
    } else if (ark.inputTokenBalance.gt(BigInt.fromI32(0))) {
      ark.calculatedApr = ark.calculatedApr
    } else {
      ark.calculatedApr = BigDecimalConstants.ZERO
    }

    // Reset cumulative deposits and withdrawals
    ark._cumulativeDeposits = BigIntConstants.ZERO
    ark._cumulativeWithdrawals = BigIntConstants.ZERO
    ark._lastUpdateInputTokenBalance = currentTotalAssets
  }
  // Update other fields
  ark.inputTokenBalance = currentTotalAssets
  ark.totalValueLockedUSD = arkDetails.totalValueLockedUSD
  ark.lastUpdateTimestamp = block.timestamp

  ark.save()
}

// Explanation:
// The following functions (handleDeposit and handleWithdrawal) are used to track
// cumulative deposits and withdrawals between Ark updates. These amounts are
// temporarily stored in the Ark entity and are used in the updateArk function
// to accurately calculate earnings.
//
// It's important to note that these functions only update the cumulative amounts
// in the Ark entity. The actual processing of deposits, withdrawals, and rebalances
// is handled separately in the Fleet entity when a rebalance event occurs.
//
// The Fleet entity is responsible for managing the overall state across multiple Arks,
// including handling rebalances between Arks. When a rebalance event is processed,
// it will use the information from individual Arks (including these cumulative amounts)
// to update the global state and distribute earnings appropriately.

export function handleBoard(amount: BigInt, ark: Ark): void {
  ark._cumulativeDeposits = ark._cumulativeDeposits.plus(amount)
  ark.save()
}

export function handleDisembark(amount: BigInt, ark: Ark): void {
  ark._cumulativeWithdrawals = ark._cumulativeWithdrawals.plus(amount)
  ark.save()
}

export function handleMove(amount: BigInt, ark: Ark): void {
  ark._cumulativeWithdrawals = ark._cumulativeWithdrawals.plus(amount)
  ark.save()
}
