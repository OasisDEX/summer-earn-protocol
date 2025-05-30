export type Chain = 'Ethereum' | 'Sonic' | 'Arbitrum' | 'Base'

export interface ReferralData {
  id: string
  amountOfReferred?: string
  protocol?: string
}

export interface HourlySnapshot {
  id: string
  timestamp: string
  inputTokenBalanceNormalizedInUSD: string
  stakedInputTokenBalanceNormalizedInUSD?: string
  unstakedInputTokenBalanceNormalizedInUSD?: string
}

export interface Position {
  id: string
  account?: {
    id: string
  }
  vault?: {
    id: string
  }
  inputTokenDeposits?: string
  inputTokenDepositsNormalized?: string
  inputTokenWithdrawalsNormalized?: string
  inputTokenDepositsNormalizedInUSD?: string
  inputTokenWithdrawals?: string
  inputTokenWithdrawalsNormalizedInUSD?: string
  inputTokenBalance?: string
  outputTokenBalance?: string
  stakedInputTokenBalance?: string
  stakedOutputTokenBalance?: string
  unstakedInputTokenBalance?: string
  unstakedOutputTokenBalance?: string
  inputTokenBalanceNormalized?: string
  stakedInputTokenBalanceNormalized?: string
  unstakedInputTokenBalanceNormalized?: string
  inputTokenBalanceNormalizedInUSD?: string
  stakedInputTokenBalanceNormalizedInUSD?: string
  unstakedInputTokenBalanceNormalizedInUSD?: string
  createdTimestamp: string
  createdBlockNumber?: string
  referralData?: ReferralData
  hourlySnapshots?: HourlySnapshot[]
}

export interface Account {
  id: string
  lastUpdateBlock?: string
  referralData?: ReferralData
  referralTimestamp?: string
  positions?: Position[]
  referralChain?: Chain
}

export function convertAccount(account: any): Account {
  return {
    id: account.id,
    lastUpdateBlock: account.lastUpdateBlock,
    referralData: account.referralData,
    referralTimestamp: account.referralTimestamp,
    positions: account.positions?.map((p: any) => convertPosition(p)),
  }
}

export function convertPosition(position: any): Position {
  return {
    id: position.id,
    account: position.account,
    vault: position.vault,
    inputTokenDeposits: position.inputTokenDeposits,
    inputTokenDepositsNormalized: position.inputTokenDepositsNormalized,
    inputTokenWithdrawalsNormalized: position.inputTokenWithdrawalsNormalized,
    inputTokenDepositsNormalizedInUSD: position.inputTokenDepositsNormalizedInUSD,
    inputTokenWithdrawals: position.inputTokenWithdrawals,
    inputTokenWithdrawalsNormalizedInUSD: position.inputTokenWithdrawalsNormalizedInUSD,
    inputTokenBalance: position.inputTokenBalance,
    outputTokenBalance: position.outputTokenBalance,
    stakedInputTokenBalance: position.stakedInputTokenBalance,
    stakedOutputTokenBalance: position.stakedOutputTokenBalance,
    unstakedInputTokenBalance: position.unstakedInputTokenBalance,
    unstakedOutputTokenBalance: position.unstakedOutputTokenBalance,
    inputTokenBalanceNormalized: position.inputTokenBalanceNormalized,
    stakedInputTokenBalanceNormalized: position.stakedInputTokenBalanceNormalized,
    unstakedInputTokenBalanceNormalized: position.unstakedInputTokenBalanceNormalized,
    inputTokenBalanceNormalizedInUSD: position.inputTokenBalanceNormalizedInUSD,
    stakedInputTokenBalanceNormalizedInUSD: position.stakedInputTokenBalanceNormalizedInUSD,
    unstakedInputTokenBalanceNormalizedInUSD: position.unstakedInputTokenBalanceNormalizedInUSD,
    createdTimestamp: position.createdTimestamp,
    referralData: position.referralData,
    hourlySnapshots: position.hourlySnapshots?.map((s: any) => convertHourlySnapshot(s)),
  }
}

export function convertHourlySnapshot(snapshot: any): HourlySnapshot {
  return {
    id: snapshot.id,
    timestamp: snapshot.timestamp,
    inputTokenBalanceNormalizedInUSD: snapshot.inputTokenBalanceNormalizedInUSD,
    stakedInputTokenBalanceNormalizedInUSD: snapshot.stakedInputTokenBalanceNormalizedInUSD,
    unstakedInputTokenBalanceNormalizedInUSD: snapshot.unstakedInputTokenBalanceNormalizedInUSD,
  }
}
