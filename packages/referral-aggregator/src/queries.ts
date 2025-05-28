export const ACCOUNT_QUERY = `
  query GetAccount($id: ID!) {
    account(id: $id) {
      id
      stakedSummerToken
      stakedSummerTokenNormalized
      lastUpdateBlock
      claimedSummerToken
      claimedSummerTokenNormalized
      referralData {
        id
        amountOfReferred
        protocol
      }
      referralTimestamp
    }
  }
`

export const POSITIONS_QUERY = `
  query GetPositions($account: String!) {
    positions(where: { account: $account }) {
      id
      account
      vault
      inputTokenDeposits
      inputTokenDepositsNormalized
      inputTokenWithdrawalsNormalized
      inputTokenDepositsNormalizedInUSD
      inputTokenWithdrawals
      inputTokenWithdrawalsNormalizedInUSD
      inputTokenBalance
      outputTokenBalance
      stakedInputTokenBalance
      stakedOutputTokenBalance
      unstakedInputTokenBalance
      unstakedOutputTokenBalance
      inputTokenBalanceNormalized
      stakedInputTokenBalanceNormalized
      unstakedInputTokenBalanceNormalized
      inputTokenBalanceNormalizedInUSD
      stakedInputTokenBalanceNormalizedInUSD
      unstakedInputTokenBalanceNormalizedInUSD
      createdTimestamp
      createdBlockNumber
      claimedSummerToken
      claimedSummerTokenNormalized
      claimableSummerToken
      claimableSummerTokenNormalized
      referralData {
        id
        amountOfReferred
        protocol
      }
    }
  }
` 