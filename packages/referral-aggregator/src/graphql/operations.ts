import { gql } from 'graphql-request'

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
      lastUpdateBlock
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
        referralData {
          id
          amountOfReferred
        }
        createdTimestamp
        hourlySnapshots(first: 1000, orderBy: timestamp, orderDirection: desc) {
          id
          timestamp
          inputTokenBalanceNormalizedInUSD
        }
      }
    }
  }
`
// todo: add pagination
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

// New query specifically for getting hourly snapshots for a time range
export const ACCOUNTS_WITH_HOURLY_SNAPSHOTS_QUERY = gql`
  query GetAccountsWithHourlySnapshots(
    $accountIds: [ID!]!
    $timestampGt: BigInt!
    $timestampLt: BigInt!
    $first: Int!
    $lastId: ID
  ) {
    accounts(orderBy: id, first: $first, where: { id_in: $accountIds, id_gt: $lastId }) {
      id
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
        createdTimestamp
        referralData {
          id
          amountOfReferred
        }
        hourlySnapshots(
          where: { timestamp_gt: $timestampGt, timestamp_lte: $timestampLt }
          orderBy: timestamp
          orderDirection: desc
        ) {
          id
          timestamp
          inputTokenBalanceNormalizedInUSD
        }
      }
    }
  }
`

// Query for hourly position snapshots - updated to be more specific
export const POSITION_HOURLY_SNAPSHOTS_QUERY = gql`
  query GetPositionHourlySnapshots(
    $timestampGt: BigInt!
    $timestampLt: BigInt!
    $first: Int!
    $skip: Int!
  ) {
    positionHourlySnapshots(
      where: { timestamp_gt: $timestampGt, timestamp_lt: $timestampLt }
      orderBy: timestamp
      first: $first
      skip: $skip
    ) {
      id
      position {
        id
        account {
          id
          referralData {
            id
          }
          referralTimestamp
        }
      }
      inputTokenBalanceNormalizedInUSD
      timestamp
    }
  }
`
