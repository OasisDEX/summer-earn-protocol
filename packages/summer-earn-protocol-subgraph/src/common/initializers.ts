import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import { ERC20 as ERC20Contract } from '../../generated/HarborCommand/ERC20'
import {
  Account,
  Ark,
  ArkDailySnapshot,
  ArkHourlySnapshot,
  DailyInterestRate,
  FinancialsDailySnapshot,
  HourlyInterestRate,
  Position,
  PositionDailySnapshot,
  PositionHourlySnapshot,
  PositionWeeklySnapshot,
  PostActionArkSnapshot,
  PostActionVaultSnapshot,
  RewardToken,
  RewardsManager,
  Token,
  UsageMetricsDailySnapshot,
  UsageMetricsHourlySnapshot,
  VaultDailySnapshot,
  VaultFee,
  VaultHourlySnapshot,
  Vault as VaultStore,
  VaultWeeklySnapshot,
  WeeklyInterestRate,
  YieldAggregator,
} from '../../generated/schema'
import {
  ArkTemplate,
  FleetCommanderRewardsManagerTemplate,
  FleetCommanderTemplate,
} from '../../generated/templates'
import { FleetCommanderRewardsManager as FleetCommanderRewardsManagerContract } from '../../generated/templates/FleetCommanderRewardsManagerTemplate/FleetCommanderRewardsManager'
import { Ark as ArkContract } from '../../generated/templates/FleetCommanderTemplate/Ark'
import { FleetCommander as FleetCommanderContract } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { updateVaultAPRs } from '../mappings/entities/vault'
import {
  getDailyTimestamp,
  getDailyVaultRateIdAndTimestamp,
  getHourlyOffsetTimestamp,
  getHourlyTimestamp,
  getHourlyVaultRateIdAndTimestamp,
  getWeeklyOffsetTimestamp,
  getWeeklyVaultRateIdAndTimestamp,
} from '../utils/vaultRateHandlers'
import { addresses } from './addressProvider'
import * as constants from './constants'
import { BigIntConstants, RewardTokenType } from './constants'
import * as utils from './utils'
getWeeklyVaultRateIdAndTimestamp

export function getOrCreateAccount(id: string): Account {
  let account = Account.load(id)

  if (!account) {
    account = new Account(id)
    account.save()

    const protocol = getOrCreateYieldAggregator(BigInt.fromI32(0))
    protocol.cumulativeUniqueUsers += 1
    protocol.save()
  }

  return account
}

export function getOrCreateRewardsManager(rewardsManagerAddress: Address): RewardsManager {
  let rewardsManager = RewardsManager.load(rewardsManagerAddress.toHexString())
  if (!rewardsManager) {
    rewardsManager = new RewardsManager(rewardsManagerAddress.toHexString())
    const rewardsManagerContract = FleetCommanderRewardsManagerContract.bind(rewardsManagerAddress)
    const vaultAddress = rewardsManagerContract.fleetCommander()
    rewardsManager.vault = vaultAddress.toHexString()
    rewardsManager.save()
  }
  return rewardsManager
}

export function getOrCreateRewardToken(rewardTokenAddress: Address): RewardToken {
  let rewardToken = RewardToken.load(rewardTokenAddress.toHexString())
  if (!rewardToken) {
    rewardToken = new RewardToken(rewardTokenAddress.toHexString())
    const token = getOrCreateToken(rewardTokenAddress)
    rewardToken.token = token.id
    rewardToken.type = RewardTokenType.DEPOSIT
    rewardToken.save()
  }
  return rewardToken
}

export function getOrCreatePosition(positionId: string, block: ethereum.Block): Position {
  let position = Position.load(positionId)
  const positionIdDetails = utils.getAccountIdAndVaultIdFromPositionId(positionId)
  if (!position) {
    position = new Position(positionId)
    position.inputTokenBalance = constants.BigIntConstants.ZERO
    position.stakedInputTokenBalance = constants.BigIntConstants.ZERO
    position.outputTokenBalance = constants.BigIntConstants.ZERO
    position.stakedOutputTokenBalance = constants.BigIntConstants.ZERO
    position.inputTokenBalanceNormalized = constants.BigDecimalConstants.ZERO
    position.stakedInputTokenBalanceNormalized = constants.BigDecimalConstants.ZERO
    position.inputTokenBalanceNormalizedInUSD = constants.BigDecimalConstants.ZERO
    position.stakedInputTokenBalanceNormalizedInUSD = constants.BigDecimalConstants.ZERO
    position.unstakedInputTokenBalance = constants.BigIntConstants.ZERO
    position.unstakedOutputTokenBalance = constants.BigIntConstants.ZERO
    position.unstakedInputTokenBalanceNormalized = constants.BigDecimalConstants.ZERO
    position.unstakedInputTokenBalanceNormalizedInUSD = constants.BigDecimalConstants.ZERO
    position.account = positionIdDetails[0]
    position.vault = positionIdDetails[1]
    position.createdBlockNumber = block.number
    position.createdTimestamp = block.timestamp
    position.inputTokenDeposits = constants.BigIntConstants.ZERO
    position.inputTokenWithdrawals = constants.BigIntConstants.ZERO
    position.inputTokenDepositsNormalizedInUSD = constants.BigDecimalConstants.ZERO
    position.inputTokenWithdrawalsNormalizedInUSD = constants.BigDecimalConstants.ZERO
    position.save()
  }

  return position
}

export function getOrCreateYieldAggregator(timestamp: BigInt): YieldAggregator {
  let protocol = YieldAggregator.load(constants.PROTOCOL_ID)
  log.debug('getOrCreateYieldAggregator', [])
  if (!protocol) {
    log.debug('Creating new protocol', [])
    protocol = new YieldAggregator(constants.PROTOCOL_ID)
    protocol.name = constants.Protocol.NAME
    protocol.slug = constants.Protocol.SLUG
    protocol.schemaVersion = '1.3.1'
    protocol.subgraphVersion = '1.0.0'
    protocol.methodologyVersion = '1.0.0'
    protocol.network = constants.Protocol.NETWORK
    protocol.type = constants.ProtocolType.YIELD
    protocol.totalValueLockedUSD = constants.BigDecimalConstants.ZERO
    protocol.protocolControlledValueUSD = constants.BigDecimalConstants.ZERO
    protocol.cumulativeSupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    protocol.cumulativeProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO
    protocol.cumulativeTotalRevenueUSD = constants.BigDecimalConstants.ZERO
    protocol.cumulativeUniqueUsers = 0
    protocol.lastDailyUpdateTimestamp = timestamp
      .div(BigIntConstants.SECONDS_PER_DAY)
      .times(BigIntConstants.SECONDS_PER_DAY)
    protocol.lastHourlyUpdateTimestamp = timestamp
      .div(BigIntConstants.SECONDS_PER_HOUR)
      .times(BigIntConstants.SECONDS_PER_HOUR)
    protocol.totalPoolCount = 0
    protocol.vaultsArray = []
    protocol.save()
  }

  // protocol.schemaVersion = Versions.getSchemaVersion();
  // protocol.subgraphVersion = Versions.getSubgraphVersion();
  // protocol.methodologyVersion = Versions.getMethodologyVersion();

  return protocol
}

export function getOrCreateToken(address: Address): Token {
  let token = Token.load(address.toHexString())

  if (!token) {
    token = new Token(address.toHexString())

    const contract = ERC20Contract.bind(address)

    token.name = utils.readValue<string>(contract.try_name(), '')
    if (address == addresses.USDCE) {
      token.symbol = 'USDC.E'
    } else {
      token.symbol = utils.readValue<string>(contract.try_symbol(), '')
    }
    token.decimals = utils
      .readValue<BigInt>(contract.try_decimals(), constants.BigIntConstants.ZERO)
      .toI32() as u8

    token.save()
  }

  return token
}

export function getOrCreateFinancialDailySnapshots(block: ethereum.Block): FinancialsDailySnapshot {
  const id = block.timestamp.toI64() / constants.SECONDS_PER_DAY
  let financialMetrics = FinancialsDailySnapshot.load(id.toString())

  if (!financialMetrics) {
    financialMetrics = new FinancialsDailySnapshot(id.toString())
    financialMetrics.protocol = constants.PROTOCOL_ID

    financialMetrics.totalValueLockedUSD = constants.BigDecimalConstants.ZERO
    financialMetrics.dailySupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    financialMetrics.cumulativeSupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    financialMetrics.dailyProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO
    financialMetrics.cumulativeProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO

    financialMetrics.dailyTotalRevenueUSD = constants.BigDecimalConstants.ZERO
    financialMetrics.cumulativeTotalRevenueUSD = constants.BigDecimalConstants.ZERO

    financialMetrics.blockNumber = block.number
    financialMetrics.timestamp = block.timestamp

    financialMetrics.save()
  }

  return financialMetrics
}

export function getOrCreateUsageMetricsDailySnapshot(
  block: ethereum.Block,
): UsageMetricsDailySnapshot {
  const id: string = (block.timestamp.toI64() / constants.SECONDS_PER_DAY).toString()
  let usageMetrics = UsageMetricsDailySnapshot.load(id)

  if (!usageMetrics) {
    usageMetrics = new UsageMetricsDailySnapshot(id)
    usageMetrics.protocol = constants.PROTOCOL_ID

    usageMetrics.dailyActiveUsers = 0
    usageMetrics.cumulativeUniqueUsers = 0
    usageMetrics.dailyTransactionCount = 0
    usageMetrics.dailyDepositCount = 0
    usageMetrics.dailyWithdrawCount = 0

    usageMetrics.blockNumber = block.number
    usageMetrics.timestamp = block.timestamp

    const protocol = getOrCreateYieldAggregator(block.timestamp)
    usageMetrics.totalPoolCount = protocol.totalPoolCount

    usageMetrics.save()
  }

  return usageMetrics
}

export function getOrCreateUsageMetricsHourlySnapshot(
  block: ethereum.Block,
): UsageMetricsHourlySnapshot {
  const metricsID: string = (block.timestamp.toI64() / constants.SECONDS_PER_HOUR).toString()
  let usageMetrics = UsageMetricsHourlySnapshot.load(metricsID)

  if (!usageMetrics) {
    usageMetrics = new UsageMetricsHourlySnapshot(metricsID)
    usageMetrics.protocol = constants.PROTOCOL_ID

    usageMetrics.hourlyActiveUsers = 0
    usageMetrics.cumulativeUniqueUsers = 0
    usageMetrics.hourlyTransactionCount = 0
    usageMetrics.hourlyDepositCount = 0
    usageMetrics.hourlyWithdrawCount = 0

    usageMetrics.blockNumber = block.number
    usageMetrics.timestamp = block.timestamp

    usageMetrics.save()
  }

  return usageMetrics
}

export function getOrCreateVaultsDailySnapshots(
  vaultAddress: Address,
  block: ethereum.Block,
): VaultDailySnapshot {
  const vault = getOrCreateVault(vaultAddress, block)
  const currentDay = block.timestamp.toI64() / constants.SECONDS_PER_DAY
  const dailyTimestamp = getDailyTimestamp(block.timestamp)
  const dailyRateId = getDailyVaultRateIdAndTimestamp(block, vault.id)
  const dailyRate = DailyInterestRate.load(dailyRateId.dailyRateId)

  const id: string = vault.id.concat('-').concat(currentDay.toString())
  let vaultSnapshots = VaultDailySnapshot.load(id)

  if (!vaultSnapshots) {
    vaultSnapshots = new VaultDailySnapshot(id)
    vaultSnapshots.protocol = vault.protocol
    vaultSnapshots.vault = vault.id

    vaultSnapshots.totalValueLockedUSD = vault.totalValueLockedUSD
    vaultSnapshots.inputTokenBalance = vault.inputTokenBalance
    vaultSnapshots.outputTokenSupply = vault.outputTokenSupply
    vaultSnapshots.outputTokenPriceUSD = vault.outputTokenPriceUSD
      ? vault.outputTokenPriceUSD!
      : constants.BigDecimalConstants.ZERO
    vaultSnapshots.inputTokenPriceUSD = vault.inputTokenPriceUSD
      ? vault.inputTokenPriceUSD!
      : constants.BigDecimalConstants.ZERO
    vaultSnapshots.pricePerShare = vault.pricePerShare
      ? vault.pricePerShare!
      : constants.BigDecimalConstants.ZERO

    vaultSnapshots.calculatedApr = dailyRate!.averageRate
    vaultSnapshots.dailySupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeSupplySideRevenueUSD = vault.cumulativeSupplySideRevenueUSD

    vaultSnapshots.dailyProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeProtocolSideRevenueUSD = vault.cumulativeProtocolSideRevenueUSD

    vaultSnapshots.dailyTotalRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeTotalRevenueUSD = vault.cumulativeTotalRevenueUSD

    vaultSnapshots.blockNumber = block.number
    vaultSnapshots.timestamp = dailyTimestamp

    vaultSnapshots.save()

    updateVaultAPRs(vault, dailyRate!.averageRate)
    vault.save()
  }

  return vaultSnapshots
}

export function getOrCreateVaultsHourlySnapshots(
  vaultAddress: Address,
  block: ethereum.Block,
): VaultHourlySnapshot {
  const vault = getOrCreateVault(vaultAddress, block)
  const hourTimestamp = getHourlyOffsetTimestamp(block.timestamp)
  const currentHour = block.timestamp
    .minus(BigIntConstants.SECONDS_PER_HOUR)
    .div(BigIntConstants.SECONDS_PER_HOUR)
  const id: string = vault.id.concat('-').concat(currentHour.toString())

  const hourlyRateId = getHourlyVaultRateIdAndTimestamp(block, vault.id)
  const hourlyRate = HourlyInterestRate.load(hourlyRateId.hourlyRateId)

  let vaultSnapshots = VaultHourlySnapshot.load(id)

  if (!vaultSnapshots) {
    vaultSnapshots = new VaultHourlySnapshot(id)
    vaultSnapshots.protocol = vault.protocol
    vaultSnapshots.vault = vault.id

    vaultSnapshots.totalValueLockedUSD = vault.totalValueLockedUSD
    vaultSnapshots.inputTokenBalance = vault.inputTokenBalance
    vaultSnapshots.outputTokenSupply = vault.outputTokenSupply
    vaultSnapshots.outputTokenPriceUSD = vault.outputTokenPriceUSD
      ? vault.outputTokenPriceUSD!
      : constants.BigDecimalConstants.ZERO
    vaultSnapshots.inputTokenPriceUSD = vault.inputTokenPriceUSD
      ? vault.inputTokenPriceUSD!
      : constants.BigDecimalConstants.ZERO
    vaultSnapshots.pricePerShare = vault.pricePerShare
      ? vault.pricePerShare!
      : constants.BigDecimalConstants.ZERO
    vaultSnapshots.calculatedApr = hourlyRate!.averageRate
    vaultSnapshots.hourlySupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeSupplySideRevenueUSD = vault.cumulativeSupplySideRevenueUSD

    vaultSnapshots.hourlyProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeProtocolSideRevenueUSD = vault.cumulativeProtocolSideRevenueUSD

    vaultSnapshots.hourlyTotalRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeTotalRevenueUSD = vault.cumulativeTotalRevenueUSD

    vaultSnapshots.blockNumber = block.number
    vaultSnapshots.timestamp = hourTimestamp
    vaultSnapshots.save()
  }

  return vaultSnapshots
}

export function getOrCreateVault(vaultAddress: Address, block: ethereum.Block): VaultStore {
  let vault = VaultStore.load(vaultAddress.toHexString())

  if (!vault) {
    vault = new VaultStore(vaultAddress.toHexString())

    const vaultContract = FleetCommanderContract.bind(vaultAddress)
    vault.name = utils.readValue<string>(vaultContract.try_name(), '')
    vault.symbol = utils.readValue<string>(vaultContract.try_symbol(), '')

    vault.protocol = constants.PROTOCOL_ID
    const config = vaultContract.getConfig()
    vault.depositCap = config.depositCap
    vault.depositLimit = config.depositCap
    vault.minimumBufferBalance = config.minimumBufferBalance
    vault.stakingRewardsManager = Address.fromString(
      getOrCreateRewardsManager(config.stakingRewardsManager).id,
    )

    vault.maxRebalanceOperations = config.maxRebalanceOperations
    vault.details = utils.readValue<string>(vaultContract.try_details(), '')
    vault.rebalanceCount = constants.BigIntConstants.ZERO

    const inputToken = getOrCreateToken(vaultContract.asset())
    vault.inputToken = inputToken.id
    vault.inputTokenBalance = constants.BigIntConstants.ZERO

    const outputToken = getOrCreateToken(vaultAddress)
    vault.outputToken = outputToken.id
    vault.outputTokenSupply = constants.BigIntConstants.ZERO
    vault.outputTokenPriceUSD = constants.BigDecimalConstants.ZERO
    vault.inputTokenPriceUSD = constants.BigDecimalConstants.ZERO

    vault.pricePerShare = constants.BigDecimalConstants.ZERO
    vault.totalValueLockedUSD = constants.BigDecimalConstants.ZERO
    vault.withdrawableTotalAssets = constants.BigIntConstants.ZERO
    vault.withdrawableTotalAssetsUSD = constants.BigDecimalConstants.ZERO
    vault.lastUpdatePricePerShare = constants.BigDecimalConstants.ZERO

    vault.cumulativeSupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    vault.cumulativeProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO
    vault.cumulativeTotalRevenueUSD = constants.BigDecimalConstants.ZERO
    vault.calculatedApr = constants.BigDecimalConstants.ZERO

    vault.createdBlockNumber = block.number
    vault.createdTimestamp = block.timestamp
    vault.lastUpdateTimestamp = block.timestamp

    const managementFeeId =
      utils.enumToPrefix(constants.VaultFeeType.MANAGEMENT_FEE) + vaultAddress.toHexString()
    const managementFee = constants.BigIntConstants.ZERO
    utils.createFeeType(managementFeeId, constants.VaultFeeType.MANAGEMENT_FEE, managementFee)

    const performanceFeeId =
      utils.enumToPrefix(constants.VaultFeeType.PERFORMANCE_FEE) + vaultAddress.toHexString()
    const performanceFee = constants.BigIntConstants.ZERO
    utils.createFeeType(performanceFeeId, constants.VaultFeeType.PERFORMANCE_FEE, performanceFee)

    vault.fees = [managementFeeId, performanceFeeId]

    vault.arksArray = []
    vault.aprValues = []
    vault.apr7d = constants.BigDecimalConstants.ZERO
    vault.apr30d = constants.BigDecimalConstants.ZERO
    vault.apr90d = constants.BigDecimalConstants.ZERO
    vault.apr180d = constants.BigDecimalConstants.ZERO
    vault.apr365d = constants.BigDecimalConstants.ZERO

    // Initialize arrays
    vault.rewardTokens = []
    vault.rewardTokenEmissionsAmount = []
    vault.rewardTokenEmissionsUSD = []
    vault.rewardTokenEmissionsAmountsPerOutputToken = []
    vault.rewardTokenEmissionsFinish = []
    vault.positions = []

    vault.save()

    const yeildAggregator = getOrCreateYieldAggregator(block.timestamp)
    const vaultsArray = yeildAggregator.vaultsArray
    vaultsArray.push(vault.id)
    yeildAggregator.vaultsArray = vaultsArray
    yeildAggregator.totalPoolCount = yeildAggregator.totalPoolCount + 1
    yeildAggregator.save()

    FleetCommanderTemplate.create(vaultAddress)
    FleetCommanderRewardsManagerTemplate.create(config.stakingRewardsManager)

    const bufferArk = vaultContract.bufferArk()
    getOrCreateArk(vaultAddress, bufferArk, block)
  }

  return vault
}

export function getOrCreateArk(
  vaultAddress: Address,
  arkAddress: Address,
  block: ethereum.Block,
): Ark {
  let ark = Ark.load(arkAddress.toHexString())

  if (!ark) {
    ark = new Ark(arkAddress.toHexString())

    const arkContract = ArkContract.bind(arkAddress)
    const vault = getOrCreateVault(vaultAddress, block)

    ark.name = arkContract.name()
    ark.vault = vaultAddress.toHexString()
    const config = arkContract.getConfig()
    ark.depositLimit = config.depositCap
    ark.depositCap = ark.depositLimit
    ark.maxDepositPercentageOfTVL = config.maxDepositPercentageOfTVL
    ark.maxRebalanceOutflow = config.maxRebalanceOutflow
    ark.maxRebalanceInflow = config.maxRebalanceInflow
    ark.requiresKeeperData = config.requiresKeeperData
    ark.details = config.details

    ark.inputToken = vault.inputToken
    ark.inputTokenBalance = constants.BigIntConstants.ZERO
    ark.totalValueLockedUSD = constants.BigDecimalConstants.ZERO
    ark.cumulativeSupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    ark.cumulativeProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO
    ark.cumulativeTotalRevenueUSD = constants.BigDecimalConstants.ZERO
    ark.calculatedApr = constants.BigDecimalConstants.ZERO

    ark.cumulativeEarnings = constants.BigIntConstants.ZERO
    ark._cumulativeDeposits = constants.BigIntConstants.ZERO
    ark._cumulativeWithdrawals = constants.BigIntConstants.ZERO
    ark._lastUpdateInputTokenBalance = constants.BigIntConstants.ZERO

    ark.createdBlockNumber = block.number
    ark.createdTimestamp = block.timestamp
    ark.lastUpdateTimestamp = block.timestamp

    const managementFeeId =
      utils.enumToPrefix(constants.VaultFeeType.MANAGEMENT_FEE) + arkAddress.toHexString()
    const managementFee = new VaultFee(managementFeeId)
    managementFee.feeType = constants.VaultFeeType.MANAGEMENT_FEE
    managementFee.feePercentage = constants.BigDecimalConstants.ZERO
    managementFee.save()

    const performanceFeeId =
      utils.enumToPrefix(constants.VaultFeeType.PERFORMANCE_FEE) + arkAddress.toHexString()
    const performanceFee = new VaultFee(performanceFeeId)
    performanceFee.feeType = constants.VaultFeeType.PERFORMANCE_FEE
    performanceFee.feePercentage = constants.BigDecimalConstants.ZERO
    performanceFee.save()

    ark.fees = [managementFeeId, performanceFeeId]

    // Initialize arrays
    ark.rewardTokens = []
    ark.rewardTokenEmissionsAmount = []
    ark.rewardTokenEmissionsUSD = []

    ark.save()

    const arksArray = vault.arksArray
    if (!arksArray.includes(ark.id)) {
      arksArray.push(ark.id)
      vault.arksArray = arksArray
      vault.save()
    }

    ArkTemplate.create(arkAddress)
  }

  return ark
}

export function getOrCreateArksHourlySnapshots(
  vaultAddress: Address,
  arkAddress: Address,
  block: ethereum.Block,
): ArkHourlySnapshot {
  const ark = getOrCreateArk(vaultAddress, arkAddress, block)
  const id: string = ark.id
    .concat('-')
    .concat((block.timestamp.toI64() / constants.SECONDS_PER_HOUR).toString())
  const previousId = ark.id
    .concat('-')
    .concat(
      (
        (block.timestamp.toI64() - constants.SECONDS_PER_HOUR) /
        constants.SECONDS_PER_HOUR
      ).toString(),
    )
  let arkSnapshots = ArkHourlySnapshot.load(id)
  let previousSnapshot = ArkHourlySnapshot.load(previousId)
  if (!arkSnapshots) {
    const arkContract = ArkContract.bind(arkAddress)
    arkSnapshots = new ArkHourlySnapshot(id)
    arkSnapshots.protocol = ark.vault
    arkSnapshots.vault = ark.vault
    arkSnapshots.ark = ark.id

    arkSnapshots.totalValueLockedUSD = ark.totalValueLockedUSD
    arkSnapshots.inputTokenBalance = ark.inputTokenBalance

    arkSnapshots.calculatedApr = ark.calculatedApr

    arkSnapshots.blockNumber = block.number
    arkSnapshots.timestamp = block.timestamp
    arkSnapshots.save()
  }

  return arkSnapshots
}

export function getOrCreateArksDailySnapshots(
  vaultAddress: Address,
  arkAddress: Address,
  block: ethereum.Block,
): ArkDailySnapshot {
  const ark = getOrCreateArk(vaultAddress, arkAddress, block)
  const id: string = ark.id
    .concat('-')
    .concat((block.timestamp.toI64() / constants.SECONDS_PER_DAY).toString())
  let arkSnapshots = ArkDailySnapshot.load(id)

  if (!arkSnapshots) {
    const arkContract = ArkContract.bind(arkAddress)
    arkSnapshots = new ArkDailySnapshot(id)
    arkSnapshots.protocol = ark.vault
    arkSnapshots.vault = ark.vault
    arkSnapshots.ark = ark.id

    arkSnapshots.totalValueLockedUSD = ark.totalValueLockedUSD
    arkSnapshots.inputTokenBalance = ark.inputTokenBalance

    arkSnapshots.apr = ark.calculatedApr

    arkSnapshots.blockNumber = block.number
    arkSnapshots.timestamp = block.timestamp

    arkSnapshots.save()
  }

  return arkSnapshots
}

export function getOrCreateArksPostActionSnapshots(
  vaultAddress: Address,
  arkAddress: Address,
  block: ethereum.Block,
): PostActionArkSnapshot {
  const ark = getOrCreateArk(vaultAddress, arkAddress, block)
  const id: string = ark.id.concat('-').concat(block.timestamp.toI64().toString())

  let arkSnapshots = PostActionArkSnapshot.load(id)

  if (!arkSnapshots) {
    const arkContract = ArkContract.bind(arkAddress)
    arkSnapshots = new PostActionArkSnapshot(id)
    arkSnapshots.protocol = ark.vault
    arkSnapshots.vault = ark.vault
    arkSnapshots.ark = ark.id

    arkSnapshots.depositLimit = utils.readValue<BigInt>(
      arkContract.try_depositCap(),
      constants.BigIntConstants.ZERO,
    )

    arkSnapshots.totalValueLockedUSD = ark.totalValueLockedUSD
    arkSnapshots.inputTokenBalance = ark.inputTokenBalance

    arkSnapshots.apr = ark.calculatedApr

    arkSnapshots.blockNumber = block.number
    arkSnapshots.timestamp = block.timestamp
    arkSnapshots.save()
  }

  return arkSnapshots
}

export function getOrCreateVaultsPostActionSnapshots(
  vaultAddress: Address,
  block: ethereum.Block,
): PostActionVaultSnapshot {
  const vault = getOrCreateVault(vaultAddress, block)
  const id: string = vault.id.concat('-').concat(block.timestamp.toI64().toString())
  let vaultSnapshots = PostActionVaultSnapshot.load(id)

  if (!vaultSnapshots) {
    vaultSnapshots = new PostActionVaultSnapshot(id)
    vaultSnapshots.protocol = vault.protocol
    vaultSnapshots.vault = vault.id

    vaultSnapshots.totalValueLockedUSD = vault.totalValueLockedUSD
    vaultSnapshots.inputTokenBalance = vault.inputTokenBalance
    vaultSnapshots.outputTokenSupply = vault.outputTokenSupply
    vaultSnapshots.outputTokenPriceUSD = vault.outputTokenPriceUSD
      ? vault.outputTokenPriceUSD!
      : constants.BigDecimalConstants.ZERO
    vaultSnapshots.inputTokenPriceUSD = vault.inputTokenPriceUSD
      ? vault.inputTokenPriceUSD!
      : constants.BigDecimalConstants.ZERO
    vaultSnapshots.pricePerShare = vault.pricePerShare
      ? vault.pricePerShare!
      : constants.BigDecimalConstants.ZERO

    const totalAssets = vault.inputTokenBalance
    const arks = vault.arksArray

    // get weighted apr for all arks
    let weightedApr = constants.BigDecimalConstants.ZERO
    for (let j = 0; j < arks.length; j++) {
      const arkAddress = Address.fromString(arks[j])
      const ark = getOrCreateArk(vaultAddress, arkAddress, block)
      const arkApr = ark.calculatedApr
      const arkTotalAssets = ark.inputTokenBalance.toBigDecimal()
      const arkWeight = arkTotalAssets.div(totalAssets.toBigDecimal())
      weightedApr = weightedApr.plus(arkApr.times(arkWeight))
    }
    vaultSnapshots.apr = weightedApr.times(constants.BigDecimalConstants.HUNDRED)

    vaultSnapshots.blockNumber = block.number
    vaultSnapshots.timestamp = block.timestamp
    vaultSnapshots.save()
  }

  return vaultSnapshots
}

export function getOrCreatePositionHourlySnapshot(
  positionId: string,
  vaultId: Address,
  block: ethereum.Block,
): void {
  const hourTimestamp = getHourlyTimestamp(block.timestamp)
  const snapshotId = positionId + '-' + hourTimestamp.toString()
  let snapshot = PositionHourlySnapshot.load(snapshotId)

  const vault = getOrCreateVault(vaultId, block)
  const inputToken = getOrCreateToken(Address.fromString(vault.inputToken))
  if (!snapshot) {
    snapshot = new PositionHourlySnapshot(snapshotId)
    snapshot.position = positionId
    snapshot.timestamp = hourTimestamp
    snapshot.inputTokenBalance = constants.BIGINT_ZERO
    snapshot.outputTokenBalance = constants.BIGINT_ZERO
  }

  // Update balances
  const position = Position.load(positionId)
  if (position) {
    snapshot.outputTokenBalance = position.outputTokenBalance

    position.inputTokenBalance = position.outputTokenBalance
      .times(vault.inputTokenBalance)
      .div(vault.outputTokenSupply)
    position.stakedInputTokenBalance = position.stakedOutputTokenBalance
      .times(vault.inputTokenBalance)
      .div(vault.outputTokenSupply)

    snapshot.inputTokenBalance = snapshot.outputTokenBalance
      .times(vault.inputTokenBalance)
      .div(vault.outputTokenSupply)

    // Update normalized values
    position.inputTokenBalanceNormalized = utils.formatAmount(
      position.inputTokenBalance,
      BigInt.fromI32(inputToken.decimals),
    )
    position.stakedInputTokenBalanceNormalized = utils.formatAmount(
      position.stakedInputTokenBalance,
      BigInt.fromI32(inputToken.decimals),
    )
    position.inputTokenBalanceNormalizedInUSD = position.inputTokenBalanceNormalized.times(
      vault.inputTokenPriceUSD!,
    )
    position.stakedInputTokenBalanceNormalizedInUSD =
      position.stakedInputTokenBalanceNormalized.times(vault.inputTokenPriceUSD!)

    snapshot.inputTokenBalanceNormalizedInUSD = utils
      .formatAmount(snapshot.inputTokenBalance, BigInt.fromI32(inputToken.decimals))
      .times(vault.inputTokenPriceUSD!)
    snapshot.inputTokenDeposits = position.inputTokenDeposits
    snapshot.inputTokenWithdrawals = position.inputTokenWithdrawals
    snapshot.inputTokenDepositsNormalizedInUSD = position.inputTokenDepositsNormalizedInUSD
    snapshot.inputTokenWithdrawalsNormalizedInUSD = position.inputTokenWithdrawalsNormalizedInUSD
    position.save()
  }

  snapshot.save()
}

// Function to create or update position daily snapshots
export function getOrCreatePositionDailySnapshot(
  positionId: string,
  vaultId: Address,
  block: ethereum.Block,
): void {
  const dayTimestamp = getDailyTimestamp(block.timestamp)

  const snapshotId = positionId + '-' + dayTimestamp.toString()
  let snapshot = PositionDailySnapshot.load(snapshotId)
  const vault = getOrCreateVault(vaultId, block)
  const inputToken = getOrCreateToken(Address.fromString(vault.inputToken))
  if (!snapshot) {
    snapshot = new PositionDailySnapshot(snapshotId)
    snapshot.position = positionId
    snapshot.timestamp = dayTimestamp
    snapshot.inputTokenBalance = constants.BIGINT_ZERO
    snapshot.outputTokenBalance = constants.BIGINT_ZERO
  }

  // Update balances
  const position = Position.load(positionId)
  if (position) {
    snapshot.outputTokenBalance = position.outputTokenBalance

    snapshot.inputTokenBalance = snapshot.outputTokenBalance
      .times(vault.inputTokenBalance)
      .div(vault.outputTokenSupply)
    snapshot.inputTokenBalanceNormalizedInUSD = utils
      .formatAmount(snapshot.inputTokenBalance, BigInt.fromI32(inputToken.decimals))
      .times(vault.inputTokenPriceUSD!)
    snapshot.inputTokenDeposits = position.inputTokenDeposits
    snapshot.inputTokenWithdrawals = position.inputTokenWithdrawals
    snapshot.inputTokenDepositsNormalizedInUSD = position.inputTokenDepositsNormalizedInUSD
    snapshot.inputTokenWithdrawalsNormalizedInUSD = position.inputTokenWithdrawalsNormalizedInUSD
  }

  snapshot.save()
}

// Function to create or update position weekly snapshots
export function getOrCreatePositionWeeklySnapshot(
  positionId: string,
  vaultId: Address,
  block: ethereum.Block,
): void {
  const weekTimestamp = getWeeklyOffsetTimestamp(block.timestamp)

  const snapshotId = positionId + '-' + weekTimestamp.toString()
  let snapshot = PositionWeeklySnapshot.load(snapshotId)
  const vault = getOrCreateVault(vaultId, block)
  const inputToken = getOrCreateToken(Address.fromString(vault.inputToken))
  if (!snapshot) {
    snapshot = new PositionWeeklySnapshot(snapshotId)
    snapshot.position = positionId
    snapshot.timestamp = weekTimestamp
    snapshot.inputTokenBalance = constants.BIGINT_ZERO
    snapshot.outputTokenBalance = constants.BIGINT_ZERO
  }

  // Update balances
  const position = Position.load(positionId)
  if (position) {
    snapshot.outputTokenBalance = position.outputTokenBalance

    snapshot.inputTokenBalance = snapshot.outputTokenBalance
      .times(vault.inputTokenBalance)
      .div(vault.outputTokenSupply)
    snapshot.inputTokenBalanceNormalizedInUSD = utils
      .formatAmount(snapshot.inputTokenBalance, BigInt.fromI32(inputToken.decimals))
      .times(vault.inputTokenPriceUSD!)
    snapshot.inputTokenDeposits = position.inputTokenDeposits
    snapshot.inputTokenWithdrawals = position.inputTokenWithdrawals
    snapshot.inputTokenDepositsNormalizedInUSD = position.inputTokenDepositsNormalizedInUSD
    snapshot.inputTokenWithdrawalsNormalizedInUSD = position.inputTokenWithdrawalsNormalizedInUSD
  }

  snapshot.save()
}

export function getOrCreateVaultWeeklySnapshots(
  vaultAddress: Address,
  block: ethereum.Block,
): void {
  const weekTimestamp = getWeeklyOffsetTimestamp(block.timestamp)
  const snapshotId = vaultAddress.toHexString() + '-' + weekTimestamp.toString()
  let snapshot = VaultWeeklySnapshot.load(snapshotId)

  const weeklyRateId = getWeeklyVaultRateIdAndTimestamp(block, vaultAddress.toHexString())
  const weeklyRate = WeeklyInterestRate.load(weeklyRateId.weeklyRateId)

  if (!snapshot) {
    snapshot = new VaultWeeklySnapshot(snapshotId)
    const vault = getOrCreateVault(vaultAddress, block)
    const protocol = getOrCreateYieldAggregator(block.timestamp)

    snapshot.protocol = protocol.id
    snapshot.vault = vault.id
    snapshot.blockNumber = block.number
    snapshot.timestamp = weekTimestamp

    // Initialize metrics
    snapshot.totalValueLockedUSD = constants.BigDecimalConstants.ZERO
    snapshot.inputTokenBalance = constants.BigIntConstants.ZERO
    snapshot.outputTokenSupply = constants.BigIntConstants.ZERO
    snapshot.weeklySupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    snapshot.weeklyProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO
    snapshot.weeklyTotalRevenueUSD = constants.BigDecimalConstants.ZERO
    snapshot.cumulativeSupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    snapshot.cumulativeProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO
    snapshot.cumulativeTotalRevenueUSD = constants.BigDecimalConstants.ZERO
    snapshot.calculatedApr = constants.BigDecimalConstants.ZERO

    snapshot.save()
  }

  // Update snapshot with current values
  const vault = getOrCreateVault(vaultAddress, block)
  snapshot.totalValueLockedUSD = vault.totalValueLockedUSD
  snapshot.inputTokenBalance = vault.inputTokenBalance
  snapshot.outputTokenSupply = vault.outputTokenSupply
  snapshot.outputTokenPriceUSD = vault.outputTokenPriceUSD
  snapshot.inputTokenPriceUSD = vault.inputTokenPriceUSD
  snapshot.pricePerShare = vault.pricePerShare
  snapshot.stakedOutputTokenAmount = vault.stakedOutputTokenAmount
  snapshot.rewardTokenEmissionsAmount = vault.rewardTokenEmissionsAmount
  snapshot.rewardTokenEmissionsUSD = vault.rewardTokenEmissionsUSD
  snapshot.calculatedApr = weeklyRate!.averageRate

  // Update cumulative and weekly revenues
  const previousSnapshot = VaultWeeklySnapshot.load(
    vaultAddress.toHexString() +
      '-' +
      weekTimestamp.minus(BigIntConstants.SECONDS_PER_WEEK).toString(),
  )

  if (previousSnapshot) {
    snapshot.weeklySupplySideRevenueUSD = vault.cumulativeSupplySideRevenueUSD.minus(
      previousSnapshot.cumulativeSupplySideRevenueUSD,
    )
    snapshot.weeklyProtocolSideRevenueUSD = vault.cumulativeProtocolSideRevenueUSD.minus(
      previousSnapshot.cumulativeProtocolSideRevenueUSD,
    )
    snapshot.weeklyTotalRevenueUSD = vault.cumulativeTotalRevenueUSD.minus(
      previousSnapshot.cumulativeTotalRevenueUSD,
    )
  }

  snapshot.cumulativeSupplySideRevenueUSD = vault.cumulativeSupplySideRevenueUSD
  snapshot.cumulativeProtocolSideRevenueUSD = vault.cumulativeProtocolSideRevenueUSD
  snapshot.cumulativeTotalRevenueUSD = vault.cumulativeTotalRevenueUSD

  snapshot.save()
}
