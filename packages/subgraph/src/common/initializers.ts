import { Address, BigInt, ethereum, log } from '@graphprotocol/graph-ts'
import { ERC20 as ERC20Contract } from '../../generated/FleetCommanderFactory/ERC20'
import {
  Account,
  FinancialsDailySnapshot,
  Position,
  Token,
  UsageMetricsDailySnapshot,
  UsageMetricsHourlySnapshot,
  VaultDailySnapshot,
  VaultHourlySnapshot,
  Vault as VaultStore,
  YieldAggregator,
} from '../../generated/schema'
import { FleetCommanderTemplate } from '../../generated/templates'
import { FleetCommander as FleetCommanderContract } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import * as constants from './constants'
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
    protocol.totalValueLockedUSD = constants.BIGDECIMAL_ZERO
    protocol.protocolControlledValueUSD = constants.BIGDECIMAL_ZERO
    protocol.cumulativeSupplySideRevenueUSD = constants.BIGDECIMAL_ZERO
    protocol.cumulativeProtocolSideRevenueUSD = constants.BIGDECIMAL_ZERO
    protocol.cumulativeTotalRevenueUSD = constants.BIGDECIMAL_ZERO
    protocol.cumulativeUniqueUsers = 0
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

    financialMetrics.totalValueLockedUSD = constants.BIGDECIMAL_ZERO
    financialMetrics.dailySupplySideRevenueUSD = constants.BIGDECIMAL_ZERO
    financialMetrics.cumulativeSupplySideRevenueUSD = constants.BIGDECIMAL_ZERO
    financialMetrics.dailyProtocolSideRevenueUSD = constants.BIGDECIMAL_ZERO
    financialMetrics.cumulativeProtocolSideRevenueUSD = constants.BIGDECIMAL_ZERO

    financialMetrics.dailyTotalRevenueUSD = constants.BIGDECIMAL_ZERO
    financialMetrics.cumulativeTotalRevenueUSD = constants.BIGDECIMAL_ZERO

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

export function getOrCreateVaultsDailySnapshots(
  vaultAddress: Address,
  block: ethereum.Block,
): VaultDailySnapshot {
  const vault = getOrCreateVault(vaultAddress, block)
  const previousId: string = vault.id
    .concat('-')
    .concat(((block.timestamp.toI64() - constants.SECONDS_PER_DAY) / constants.SECONDS_PER_DAY).toString())
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
      : constants.BIGDECIMAL_ZERO
    vaultSnapshots.pricePerShare = vault.pricePerShare
      ? vault.pricePerShare!
      : constants.BIGDECIMAL_ZERO
    vaultSnapshots.apr = !previousSnapshot
      ? constants.BIGDECIMAL_ZERO
      : utils.getAprForTimePeriod(
        previousSnapshot.pricePerShare!,
        vault.pricePerShare!,
        constants.BigDecimalConstants.DAY_IN_SECONDS,
      )
    vaultSnapshots.dailySupplySideRevenueUSD = constants.BIGDECIMAL_ZERO
    vaultSnapshots.cumulativeSupplySideRevenueUSD = vault.cumulativeSupplySideRevenueUSD

    vaultSnapshots.dailyProtocolSideRevenueUSD = constants.BIGDECIMAL_ZERO
    vaultSnapshots.cumulativeProtocolSideRevenueUSD = vault.cumulativeProtocolSideRevenueUSD

    vaultSnapshots.dailyTotalRevenueUSD = constants.BIGDECIMAL_ZERO
    vaultSnapshots.cumulativeTotalRevenueUSD = vault.cumulativeTotalRevenueUSD

    vaultSnapshots.blockNumber = block.number
    vaultSnapshots.timestamp = block.timestamp

    vaultSnapshots.save()
  }
  ; ``

  return vaultSnapshots
}

export function getOrCreateVaultsHourlySnapshots(
  vaultAddress: Address,
  block: ethereum.Block,
): VaultHourlySnapshot {
  const vault = getOrCreateVault(vaultAddress, block)
  const id: string = vault.id
    .concat('-')
    .concat((block.timestamp.toI64() / constants.SECONDS_PER_HOUR).toString())
  const previousId = vault.id
    .concat('-')
    .concat(((block.timestamp.toI64() - constants.SECONDS_PER_HOUR) / constants.SECONDS_PER_HOUR).toString())
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
      : constants.BIGDECIMAL_ZERO
    vaultSnapshots.pricePerShare = vault.pricePerShare
      ? vault.pricePerShare!
      : constants.BIGDECIMAL_ZERO
    vaultSnapshots.apr = !previousSnapshot
      ? constants.BIGDECIMAL_ZERO
      : utils.getAprForTimePeriod(
        previousSnapshot.pricePerShare!,
        vault.pricePerShare!,
        constants.BigDecimalConstants.HOUR_IN_SECONDS,
      )
    vaultSnapshots.hourlySupplySideRevenueUSD = constants.BIGDECIMAL_ZERO
    vaultSnapshots.cumulativeSupplySideRevenueUSD = vault.cumulativeSupplySideRevenueUSD

    vaultSnapshots.hourlyProtocolSideRevenueUSD = constants.BIGDECIMAL_ZERO
    vaultSnapshots.cumulativeProtocolSideRevenueUSD = vault.cumulativeProtocolSideRevenueUSD

    vaultSnapshots.hourlyTotalRevenueUSD = constants.BIGDECIMAL_ZERO
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
    vault.depositLimit = utils.readValue<BigInt>(
      vaultContract.try_depositCap(),
      constants.BigIntConstants.ZERO,
    )

    const inputToken = getOrCreateToken(vaultContract.asset())
    vault.inputToken = inputToken.id
    vault.inputTokenBalance = constants.BigIntConstants.ZERO

    const outputToken = getOrCreateToken(vaultAddress)
    vault.outputToken = outputToken.id
    vault.outputTokenSupply = constants.BigIntConstants.ZERO

    vault.outputTokenPriceUSD = constants.BIGDECIMAL_ZERO
    vault.pricePerShare = constants.BIGDECIMAL_ZERO

    vault.createdBlockNumber = block.number
    vault.createdTimestamp = block.timestamp

    vault.totalValueLockedUSD = constants.BIGDECIMAL_ZERO

    vault.cumulativeSupplySideRevenueUSD = constants.BIGDECIMAL_ZERO
    vault.cumulativeProtocolSideRevenueUSD = constants.BIGDECIMAL_ZERO
    vault.cumulativeTotalRevenueUSD = constants.BIGDECIMAL_ZERO
    vault.apr = constants.BIGDECIMAL_ZERO
    vault.lastUpdateTimestamp = block.timestamp

    const managementFeeId =
      utils.enumToPrefix(constants.VaultFeeType.MANAGEMENT_FEE) + vaultAddress.toHexString()
    const managementFee = BigInt.fromI32(0)
    utils.createFeeType(managementFeeId, constants.VaultFeeType.MANAGEMENT_FEE, managementFee)

    const performanceFeeId =
      utils.enumToPrefix(constants.VaultFeeType.PERFORMANCE_FEE) + vaultAddress.toHexString()
    const performanceFee = BigInt.fromI32(0)
    utils.createFeeType(performanceFeeId, constants.VaultFeeType.PERFORMANCE_FEE, performanceFee)

    vault.fees = [managementFeeId, performanceFeeId]

    vault.save()

    FleetCommanderTemplate.create(vaultAddress)


    const yeildAggregator = getOrCreateYieldAggregator()
    const vaultsArray = yeildAggregator.vaultsArray
    vaultsArray.push(vault.id)
    yeildAggregator.vaultsArray = vaultsArray
    yeildAggregator.totalPoolCount = yeildAggregator.totalPoolCount + 1
    yeildAggregator.save()
  }

  return vault
}
