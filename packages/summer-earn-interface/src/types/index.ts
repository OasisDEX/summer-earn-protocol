export type ChainId = '1' | '42161' | '8453' | '146'

export interface TokenInfo {
  address: string
  symbol: string
  decimals: number
}

export interface FleetCommanderInfo {
  address: string
  name: string
  symbol: string
  asset: string
  totalAssets: bigint
  withdrawableTotalAssets: bigint
  depositCap: bigint
  assetDecimals: number
  assetSymbol: string
}

export interface ArkInfo {
  address: string
  totalAssets: bigint
  withdrawableTotalAssets: bigint
  name: string
}

export interface RebalanceData {
  fromArk: `0x${string}`
  toArk: `0x${string}`
  amount: bigint
  boardData: `0x${string}`
  disembarkData: `0x${string}`
}

export interface UserFleetInfo {
  balance: bigint
  allowance: bigint
  underlyingBalance: bigint
}
