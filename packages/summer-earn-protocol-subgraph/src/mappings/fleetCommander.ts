import { Address, BigDecimal, BigInt, dataSource } from '@graphprotocol/graph-ts'
import { VaultFee } from '../../generated/schema'
import {
  RewardAdded,
  RewardPaid,
  RewardTokenRemoved,
  RewardsDurationUpdated,
  Staked,
  Unstaked,
} from '../../generated/templates/FleetCommanderRewardsManagerTemplate/FleetCommanderRewardsManager'
import {
  ArkAdded,
  ArkRemoved,
  Deposit as DepositEvent,
  FleetCommander as FleetCommanderContract,
  FleetCommanderDepositCapUpdated,
  FleetCommanderMaxRebalanceOperationsUpdated,
  FleetCommanderRedeemedFromArks,
  FleetCommanderStakingRewardsUpdated,
  FleetCommanderWithdrawnFromArks,
  FleetCommanderminimumBufferBalanceUpdated,
  Rebalanced,
  TipAccrued,
  TipRateUpdated,
  Transfer as TransferEvent,
  Withdraw as WithdrawEvent,
} from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { addresses } from '../common/addressProvider'
import * as constants from '../common/constants'
import { ADDRESS_ZERO, BigIntConstants, VaultFeeType } from '../common/constants'
import {
  getOrCreateAccount,
  getOrCreateArk,
  getOrCreatePosition,
  getOrCreatePositionRewards,
  getOrCreateRewardsManager,
  getOrCreateToken,
  getOrCreateVault,
} from '../common/initializers'
import { getTokenPriceInUSD } from '../common/priceHelpers'
import { getTransferabilityEnabledBlockByChain } from '../common/transferabilityHelper'
import * as utils from '../common/utils'
import { formatAmount } from '../common/utils'
import { getPositionDetails } from '../utils/position'
import { getVaultDetails } from '../utils/vault'
import { createDepositEventEntity } from './entities/deposit'
import { updatePosition } from './entities/position'
import { handleReferrals } from './entities/referral'
import { createStakedEventEntity } from './entities/stake'
import { createUnstakedEventEntity } from './entities/unstake'
import {
  addOrUpdateVaultRewardRates,
  removeVaultRewardRates,
  updateVault,
  updateVaultAndArks,
} from './entities/vault'
import { createWithdrawEventEntity } from './entities/withdraw'

export function handleRebalance(event: Rebalanced): void {
  const vault = getOrCreateVault(event.address, event.block)
  updateVaultAndArks(event, vault)
  vault.rebalanceCount = vault.rebalanceCount.plus(BigIntConstants.ONE)
  vault.save()
}

export function handleArkAdded(event: ArkAdded): void {
  const vault = getOrCreateVault(event.address, event.block)
  const ark = getOrCreateArk(event.params.ark, event.block)
  ark.vault = vault.id
  ark.save()

  const arksArray = vault.arksArray
  if (!arksArray.includes(ark.id)) {
    arksArray.push(ark.id)
    vault.arksArray = arksArray
    vault.save()
  }
}

let _arkAddress: string
export function handleArkRemoved(event: ArkRemoved): void {
  const vault = getOrCreateVault(event.address, event.block)
  _arkAddress = event.params.ark.toHexString()
  let previousArrayOfArks = vault.arksArray
  vault.arksArray = previousArrayOfArks.filter((ark) => ark !== _arkAddress)
  vault.save()
  // remove relation to vault
  const ark = getOrCreateArk(Address.fromString(_arkAddress), event.block)
  ark.vault = ADDRESS_ZERO.toHexString()
  ark.save()
}

export function handleDeposit(event: DepositEvent): void {
  const vault = getOrCreateVault(event.address, event.block)
  const account = getOrCreateAccount(event.params.owner.toHexString())

  const vaultDetails = getVaultDetails(vault, event.block)
  const updatedVault = updateVault(vaultDetails, event.block, false)

  const positionDetails = getPositionDetails(
    updatedVault,
    Address.fromString(account.id),
    vaultDetails,
    event.block,
  )

  const referralData = handleReferrals(event, account, positionDetails, 'handleDeposit')

  updatePosition(positionDetails, event.block, referralData)

  createDepositEventEntity(event, positionDetails, referralData)
}

export function handleWithdraw(event: WithdrawEvent): void {
  const vault = getOrCreateVault(event.address, event.block)

  const vaultDetails = getVaultDetails(vault, event.block)
  const updatedVault = updateVault(vaultDetails, event.block, false)

  const rewardsManager = vaultDetails.rewardsManager

  if (rewardsManager.toHexString() == event.params.owner.toHexString()) {
    // if the owner is the rewards manager, then we skip event creation and position update
    return
  }

  const account = getOrCreateAccount(event.params.owner.toHexString())

  const positionDetails = getPositionDetails(
    updatedVault,
    event.params.owner,
    vaultDetails,
    event.block,
  )
  updatePosition(positionDetails, event.block, account.referralData)

  createWithdrawEventEntity(event, positionDetails, account.referralData)
}

// Track transfers of ERC4626 shares between users (excluding mints/burns and staking contract transfers)
export function handleShareTransfer(event: TransferEvent): void {
  if (
    event.block.number.lt(getTransferabilityEnabledBlockByChain(dataSource.network().toLowerCase()))
  ) {
    return
  }
  // skip mints/burns and zero-value transfers
  if (
    event.params.from.equals(ADDRESS_ZERO) ||
    event.params.to.equals(ADDRESS_ZERO) ||
    event.params.value.equals(constants.BigIntConstants.ZERO)
  ) {
    return
  }

  const vault = getOrCreateVault(event.address, event.block)
  const rewardsManager = vault.stakingRewardsManager

  // skip transfers involving the staking rewards manager
  if (
    rewardsManager &&
    (event.params.from.toHexString() == rewardsManager.toHexString() ||
      event.params.to.toHexString() == rewardsManager.toHexString())
  ) {
    return
  }

  // ensure Account entities exist for FE lookups
  getOrCreateAccount(event.params.from.toHexString())
  getOrCreateAccount(event.params.to.toHexString())

  // Recompute positions using the standard path to keep balances and rewards coherent
  const vaultDetails = getVaultDetails(vault, event.block)
  const updatedVault = updateVault(vaultDetails, event.block, false)

  const fromDetails = getPositionDetails(updatedVault, event.params.from, vaultDetails, event.block)
  updatePosition(fromDetails, event.block, null)
  createWithdrawEventEntity(event, fromDetails, null, true)

  const toDetails = getPositionDetails(updatedVault, event.params.to, vaultDetails, event.block)
  updatePosition(toDetails, event.block, null)
  createDepositEventEntity(event, toDetails, null, true)
}

// withdaraw already handled in handleWithdraw
export function handleFleetCommanderWithdrawnFromArks(
  event: FleetCommanderWithdrawnFromArks,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  updateVaultAndArks(event, vault)
}
export function handleFleetCommanderRedeemedFromArks(event: FleetCommanderRedeemedFromArks): void {
  const vault = getOrCreateVault(event.address, event.block)
  updateVaultAndArks(event, vault)
}

export function handleFleetCommanderMinimumBufferBalanceUpdated(
  event: FleetCommanderminimumBufferBalanceUpdated,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  if (vault) {
    vault.minimumBufferBalance = event.params.newBalance
    vault.save()
  }
}

export function handleFleetCommanderDepositCapUpdated(
  event: FleetCommanderDepositCapUpdated,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  if (vault) {
    vault.depositCap = event.params.newCap
    vault.save()
  }
}

export function handleFleetCommanderStakingRewardsUpdated(
  event: FleetCommanderStakingRewardsUpdated,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  if (vault) {
    vault.stakingRewardsManager = event.params.newStakingRewards
    getOrCreateRewardsManager(event.params.newStakingRewards)
    vault.save()
  }
}

export function handleFleetCommanderMaxRebalanceOperationsUpdated(
  event: FleetCommanderMaxRebalanceOperationsUpdated,
): void {
  const vault = getOrCreateVault(event.address, event.block)
  if (vault) {
    vault.maxRebalanceOperations = event.params.newMaxRebalanceOperations
    vault.save()
  }
}

export function handleStaked(event: Staked): void {
  const rewardsManager = getOrCreateRewardsManager(event.address)
  const vault = getOrCreateVault(Address.fromString(rewardsManager.vault), event.block)
  const account = getOrCreateAccount(event.params.receiver.toHexString())

  const vaultDetails = getVaultDetails(vault, event.block)
  const updatedVault = updateVault(vaultDetails, event.block, false)
  const positionDetails = getPositionDetails(
    updatedVault,
    Address.fromString(account.id),
    vaultDetails,
    event.block,
  )

  const referralData = handleReferrals(event, account, positionDetails, 'handleStaked')

  updatePosition(positionDetails, event.block, referralData)

  createStakedEventEntity(event, positionDetails)
  createDepositEventEntity(event, positionDetails, referralData)
}

export function handleUnstaked(event: Unstaked): void {
  const rewardsManager = getOrCreateRewardsManager(event.address)
  const vault = getOrCreateVault(Address.fromString(rewardsManager.vault), event.block)
  const account = getOrCreateAccount(event.params.staker.toHexString())

  const vaultDetails = getVaultDetails(vault, event.block)
  const updatedVault = updateVault(vaultDetails, event.block, false)
  const positionDetails = getPositionDetails(
    updatedVault,
    Address.fromString(account.id),
    vaultDetails,
    event.block,
  )

  updatePosition(positionDetails, event.block, account.referralData)

  createUnstakedEventEntity(event, positionDetails)
  createWithdrawEventEntity(event, positionDetails, account.referralData)
}

export function handleRewardTokenRemoved(event: RewardTokenRemoved): void {
  const rewardsManager = getOrCreateRewardsManager(event.address)
  const vault = getOrCreateVault(Address.fromString(rewardsManager.vault), event.block)

  removeVaultRewardRates(vault, event.params.rewardToken)
}

export function handleRewardAdded(event: RewardAdded): void {
  const rewardsManager = getOrCreateRewardsManager(event.address)
  const vault = getOrCreateVault(Address.fromString(rewardsManager.vault), event.block)

  addOrUpdateVaultRewardRates(vault, event.address, event.params.rewardToken)

  rewardsManager.save()
}

export function handleRewardsDurationUpdated(event: RewardsDurationUpdated): void {
  const rewardsManager = getOrCreateRewardsManager(event.address)
  const vault = getOrCreateVault(Address.fromString(rewardsManager.vault), event.block)

  addOrUpdateVaultRewardRates(vault, event.address, event.params.rewardToken)

  rewardsManager.save()
}

export function handleTipAccrued(event: TipAccrued): void {
  const vault = getOrCreateVault(event.address, event.block)
  const vaultContract = FleetCommanderContract.bind(event.address)
  const tipRate = vaultContract.tipRate()
  const shares = event.params.tipAmount

  const inputToken = getOrCreateToken(Address.fromString(vault.inputToken))
  const inputTokenAmount = utils.readValue<BigInt>(
    vaultContract.try_convertToAssets(shares),
    constants.BigIntConstants.ZERO,
  )
  const inputTokenAmountNormalized = formatAmount(
    inputTokenAmount,
    BigInt.fromI32(inputToken.decimals),
  )
  const inputTokenPriceUSD = getTokenPriceInUSD(Address.fromString(vault.inputToken), event.block)
  const inputTokenAmountNormalizedInUSD = inputTokenAmountNormalized.times(inputTokenPriceUSD.price)

  const fee = new VaultFee(event.address.toHexString() + '-' + event.block.timestamp.toString())
  fee.feeType = VaultFeeType.MANAGEMENT_FEE
  fee.token = inputToken.id
  fee.feePercentage = BigDecimal.fromString(tipRate.toString())
  fee.outputTokenAmount = event.params.tipAmount
  fee.inputTokenAmount = inputTokenAmount
  fee.inputTokenAmountNormalizedInUSD = inputTokenAmountNormalizedInUSD
  fee.blockNumber = event.block.number
  fee.timestamp = event.block.timestamp
  fee.vault = vault.id
  fee.save()
}

export function handleTipRateUpdated(event: TipRateUpdated): void {
  const vault = getOrCreateVault(event.address, event.block)
  vault.tipRate = event.params.newTipRate
  vault.save()
}

export function handleRewardPaid(event: RewardPaid): void {
  const rewardsManager = getOrCreateRewardsManager(event.address)
  const vault = getOrCreateVault(Address.fromString(rewardsManager.vault), event.block)

  if (vault.rewardTokens.includes(event.params.rewardToken.toHexString())) {
    const account = getOrCreateAccount(event.params.user.toHexString())
    const position = getOrCreatePosition(utils.formatPositionId(account.id, vault.id), event.block)

    const positionRewards = getOrCreatePositionRewards(
      utils.formatPositionId(account.id, vault.id),
      getOrCreateToken(event.params.rewardToken),
      event.block,
    )
    positionRewards.claimed = positionRewards.claimed.plus(event.params.reward)
    positionRewards.claimedNormalized = positionRewards.claimedNormalized.plus(
      formatAmount(
        event.params.reward,
        BigInt.fromI32(getOrCreateToken(Address.fromString(positionRewards.rewardToken)).decimals),
      ),
    )
    positionRewards.save()

    // will be deprecated in the future
    if (event.params.rewardToken.toHexString() == addresses.SUMMER_TOKEN.toHexString()) {
      position.claimedSummerToken = position.claimedSummerToken.plus(event.params.reward)
      position.claimedSummerTokenNormalized = position.claimedSummerTokenNormalized.plus(
        formatAmount(event.params.reward, BigInt.fromI32(18)),
      )

      account.claimedSummerToken = account.claimedSummerToken.plus(event.params.reward)
      account.claimedSummerTokenNormalized = account.claimedSummerTokenNormalized.plus(
        formatAmount(event.params.reward, BigInt.fromI32(18)),
      )
      account.save()
    }
  }
}
