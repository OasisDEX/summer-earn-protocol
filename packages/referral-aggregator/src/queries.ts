import { gql } from 'graphql-tag'

export const ACCOUNT_QUERY = `
  query GetAccount($id: ID!) {
    account(id: $id) {
      id
      referralData {
        id
      }
      referralTimestamp
    }
  }
`

export const ACCOUNTS_QUERY = gql`
  query GetAccounts($where: Account_filter!, $first: Int!, $lastId: ID) {
    accounts(orderBy: id, first: $first, where: $where) {
      id
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

export const REFERRED_ACCOUNTS_QUERY = gql`
  query GetReferredAccounts($timestampGt: BigInt, $timestampLt: BigInt) {
    accounts(
      where: { referralTimestamp_gt: $timestampGt, referralTimestamp_lt: $timestampLt }
      orderBy: id
      first: 1000
    ) {
      id
      referralTimestamp
      referralData {
        id
        amountOfReferred
      }
    }
  }
`

export const POSITIONS_QUERY = `
  query GetPositions($where: Position_filter) {
    positions(where: $where) {
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

export const ACCOUNTS_WITH_POSITIONS_QUERY = gql`
  query GetAccountsWithPositions($accountIds: [ID!]!, $first: Int!, $lastId: ID) {
    accounts(orderBy: id, first: $first, where: { id_in: $accountIds, id_gt: $lastId }) {
      id
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
      positions(first: 50, orderBy: createdTimestamp) {
        id
        account {
          id
        }
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
        referralData {
          id
          amountOfReferred
        }
        createdTimestamp
      }
    }
  }
`

export const VALIDATE_POSITIONS_QUERY = gql`
  query ValidatePositions($accountIds: [ID!]!) {
    accounts(where: { id_in: $accountIds }) {
      id
      referralTimestamp
      positions(first: 1, orderBy: createdTimestamp, orderDirection: asc) {
        id
        createdTimestamp
      }
    }
  }
`
