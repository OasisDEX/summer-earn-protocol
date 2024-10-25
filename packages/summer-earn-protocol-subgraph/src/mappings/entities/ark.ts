import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import { Ark as ArkContract } from '../../../generated/HarborCommand/Ark'
import { Ark } from '../../../generated/schema'
import { BigDecimalConstants } from '../../common/constants'
import { getOrCreateArk } from '../../common/initializers'
import { getAprForTimePeriod } from '../../common/utils'
import { ArkDetails } from '../../types'

export function updateArk(arkDetails: ArkDetails, block: ethereum.Block): void {
  const arkAddress = Address.fromString(arkDetails.arkId)
  const vaultAddress = Address.fromString(arkDetails.vaultId)
  const ark = getOrCreateArk(vaultAddress, arkAddress, block)

  const arkContract = ArkContract.bind(arkAddress)
  const currentTotalAssets = arkContract.totalAssets()

  // Calculate earnings since last update
  const timeDiff = block.timestamp.minus(ark.lastUpdateTimestamp)
  const assetDiff = currentTotalAssets.minus(ark.inputTokenBalance)

  // Adjust for known deposits and withdrawals
  const netDeposits = ark.cumulativeDeposits.minus(ark.cumulativeWithdrawals)
  const earnings = assetDiff.minus(netDeposits)

  // Update cumulative earnings
  ark.cumulativeEarnings = ark.cumulativeEarnings.plus(earnings)

  // Calculate annualized APR based on earnings
  if (timeDiff.gt(BigInt.fromI32(0)) && ark.inputTokenBalance.gt(BigInt.fromI32(0))) {
    ark.calculatedApr = getAprForTimePeriod(
      ark.inputTokenBalance.toBigDecimal(),
      ark.inputTokenBalance.plus(earnings).toBigDecimal(),
      timeDiff.toBigDecimal(),
    )
    log.error('ark.inputTokenBalance: {}, earnings: {}, timeDiff: {} calculatedApr: {}', [
      ark.inputTokenBalance.toString(),
      earnings.toString(),
      timeDiff.toString(),
      ark.calculatedApr.toString(),
    ])
  } else if (ark.inputTokenBalance.gt(BigInt.fromI32(0))) {
    ark.calculatedApr = ark.calculatedApr
  } else {
    ark.calculatedApr = BigDecimalConstants.ZERO
  }

  // Update other fields
  ark.inputTokenBalance = currentTotalAssets
  ark.totalValueLockedUSD = arkDetails.totalValueLockedUSD
  ark.lastUpdateTimestamp = block.timestamp

  // Reset cumulative deposits and withdrawals
  ark.cumulativeDeposits = BigInt.fromI32(0)
  ark.cumulativeWithdrawals = BigInt.fromI32(0)

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
  ark.cumulativeDeposits = ark.cumulativeDeposits.plus(amount)
  ark.save()
}

export function handleDisembark(amount: BigInt, ark: Ark): void {
  ark.cumulativeWithdrawals = ark.cumulativeWithdrawals.plus(amount)
  ark.save()
  log.error('Disembarked TOTAL {}, amount: {}', [ark.name!, ark.cumulativeWithdrawals.toString()])
}

export function handleMove(amount: BigInt, ark: Ark): void {
  ark.cumulativeWithdrawals = ark.cumulativeWithdrawals.plus(amount)
  ark.save()
}
