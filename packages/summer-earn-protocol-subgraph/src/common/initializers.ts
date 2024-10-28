import { Address, BigDecimal, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import { ERC20 as ERC20Contract } from '../../generated/HarborCommand/ERC20'
import {
  Account,
  Ark,
  ArkDailySnapshot,
  ArkHourlySnapshot,
  FinancialsDailySnapshot,
  Position,
  PostActionArkSnapshot,
  PostActionVaultSnapshot,
  Token,
  UsageMetricsDailySnapshot,
  UsageMetricsHourlySnapshot,
  Vault,
  VaultDailySnapshot,
  VaultFee,
  VaultHourlySnapshot,
  Vault as VaultStore,
  YieldAggregator,
} from '../../generated/schema'
import { ArkTemplate, FleetCommanderTemplate } from '../../generated/templates'
import { Ark as ArkContract } from '../../generated/templates/FleetCommanderTemplate/Ark'
import { FleetCommander as FleetCommanderContract } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import * as constants from './constants'
import { BigDecimalConstants } from './constants'
import * as utils from './utils'

export function getOrCreateAccount(id: string): Account {
  let account = Account.load(id)

  if (!account) {
    account = new Account(id)
    account.save()

    const protocol = getOrCreateYieldAggregator()
    protocol.cumulativeUniqueUsers += 1
    protocol.save()
  }

  return account
}

export function getOrCreatePosition(positionId: string, block: ethereum.Block): Position {
  let position = Position.load(positionId)
  const positionIdDetails = utils.getAccountIdAndVaultIdFromPositionId(positionId)
  if (!position) {
    position = new Position(positionId)
    position.inputTokenBalance = constants.BigIntConstants.ZERO
    position.outputTokenBalance = constants.BigIntConstants.ZERO
    position.outputTokenBalanceNormalized = constants.BigDecimalConstants.ZERO
    position.outputTokenBalanceNormalizedInUSD = constants.BigDecimalConstants.ZERO
    position.account = positionIdDetails[0]
    position.vault = positionIdDetails[1]
    position.createdBlockNumber = block.number
    position.createdTimestamp = block.timestamp
    position.save()
  }

  return position
}

export function getOrCreateYieldAggregator(): YieldAggregator {
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
    protocol.lastUpdateTimestamp = constants.BigIntConstants.ZERO
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
    token.symbol = utils.readValue<string>(contract.try_symbol(), '')
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

    const protocol = getOrCreateYieldAggregator()
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

export function updateVaultAPRs(vault: Vault, block: ethereum.Block): void {
  const MAX_APR_VALUES = 365
  const currentApr = vault.calculatedApr
  let aprValues = vault.aprValues

  // Add new APR to the array
  if (aprValues.length >= MAX_APR_VALUES) {
    // Shift array by removing first element and adding new one at the end
    const newArray = new Array<BigDecimal>(MAX_APR_VALUES)
    for (let i = 0; i < MAX_APR_VALUES - 1; i++) {
      newArray[i] = aprValues[i + 1]
    }
    newArray[MAX_APR_VALUES - 1] = currentApr
    aprValues = newArray
  } else {
    aprValues.push(currentApr)
  }

  // Update vault's APR array
  vault.aprValues = aprValues

  // Calculate averages for different time windows
  const length = aprValues.length
  let sum7d = BigDecimalConstants.ZERO
  let sum30d = BigDecimalConstants.ZERO
  let sum90d = BigDecimalConstants.ZERO
  let sum180d = BigDecimalConstants.ZERO
  let sum365d = BigDecimalConstants.ZERO

  for (let i = 0; i < length; i++) {
    const value = aprValues[length - 1 - i] // Start from the most recent

    if (i < 7) sum7d = sum7d.plus(value)
    if (i < 30) sum30d = sum30d.plus(value)
    if (i < 90) sum90d = sum90d.plus(value)
    if (i < 180) sum180d = sum180d.plus(value)
    if (i < 365) sum365d = sum365d.plus(value)
  }

  // Update rolling averages
  vault.apr7d =
    length >= 7
      ? sum7d.div(BigDecimal.fromString('7'))
      : sum7d.div(BigDecimal.fromString(length.toString()))
  vault.apr30d =
    length >= 30
      ? sum30d.div(BigDecimal.fromString('30'))
      : sum30d.div(BigDecimal.fromString(length.toString()))
  vault.apr90d =
    length >= 90
      ? sum90d.div(BigDecimal.fromString('90'))
      : sum90d.div(BigDecimal.fromString(length.toString()))
  vault.apr180d =
    length >= 180
      ? sum180d.div(BigDecimal.fromString('180'))
      : sum180d.div(BigDecimal.fromString(length.toString()))
  vault.apr365d =
    length >= 365
      ? sum365d.div(BigDecimal.fromString('365'))
      : sum365d.div(BigDecimal.fromString(length.toString()))
}

export function getOrCreateVaultsDailySnapshots(
  vaultAddress: Address,
  block: ethereum.Block,
): VaultDailySnapshot {
  const vault = getOrCreateVault(vaultAddress, block)

  const currentDay = block.timestamp.toI64() / constants.SECONDS_PER_DAY
  // Calculate previous day directly
  const previousDay = currentDay - 1

  const previousId = vault.id.concat('-').concat(previousDay.toString())

  log.error('Creating daily snapshot - Current: {}, Previous: {}, Timestamp: {}', [
    currentDay.toString(),
    previousDay.toString(),
    block.timestamp.toString(),
  ])
  const previousSnapshot = VaultDailySnapshot.load(previousId)

  const id: string = vault.id
    .concat('-')
    .concat((block.timestamp.toI64() / constants.SECONDS_PER_DAY).toString())
  let vaultSnapshots = VaultDailySnapshot.load(id)

  if (!vaultSnapshots) {
    vaultSnapshots = new VaultDailySnapshot(id)
    vaultSnapshots.protocol = vault.protocol
    vaultSnapshots.vault = vault.id

    vaultSnapshots.totalValueLockedUSD = vault.totalValueLockedUSD
    vaultSnapshots.inputTokenBalance = vault.inputTokenBalance
    vaultSnapshots.outputTokenSupply = vault.outputTokenSupply
      ? vault.outputTokenSupply!
      : constants.BigIntConstants.ZERO
    vaultSnapshots.outputTokenPriceUSD = vault.outputTokenPriceUSD
      ? vault.outputTokenPriceUSD!
      : constants.BigDecimalConstants.ZERO
    vaultSnapshots.pricePerShare = vault.pricePerShare
      ? vault.pricePerShare!
      : constants.BigDecimalConstants.ZERO

    vaultSnapshots.calculatedApr = !previousSnapshot
      ? constants.BigDecimalConstants.ZERO
      : utils.getAprForTimePeriod(
          previousSnapshot.pricePerShare!,
          vault.pricePerShare!,
          constants.BigDecimalConstants.DAY_IN_SECONDS,
        )
    log.error('vaultSnapshots.pricePerShare {} previous {} day in seconds {} apr {}', [
      vaultSnapshots.pricePerShare!.toString(),
      previousSnapshot ? previousSnapshot.pricePerShare!.toString() : 'nope',
      constants.BigDecimalConstants.DAY_IN_SECONDS.toString(),
      vaultSnapshots.calculatedApr.toString(),
    ])
    vaultSnapshots.dailySupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeSupplySideRevenueUSD = vault.cumulativeSupplySideRevenueUSD

    vaultSnapshots.dailyProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeProtocolSideRevenueUSD = vault.cumulativeProtocolSideRevenueUSD

    vaultSnapshots.dailyTotalRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeTotalRevenueUSD = vault.cumulativeTotalRevenueUSD

    vaultSnapshots.blockNumber = block.number
    vaultSnapshots.timestamp = block.timestamp

    vaultSnapshots.save()

    updateVaultAPRs(vault, block)
    vault.save()
  }

  return vaultSnapshots
}

export function getOrCreateVaultsHourlySnapshots(
  vaultAddress: Address,
  block: ethereum.Block,
): VaultHourlySnapshot {
  const vault = getOrCreateVault(vaultAddress, block)
  const currentHour = block.timestamp.toI64() / constants.SECONDS_PER_HOUR
  // Calculate previous hour directly
  const previousHour = currentHour - 1

  const id: string = vault.id.concat('-').concat(currentHour.toString())
  const previousId = vault.id.concat('-').concat(previousHour.toString())

  const previousSnapshot = VaultHourlySnapshot.load(previousId)
  let vaultSnapshots = VaultHourlySnapshot.load(id)

  if (!vaultSnapshots) {
    vaultSnapshots = new VaultHourlySnapshot(id)
    vaultSnapshots.protocol = vault.protocol
    vaultSnapshots.vault = vault.id

    vaultSnapshots.totalValueLockedUSD = vault.totalValueLockedUSD
    vaultSnapshots.inputTokenBalance = vault.inputTokenBalance
    vaultSnapshots.outputTokenSupply = vault.outputTokenSupply
      ? vault.outputTokenSupply!
      : constants.BigIntConstants.ZERO
    vaultSnapshots.outputTokenPriceUSD = vault.outputTokenPriceUSD
      ? vault.outputTokenPriceUSD!
      : constants.BigDecimalConstants.ZERO
    vaultSnapshots.pricePerShare = vault.pricePerShare
      ? vault.pricePerShare!
      : constants.BigDecimalConstants.ZERO
    vaultSnapshots.calculatedApr = !previousSnapshot
      ? constants.BigDecimalConstants.ZERO
      : utils.getAprForTimePeriod(
          previousSnapshot.pricePerShare!,
          vault.pricePerShare!,
          constants.BigDecimalConstants.HOUR_IN_SECONDS,
        )

    vaultSnapshots.hourlySupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeSupplySideRevenueUSD = vault.cumulativeSupplySideRevenueUSD

    vaultSnapshots.hourlyProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeProtocolSideRevenueUSD = vault.cumulativeProtocolSideRevenueUSD

    vaultSnapshots.hourlyTotalRevenueUSD = constants.BigDecimalConstants.ZERO
    vaultSnapshots.cumulativeTotalRevenueUSD = vault.cumulativeTotalRevenueUSD

    vaultSnapshots.blockNumber = block.number
    vaultSnapshots.timestamp = block.timestamp
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
    vault.depositLimit = config.depositCap

    const inputToken = getOrCreateToken(vaultContract.asset())
    vault.inputToken = inputToken.id
    vault.inputTokenBalance = constants.BigIntConstants.ZERO

    const outputToken = getOrCreateToken(vaultAddress)
    vault.outputToken = outputToken.id
    vault.outputTokenSupply = constants.BigIntConstants.ZERO
    vault.outputTokenPriceUSD = constants.BigDecimalConstants.ZERO

    vault.pricePerShare = constants.BigDecimalConstants.ZERO
    vault.totalValueLockedUSD = constants.BigDecimalConstants.ZERO

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

    const initialVaultArks = utils.readValue<Address[]>(
      vaultContract.try_getArks(),
      new Array<Address>(),
    )

    vault.arksArray = initialVaultArks.map<string>((ark: Address) => ark.toHexString())
    vault.aprValues = []
    vault.apr7d = constants.BigDecimalConstants.ZERO
    vault.apr30d = constants.BigDecimalConstants.ZERO
    vault.apr90d = constants.BigDecimalConstants.ZERO
    vault.apr180d = constants.BigDecimalConstants.ZERO
    vault.apr365d = constants.BigDecimalConstants.ZERO

    vault.save()

    const yeildAggregator = getOrCreateYieldAggregator()
    const vaultsArray = yeildAggregator.vaultsArray
    vaultsArray.push(vault.id)
    yeildAggregator.vaultsArray = vaultsArray
    yeildAggregator.totalPoolCount = yeildAggregator.totalPoolCount + 1
    yeildAggregator.save()

    FleetCommanderTemplate.create(vaultAddress)
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
    ark.depositLimit = utils.readValue<BigInt>(
      arkContract.try_depositCap(),
      constants.BigIntConstants.ZERO,
    )

    ark.inputToken = vault.inputToken
    ark.inputTokenBalance = constants.BigIntConstants.ZERO
    ark.totalValueLockedUSD = constants.BigDecimalConstants.ZERO
    ark.cumulativeSupplySideRevenueUSD = constants.BigDecimalConstants.ZERO
    ark.cumulativeProtocolSideRevenueUSD = constants.BigDecimalConstants.ZERO
    ark.cumulativeTotalRevenueUSD = constants.BigDecimalConstants.ZERO
    ark.calculatedApr = constants.BigDecimalConstants.ZERO

    ark.cumulativeEarnings = constants.BigIntConstants.ZERO
    ark.cumulativeDeposits = constants.BigIntConstants.ZERO
    ark.cumulativeWithdrawals = constants.BigIntConstants.ZERO

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
      ? vault.outputTokenSupply!
      : constants.BigIntConstants.ZERO
    vaultSnapshots.outputTokenPriceUSD = vault.outputTokenPriceUSD
      ? vault.outputTokenPriceUSD!
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
