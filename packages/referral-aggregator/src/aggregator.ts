import { ReferralClient } from './client'
import { Account, Position, ReferralData } from './types'

export type AggregatedAccount = {
  id: string
  positions: Position[]
  totalStakedSummerToken: bigint
  totalStakedSummerTokenNormalized: number
  lastUpdateBlock: bigint
  totalClaimedSummerToken: bigint
  totalClaimedSummerTokenNormalized: number
  referralData: ReferralData | null
  referralTimestamp: bigint | null
  chainData: {
    [chain: string]: {
      stakedSummerToken: bigint
      stakedSummerTokenNormalized: number
      claimedSummerToken: bigint
      claimedSummerTokenNormalized: number
      referralData: ReferralData | null
      referralTimestamp: bigint | null
    }
  }
}

export class ReferralAggregator {
  private client: ReferralClient

  constructor() {
    this.client = new ReferralClient()
  }

  async aggregateAccount(accountId: string): Promise<AggregatedAccount | null> {
    const chainData = await this.client.getAllChainData(accountId)
    
    // If no data found on any chain, return null
    if (Object.values(chainData).every(data => !data.account)) {
      return null
    }

    // Initialize aggregated account
    const aggregatedAccount: AggregatedAccount = {
      id: accountId,
      positions: [],
      totalStakedSummerToken: BigInt(0),
      totalStakedSummerTokenNormalized: 0,
      lastUpdateBlock: BigInt(0),
      totalClaimedSummerToken: BigInt(0),
      totalClaimedSummerTokenNormalized: 0,
      referralData: null,
      referralTimestamp: null,
      chainData: {}
    }

    // Process data from each chain
    for (const [chain, data] of Object.entries(chainData)) {
      const { account, positions } = data
      
      if (account) {
        // Add chain-specific data
        aggregatedAccount.chainData[chain] = {
          stakedSummerToken: account.stakedSummerToken,
          stakedSummerTokenNormalized: account.stakedSummerTokenNormalized,
          claimedSummerToken: account.claimedSummerToken,
          claimedSummerTokenNormalized: account.claimedSummerTokenNormalized,
          referralData: account.referralData,
          referralTimestamp: account.referralTimestamp
        }

        // Update totals
        aggregatedAccount.totalStakedSummerToken += account.stakedSummerToken
        aggregatedAccount.totalStakedSummerTokenNormalized += account.stakedSummerTokenNormalized
        aggregatedAccount.totalClaimedSummerToken += account.claimedSummerToken
        aggregatedAccount.totalClaimedSummerTokenNormalized += account.claimedSummerTokenNormalized

        // Update last update block if newer
        if (account.lastUpdateBlock > aggregatedAccount.lastUpdateBlock) {
          aggregatedAccount.lastUpdateBlock = account.lastUpdateBlock
        }

        // Set referral data if not already set (prioritize earliest referral)
        if (account.referralData && (!aggregatedAccount.referralData || 
            (account.referralTimestamp && aggregatedAccount.referralTimestamp && 
             account.referralTimestamp < aggregatedAccount.referralTimestamp))) {
          aggregatedAccount.referralData = account.referralData
          aggregatedAccount.referralTimestamp = account.referralTimestamp
        }
      }

      // Add positions from this chain
      aggregatedAccount.positions = aggregatedAccount.positions.concat(positions)
    }

    return aggregatedAccount
  }
} 