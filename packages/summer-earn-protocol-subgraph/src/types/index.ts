import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'
import { Token } from '../../generated/schema'

export class VaultAndPositionDetails {
  vaultDetails: VaultDetails
  positionDetails: PositionDetails
}

export class PositionDetails {
  positionId: string
  outputTokenBalance: BigInt
  stakedOutputTokenBalance: BigInt
  inputTokenBalance: BigInt
  inputTokenBalanceNormalized: BigDecimal
  inputTokenBalanceNormalizedUSD: BigDecimal
  stakedInputTokenBalance: BigInt
  stakedInputTokenBalanceNormalized: BigDecimal
  stakedInputTokenBalanceNormalizedUSD: BigDecimal
  vault: string
  account: string
  inputToken: Token
  protocol: string
  constructor(
    positionId: string,
    outputTokenBalance: BigInt,
    stakedOutputTokenBalance: BigInt,
    inputTokenBalance: BigInt,
    inputTokenBalanceNormalized: BigDecimal,
    inputTokenBalanceNormalizedUSD: BigDecimal,
    stakedInputTokenBalance: BigInt,
    stakedInputTokenBalanceNormalized: BigDecimal,
    stakedInputTokenBalanceNormalizedUSD: BigDecimal,
    vault: string,
    account: string,
    inputToken: Token,
    protocol: string,
  ) {
    this.positionId = positionId
    this.outputTokenBalance = outputTokenBalance
    this.stakedOutputTokenBalance = stakedOutputTokenBalance
    this.inputTokenBalance = inputTokenBalance
    this.inputTokenBalanceNormalized = inputTokenBalanceNormalized
    this.inputTokenBalanceNormalizedUSD = inputTokenBalanceNormalizedUSD
    this.stakedInputTokenBalance = stakedInputTokenBalance
    this.stakedInputTokenBalanceNormalized = stakedInputTokenBalanceNormalized
    this.stakedInputTokenBalanceNormalizedUSD = stakedInputTokenBalanceNormalizedUSD
    this.vault = vault
    this.account = account
    this.inputToken = inputToken
    this.protocol = protocol
  }
}
export class VaultDetails {
  vaultId: string
  totalValueLockedUSD: BigDecimal
  pricePerShare: BigDecimal
  inputTokenPriceUSD: BigDecimal
  inputTokenBalance: BigInt
  outputTokenPriceUSD: BigDecimal
  outputTokenSupply: BigInt
  inputToken: Token
  protocol: string
  rewardsManager: Address
  withdrawableTotalAssets: BigInt
  withdrawableTotalAssetsUSD: BigDecimal
  rewardTokenEmissionsAmountsPerOutputToken: BigInt[]
  constructor(
    vaultId: string,
    totalValueLockedUSD: BigDecimal,
    pricePerShare: BigDecimal,
    inputTokenPriceUSD: BigDecimal,
    inputTokenBalance: BigInt,
    outputTokenPriceUSD: BigDecimal,
    outputTokenSupply: BigInt,
    inputToken: Token,
    protocol: string,
    rewardsManager: Address,
    withdrawableTotalAssets: BigInt,
    withdrawableTotalAssetsUSD: BigDecimal,
    rewardTokenEmissionsAmountsPerOutputToken: BigInt[],
  ) {
    this.vaultId = vaultId
    this.totalValueLockedUSD = totalValueLockedUSD
    this.pricePerShare = pricePerShare
    this.inputTokenPriceUSD = inputTokenPriceUSD
    this.inputTokenBalance = inputTokenBalance
    this.outputTokenPriceUSD = outputTokenPriceUSD
    this.outputTokenSupply = outputTokenSupply
    this.inputToken = inputToken
    this.protocol = protocol
    this.rewardsManager = rewardsManager
    this.withdrawableTotalAssets = withdrawableTotalAssets
    this.withdrawableTotalAssetsUSD = withdrawableTotalAssetsUSD
    this.rewardTokenEmissionsAmountsPerOutputToken = rewardTokenEmissionsAmountsPerOutputToken
  }
}

export class ArkDetails {
  arkId: string
  vaultId: string
  inputTokenBalance: BigInt
  totalValueLockedUSD: BigDecimal
  constructor(
    arkId: string,
    vaultId: string,
    inputTokenBalance: BigInt,
    totalValueLockedUSD: BigDecimal,
  ) {
    this.arkId = arkId
    this.vaultId = vaultId
    this.inputTokenBalance = inputTokenBalance
    this.totalValueLockedUSD = totalValueLockedUSD
  }
}
