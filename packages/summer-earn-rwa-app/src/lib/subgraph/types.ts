// TS mirrors of the v2 institutions subgraph (schema in
// packages/summer-earn-institutions-v2-subgraph/schema.graphql). BigInt
// fields arrive as strings — consumers convert with BigInt(...).

export type RoundState = 'OPENED' | 'IN_SETTLEMENT' | 'SETTLED' | 'ROLLED_BACK'
export type RoundsVaultFlavor = 'INPUT' | 'OUTPUT'
export type TransferKind = 'MINT' | 'BURN' | 'TRANSFER' | 'REDEEM'
export type RoleAction = 'GRANT_ROLE' | 'REVOKE_ROLE'

export interface SubgraphToken {
  id: string
  symbol: string
  decimals: number
  name?: string
}

export interface SubgraphRound {
  id: string
  roundId: string
  state: RoundState
  openedAt: string
  openedAtBlock: string
  closedAt?: string | null
  closedAtBlock?: string | null
  settledAt?: string | null
  settledAtBlock?: string | null
  exchangeRateBase?: string | null
  exchangeRateQuote?: string | null
  exchangeRateDecimal?: string | null
  totalReceiptSupplyAtClose?: string | null
  inputAssetsDeposited?: string | null
  inputSharesReceived?: string | null
  outputSharesRedeemed?: string | null
  outputAssetsReturned?: string | null
  retriedCount: string
  rolledBack: boolean
}

export interface SubgraphRoundsVault {
  id: string
  flavor: RoundsVaultFlavor
  underlyingToken: SubgraphToken
  exchangeAssetToken: SubgraphToken
  currentRound: string
  minPositionSize: string
  cumulativeDepositsQueued: string
  cumulativeExchangeAssetWithdrawn: string
  currentRoundReceiptSupply: string
  pendingSettlementAmount: string
  createdAt: string
  createdAtBlock: string
  pair?: {
    id: string
    active: boolean
    targetVault: { id: string; name?: string }
  }
  rounds?: SubgraphRound[]
}

export interface SubgraphRoundsVaultPair {
  id: string
  active: boolean
  institutionId: string
  registeredAt: string
  registeredAtBlock: string
  lastUpdated: string
  targetVault: { id: string; name?: string; symbol?: string }
  inputVault?: SubgraphRoundsVault | null
  outputVault?: SubgraphRoundsVault | null
}

export interface SubgraphReceipt {
  id: string
  balance: string
  totalMinted: string
  totalBurned: string
  totalRedeemedForExchangeAsset: string
  exchangeAssetReceived: string
  lastUpdated: string
  lastUpdatedBlock: string
  round: SubgraphRound
  vault: SubgraphRoundsVault
}

export interface SubgraphRoleEvent {
  id: string
  hash: string
  action: RoleAction
  caller: string
  timestamp: string
  blockNumber: string
}

export interface SubgraphRole {
  id: string
  name: string
  owner: string
  targetContract: string
  accessController: string
  createdTimestamp: string
  createdBlockNumber: string
  active: boolean
  events?: SubgraphRoleEvent[]
}

export interface SubgraphVault {
  id: string
  name: string
  symbol: string
  details?: string | null
  isWhitelistOpen: boolean
  depositCap?: string | null
  minimumBufferBalance?: string | null
  tipRate?: string | null
  inputToken: SubgraphToken
  totalValueLockedUSD?: string | null
  pricePerShare?: string | null
  calculatedApr?: string | null
  apr7d?: string | null
  apr30d?: string | null
  apr90d?: string | null
  arks?: Array<{
    id: string
    productId?: string | null
    name?: string | null
    depositCap?: string | null
    inputToken?: SubgraphToken
  }>
  bufferArk?: { id: string } | null
  roundsVaultPair?: SubgraphRoundsVaultPair | null
}

export interface SubgraphInstitution {
  id: string
  active: boolean
  configurationManager: string
  protocolAccessManager: string
  admiralsQuarters: string
  harborCommand: string
  createdTimestamp: string
  createdBlockNumber: string
  vaults?: SubgraphVault[]
  roles?: SubgraphRole[]
}

export interface SubgraphRebalance {
  id: string
  hash: string
  timestamp: string
  amount: string
  amountUSD?: string | null
  asset: SubgraphToken
  from: { id: string; productId?: string | null; name?: string | null }
  to: { id: string; productId?: string | null; name?: string | null }
  fromPostAction?: { totalValueLockedUSD?: string | null; inputTokenBalance?: string | null } | null
  toPostAction?: { totalValueLockedUSD?: string | null; inputTokenBalance?: string | null } | null
}
