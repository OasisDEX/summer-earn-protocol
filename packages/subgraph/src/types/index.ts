import { BigInt, BigDecimal } from '@graphprotocol/graph-ts'
import { Token } from '../../generated/schema'

export class VaultAndPositionDetails {
  vaultDetails: VaultDetails
  positionDetails: PositionDetails
}

export class PositionDetails {
  positionId: string
  outputTokenBalance: BigInt
  inputTokenBalance: BigInt
  inputTokenBalanceNormalized: BigDecimal
  inputTokenBalanceNormalizedUSD: BigDecimal
  vault: string
  account: string
  inputToken: Token
  protocol: string
  constructor(
    positionId: string,
    outputTokenBalance: BigInt,
    inputTokenBalance: BigInt,
    inputTokenBalanceNormalized: BigDecimal,
    inputTokenBalanceNormalizedUSD: BigDecimal,
    vault: string,
    account: string,
    inputToken: Token,
    protocol: string,
  ) {
    this.positionId = positionId
    this.outputTokenBalance = outputTokenBalance
    this.inputTokenBalance = inputTokenBalance
    this.inputTokenBalanceNormalized = inputTokenBalanceNormalized
    this.inputTokenBalanceNormalizedUSD = inputTokenBalanceNormalizedUSD
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
  }
}
