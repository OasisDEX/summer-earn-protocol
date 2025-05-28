import { gql } from 'graphql-request'

export const ACCOUNT_QUERY = gql`
  query GetAccount($id: ID!) {
    account(id: $id) {
      id
      positions {
        id
      }
      stakedSummerToken
      stakedSummerTokenNormalized
      lastUpdateBlock
      claimedSummerToken
      claimedSummerTokenNormalized
      referralData {
        id
        amountOfReferred
      }
      referralTimestamp
    }
  }
`

export const POSITIONS_QUERY = gql`
  query GetPositions($account: String!) {
    positions(where: { account: $account }) {
      id
      account{
      id}
      vault {
        id
      }
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
    }
  }
` 