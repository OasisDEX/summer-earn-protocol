import { Account as GeneratedAccount, Position as GeneratedPosition, ReferralData as GeneratedReferralData } from './generated/graphql'

// Remove Maybe<T> and make fields non-nullable where we know they exist
export type Account = {
  id: string
  positions: { id: string }[]
  stakedSummerToken: bigint
  stakedSummerTokenNormalized: number
  lastUpdateBlock: bigint
  claimedSummerToken: bigint
  claimedSummerTokenNormalized: number
  referralData: ReferralData | null
  referralTimestamp: bigint | null
}

export type Position = {
  id: string
  account: { id: string }
  vault: { id: string }
  inputTokenDeposits: bigint
  inputTokenDepositsNormalized: number
  inputTokenWithdrawalsNormalized: number
  inputTokenDepositsNormalizedInUSD: number
  inputTokenWithdrawals: bigint
  inputTokenWithdrawalsNormalizedInUSD: number
  inputTokenBalance: bigint
  outputTokenBalance: bigint
  stakedInputTokenBalance: bigint
  stakedOutputTokenBalance: bigint
  unstakedInputTokenBalance: bigint
  unstakedOutputTokenBalance: bigint
  inputTokenBalanceNormalized: number
  stakedInputTokenBalanceNormalized: number
  unstakedInputTokenBalanceNormalized: number
  inputTokenBalanceNormalizedInUSD: number
  stakedInputTokenBalanceNormalizedInUSD: number
  unstakedInputTokenBalanceNormalizedInUSD: number
  createdTimestamp: bigint
  createdBlockNumber: bigint
  claimedSummerToken: bigint
  claimedSummerTokenNormalized: number
  claimableSummerToken: bigint
  claimableSummerTokenNormalized: number
  depositAmountUsd: bigint
  createdAt: bigint
  referralData: ReferralData | null
}

export type ReferralData = {
  id: string
  amountOfReferred: bigint
}

export type Chain = 'Ethereum' | 'Polygon' | 'Arbitrum' | 'Base'

// Helper function to convert generated types to our types
export function convertAccount(account: GeneratedAccount | null | undefined): Account | null {
  if (!account) return null
  return {
    id: account.id,
    positions: account.positions.map(p => ({ id: p.id })),
    stakedSummerToken: BigInt(account.stakedSummerToken),
    stakedSummerTokenNormalized: Number(account.stakedSummerTokenNormalized),
    lastUpdateBlock: BigInt(account.lastUpdateBlock),
    claimedSummerToken: BigInt(account.claimedSummerToken),
    claimedSummerTokenNormalized: Number(account.claimedSummerTokenNormalized),
    referralData: account.referralData ? convertReferralData(account.referralData) : null,
    referralTimestamp: account.referralTimestamp ? BigInt(account.referralTimestamp) : null
  }
}

export function convertPosition(position: GeneratedPosition | null | undefined): Position | null {
  if (!position) return null
  return {
    id: position.id,
    account: { id: position.account.id },
    vault: { id: position.vault.id },
    inputTokenDeposits: BigInt(position.inputTokenDeposits),
    inputTokenDepositsNormalized: Number(position.inputTokenDepositsNormalized),
    inputTokenWithdrawalsNormalized: Number(position.inputTokenWithdrawalsNormalized),
    inputTokenDepositsNormalizedInUSD: Number(position.inputTokenDepositsNormalizedInUSD),
    inputTokenWithdrawals: BigInt(position.inputTokenWithdrawals),
    inputTokenWithdrawalsNormalizedInUSD: Number(position.inputTokenWithdrawalsNormalizedInUSD),
    inputTokenBalance: BigInt(position.inputTokenBalance),
    outputTokenBalance: BigInt(position.outputTokenBalance),
    stakedInputTokenBalance: BigInt(position.stakedInputTokenBalance),
    stakedOutputTokenBalance: BigInt(position.stakedOutputTokenBalance),
    unstakedInputTokenBalance: BigInt(position.unstakedInputTokenBalance),
    unstakedOutputTokenBalance: BigInt(position.unstakedOutputTokenBalance),
    inputTokenBalanceNormalized: Number(position.inputTokenBalanceNormalized),
    stakedInputTokenBalanceNormalized: Number(position.stakedInputTokenBalanceNormalized),
    unstakedInputTokenBalanceNormalized: Number(position.unstakedInputTokenBalanceNormalized),
    inputTokenBalanceNormalizedInUSD: Number(position.inputTokenBalanceNormalizedInUSD),
    stakedInputTokenBalanceNormalizedInUSD: Number(position.stakedInputTokenBalanceNormalizedInUSD),
    unstakedInputTokenBalanceNormalizedInUSD: Number(position.unstakedInputTokenBalanceNormalizedInUSD),
    createdTimestamp: BigInt(position.createdTimestamp),
    createdBlockNumber: BigInt(position.createdBlockNumber),
    claimedSummerToken: BigInt(position.claimedSummerToken),
    claimedSummerTokenNormalized: Number(position.claimedSummerTokenNormalized),
    claimableSummerToken: BigInt(position.claimableSummerToken),
    claimableSummerTokenNormalized: Number(position.claimableSummerTokenNormalized),
    depositAmountUsd: BigInt(position.inputTokenBalanceNormalizedInUSD),
    createdAt: BigInt(position.createdTimestamp),
    referralData: position.referralData ? convertReferralData(position.referralData) : null
  }
}

export function convertReferralData(data: GeneratedReferralData | null | undefined): ReferralData | null {
  if (!data) return null
  return {
    id: data.id,
    amountOfReferred: BigInt(data.amountOfReferred)
  }
} 