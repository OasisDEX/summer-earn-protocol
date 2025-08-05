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
  fleetDecimals: number
}

export interface ArkInfo {
  address: string
  totalAssets: bigint
  withdrawableTotalAssets: bigint
  name: string
  isBufferArk?: boolean
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

// Role Management Types
export type GlobalRole =
  | 'GOVERNOR_ROLE'
  | 'SUPER_KEEPER_ROLE'
  | 'GUARDIAN_ROLE'
  | 'DECAY_CONTROLLER_ROLE'
  | 'ADMIRALS_QUARTERS_ROLE'
  | 'FOUNDATION_ROLE'

export type FleetRole = 'CURATOR_ROLE' | 'KEEPER_ROLE'

export type ArkRole = 'COMMANDER_ROLE'

export interface RoleAction {
  role: GlobalRole | FleetRole | ArkRole
  action: 'grant' | 'revoke'
  address: string
  targetContract?: string // For fleet/ark specific roles
}

export interface GuardianInfo {
  address: string
  expiration: bigint
  isActive: boolean
}

// Staking Types
export interface StakingInfo {
  stakingRewardsManagerAddress?: string
  stakedBalance: bigint
  totalStakedSupply: bigint
  earnedRewards: bigint
  rewardTokens: string[]
}

export interface RewardTokenInfo {
  address: string
  symbol: string
  decimals: number
  earned: bigint
  rewardRate: bigint
}
