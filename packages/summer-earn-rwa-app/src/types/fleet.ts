// Lifted from summer-earn-interface/src/types/index.ts. Same shape; only
// the slice we actually consume in rwa-app.

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
  minimumBufferBalance: bigint
  maxRebalanceOperations: bigint
  assetDecimals: number
  assetSymbol: string
  fleetDecimals: number
}

export interface ArkInfo {
  address: string
  totalAssets: bigint
  withdrawableTotalAssets: bigint
  name: string
  isBufferArk?: boolean
  depositCap: bigint
  maxDepositPercentageOfTVL: bigint
  maxRebalanceInflow: bigint
  maxRebalanceOutflow: bigint
  withdrawalRequestId?: string
  assetsInWithdrawalQueue?: string
  isWithdrawalClaimRequired?: boolean
  assetBalance?: string
  hasWithdrawalQueue?: boolean
  needsSweep?: boolean
  pendingDepositAssets?: string
  sharesToAssets1e18?: string
}

export interface UserFleetInfo {
  balance: bigint
  allowance: bigint
  underlyingBalance: bigint
}

export interface RebalanceData {
  fromArk: `0x${string}`
  toArk: `0x${string}`
  amount: bigint
  boardData: `0x${string}`
  disembarkData: `0x${string}`
}

export type GlobalRole =
  | 'GOVERNOR_ROLE'
  | 'SUPER_KEEPER_ROLE'
  | 'GUARDIAN_ROLE'
  | 'DECAY_CONTROLLER_ROLE'
  | 'ADMIRALS_QUARTERS_ROLE'
  | 'FOUNDATION_ROLE'
  | 'WHITELIST_MANAGER_ROLE'

export type ContractRole = 'CURATOR_ROLE' | 'KEEPER_ROLE' | 'COMMANDER_ROLE' | 'OPERATOR_ROLE'
