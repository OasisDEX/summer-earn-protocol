import { GraphQLClient } from 'graphql-request'
import {
  GetAccountsQuery,
  GetReferredAccountsQuery,
  ValidatePositionsQuery,
} from './generated/graphql'
import {
  ACCOUNTS_QUERY,
  ACCOUNTS_WITH_HOURLY_SNAPSHOTS_QUERY,
  ACCOUNTS_WITH_POSITIONS_QUERY,
  REFERRED_ACCOUNTS_QUERY,
  VALIDATE_POSITIONS_QUERY,
} from './graphql/operations'
import { Account, convertAccount } from './types'

const CHAINS = ['Ethereum', 'Sonic', 'Arbitrum', 'Base'] as const
type Chain = (typeof CHAINS)[number]

const SUBGRAPH_URLS: Record<Chain, string> = {
  Ethereum: 'https://subgraph.staging.oasisapp.dev/summer-protocol',
  Sonic: 'https://subgraph.staging.oasisapp.dev/summer-protocol-sonic',
  Arbitrum: 'https://subgraph.staging.oasisapp.dev/summer-protocol-arbitrum',
  Base: 'https://subgraph.staging.oasisapp.dev/summer-protocol-base',
}

export interface ReferredAccountsOptions {
  timestampGt?: bigint
  timestampLt?: bigint
}

export interface PaginationOptions {
  first: number
  lastId?: string
}

export interface HourlySnapshotOptions {
  timestampGt: bigint
  timestampLt: bigint
}

export class ReferralClient {
  private clients: Record<Chain, GraphQLClient>

  constructor() {
    this.clients = CHAINS.reduce(
      (acc, chain) => {
        acc[chain] = new GraphQLClient(SUBGRAPH_URLS[chain])
        return acc
      },
      {} as Record<Chain, GraphQLClient>,
    )
  }

  async getReferredAccounts(
    chain: Chain,
    options: ReferredAccountsOptions = {},
  ): Promise<Account[]> {
    try {
      const variables: any = {}
      variables.timestampGt = options.timestampGt ? options.timestampGt.toString() : '0'
      variables.timestampLt = options.timestampLt
        ? options.timestampLt.toString()
        : '99999999999999999999'
      const data = await this.clients[chain].request<GetReferredAccountsQuery>(
        REFERRED_ACCOUNTS_QUERY,
        variables,
      )
      return data.accounts.filter(Boolean).map((a) => convertAccount(a as any)) as Account[]
    } catch (error) {
      console.error(`Error fetching referred accounts from ${chain}:`, error)
      return []
    }
  }

  async getAccounts(
    chain: Chain,
    addresses: string[],
    pagination: PaginationOptions,
  ): Promise<Account[]> {
    try {
      const lowercasedAddresses = addresses.map((a) => a.toLowerCase())
      const where: any = { id_in: lowercasedAddresses }
      if (pagination.lastId) {
        where.id_gt = pagination.lastId
      }

      const data = await this.clients[chain].request<GetAccountsQuery>(ACCOUNTS_QUERY, {
        where,
        first: pagination.first,
        lastId: pagination.lastId,
      })
      return data.accounts.filter(Boolean).map((a) => convertAccount(a as any)) as Account[]
    } catch (error) {
      console.error(`Error fetching accounts from ${chain}:`, error)
      return []
    }
  }

  async getAccountsWithPositions(
    chain: Chain,
    accountIds: string[],
    pagination: PaginationOptions,
  ): Promise<Account[]> {
    try {
      const lowercasedIds = accountIds.map((id) => id.toLowerCase())
      const variables: any = {
        accountIds: lowercasedIds,
        first: pagination.first,
      }
      if (pagination.lastId) {
        variables.lastId = pagination.lastId
      } else {
        variables.lastId = ''
      }

      const data = (await this.clients[chain].request(
        ACCOUNTS_WITH_POSITIONS_QUERY,
        variables,
      )) as any
      return data.accounts.filter(Boolean).map((a: any) => convertAccount(a)) as Account[]
    } catch (error) {
      console.error(`Error fetching accounts with positions from ${chain}:`, error)
      return []
    }
  }

  // New method to get accounts with hourly snapshots for specific time range
  async getAccountsWithHourlySnapshots(
    chain: Chain,
    accountIds: string[],
    pagination: PaginationOptions,
    snapshotOptions: HourlySnapshotOptions,
  ): Promise<Account[]> {
    try {
      const lowercasedIds = accountIds.map((id) => id.toLowerCase())
      const variables: any = {
        accountIds: lowercasedIds,
        first: pagination.first,
        timestampGt: snapshotOptions.timestampGt.toString(),
        timestampLt: snapshotOptions.timestampLt.toString(),
      }
      if (pagination.lastId) {
        variables.lastId = pagination.lastId
      } else {
        variables.lastId = ''
      }

      const data = (await this.clients[chain].request(
        ACCOUNTS_WITH_HOURLY_SNAPSHOTS_QUERY,
        variables,
      )) as any
      return data.accounts.filter(Boolean).map((a: any) => convertAccount(a)) as Account[]
    } catch (error) {
      console.error(`Error fetching accounts with hourly snapshots from ${chain}:`, error)
      return []
    }
  }

  /**
   * Validates positions for a set of accounts on a specific chain to ensure they comply with referral rules.
   *
   * This method checks if accounts have valid positions based on the following criteria:
   * 1. If an account has positions created before their referral timestamp, it's considered invalid
   * 2. The referral timestamp is determined by the earliest referral timestamp across all chains
   * 3. Accounts with positions created after their referral timestamp are considered valid
   *
   * @param chain - The blockchain network to validate positions on
   * @param accounts - A map of account IDs to their Account objects containing referral data
   * @returns A map of account IDs to boolean values indicating whether their positions are valid
   *          (true = valid, false = invalid)
   *
   * @example
   * ```typescript
   * const accounts = {
   *   '0x123': { referralTimestamp: '1234567890', ... },
   *   '0x456': { referralTimestamp: '1234567891', ... }
   * };
   * const validations = await client.validateAccounts('ethereum', accounts);
   * // Returns: { '0x123': true, '0x456': false }
   * ```
   */
  async validateAccounts(
    chain: Chain,
    accounts: { [accountId: string]: Account },
  ): Promise<{ [accountId: string]: boolean }> {
    try {
      const lowercasedIds = Object.keys(accounts).map((accountId) => accountId.toLowerCase())
      const data = await this.clients[chain].request<ValidatePositionsQuery>(
        VALIDATE_POSITIONS_QUERY,
        {
          accountIds: lowercasedIds,
        },
      )

      const result: { [accountId: string]: boolean } = {}
      for (const account of data.accounts) {
        const earliestReferralTimestamp = accounts[account.id].referralTimestamp

        // Define validation conditions as named constants for clarity
        const hasPositions = account.positions.length > 0
        const hasEarliestReferralTimestamp = Boolean(earliestReferralTimestamp)
        const hasReferralTimestamp = Boolean(account.referralTimestamp)
        const positionsCreatedBeforeReferral =
          hasPositions &&
          hasEarliestReferralTimestamp &&
          Number(account.positions[0].createdTimestamp) < Number(earliestReferralTimestamp)
        const wasReferredEarlierThanCurrentPeriod =
          hasEarliestReferralTimestamp &&
          hasReferralTimestamp &&
          Number(earliestReferralTimestamp) > Number(account.referralTimestamp)

        // An account is invalid if:
        // 1. It has a referral timestamp AND positions created before referral, OR
        // 2. It was referred earlier than the current period being processed, OR
        // 3. It has no referral timestamp (shouldn't be in results)
        const isInvalid =
          (hasEarliestReferralTimestamp && positionsCreatedBeforeReferral) ||
          wasReferredEarlierThanCurrentPeriod

        result[account.id] = !isInvalid
      }
      return result
    } catch (error) {
      console.error(`Error validating positions from ${chain}:`, error)
      return {}
    }
  }

  // Method to get all positions with hourly snapshots for valid accounts
  async getAllPositionsWithHourlySnapshots(
    accountIds: string[],
    snapshotOptions: HourlySnapshotOptions,
  ): Promise<{ [chain: string]: Account[] }> {
    const result: { [chain: string]: Account[] } = {}

    for (const chain of CHAINS) {
      const allAccounts: Account[] = []
      let lastId: string | undefined
      const batchSize = 50
      // Paginate through accounts
      while (true) {
        const accounts = await this.getAccountsWithHourlySnapshots(
          chain,
          accountIds,
          {
            first: batchSize,
            lastId,
          },
          snapshotOptions,
        )
        if (accounts.length === 0) break

        allAccounts.push(...accounts)

        if (accounts.length < batchSize) break

        lastId = accounts[accounts.length - 1].id
      }

      result[chain] = allAccounts
    }

    return result
  }

  /**
   * Gets a list of valid accounts that were referred in a specific time period.
   * This method validates accounts across all chains and ensures they meet all referral criteria.
   *
   * The process consists of four main steps:
   * 1. Fetches referred accounts from all chains (Ethereum, Sonic, Arbitrum, Base) for the specified time period
   * 2. Consolidates accounts across chains, keeping the earliest referral timestamp for each account
   * 3. Validates positions across all chains to ensure accounts haven't created positions before being referred
   * 4. Validates if the account was not referred before the currently processed time period
   *
   * Time period handling:
   * - For first run (isFirstRun=true): Only uses timestampLt to get all historical data up to that point
   * - For subsequent runs: Uses both timestampGt and timestampLt to process the specified time period
   *
   * @param timestampGt - The start timestamp of the period (in seconds since epoch)
   * @param timestampLt - The end timestamp of the period (in seconds since epoch)
   * @param isFirstRun - Whether this is the first run of the processor
   * @returns Object containing an array of valid account IDs that passed all validation checks
   *
   * @example
   * ```typescript
   * // First run - process all historical data up to now
   * const { validAccountIds } = await client.getValidReferredAccounts(
   *   undefined,
   *   BigInt(Math.floor(Date.now() / 1000)),
   *   true
   * );
   *
   * // Process a specific time period
   * const periodStart = BigInt(Math.floor(Date.now() / 1000) - 3600); // 1 hour ago
   * const periodEnd = BigInt(Math.floor(Date.now() / 1000));
   * const { validAccountIds } = await client.getValidReferredAccounts(
   *   periodStart,
   *   periodEnd,
   *   false
   * );
   * ```
   *
   * Note: This method is designed to work with any time period because:
   * 1. It processes referral data in time-bound chunks
   * 2. It validates positions against referral timestamps
   * 3. It ensures no positions were created before referral across all chains
   * 4. It verifies that accounts weren't referred before the current period
   *
   * The time period approach is safe because:
   * - It maintains data consistency by processing complete time periods
   * - It prevents double-counting by using timestamp boundaries
   * - It allows for efficient backfilling of historical data
   * - It ensures all chains are synchronized in their validation
   */
  async getValidReferredAccounts(
    timestampGt: bigint,
    timestampLt: bigint,
  ): Promise<{ validAccounts: Account[] }> {
    const allAccts: Account[] = []

    // Step 1: Get all referred accounts from all chains
    for (const chain of CHAINS) {
      const options: ReferredAccountsOptions = {}

      if (timestampGt) options.timestampGt = timestampGt
      if (timestampLt) options.timestampLt = timestampLt

      const accounts = (await this.getReferredAccounts(chain, options)).map((a) => ({
        ...a,
        referralChain: chain,
      }))
      allAccts.push(...accounts)
    }
    // Step 2: Get all referred accounts from all chains
    const allReferredAccounts = allAccts.reduce(
      (acc, account) => {
        if (!acc[account.id]) {
          acc[account.id] = account
        } else {
          if (Number(account.referralTimestamp) < Number(acc[account.id].referralTimestamp)) {
            acc[account.id] = account
          }
        }
        return acc
      },
      {} as { [id: string]: Account },
    )
    // Step3: Validate accounts across all chains (check if they have positions created before earliest referral timestamp)
    const validationResults: { [accountId: string]: boolean } = {}
    for (const chain of CHAINS) {
      const chainValidation = await this.validateAccounts(chain, allReferredAccounts)
      Object.entries(chainValidation).forEach(([accountId, isValid]) => {
        if (validationResults[accountId] === undefined) {
          validationResults[accountId] = isValid
        } else {
          // Account is valid only if it's valid on ALL chains
          validationResults[accountId] = validationResults[accountId] && isValid
        }
      })
    }

    return {
      validAccounts: Object.values(allReferredAccounts).filter(
        (account) => validationResults[account.id],
      ),
    }
  }

  // Method to get all positions for valid accounts with pagination
  async getAllPositionsForAccounts(accountIds: string[]): Promise<{ [chain: string]: Account[] }> {
    const result: { [chain: string]: Account[] } = {}

    for (const chain of CHAINS) {
      const allAccounts: Account[] = []
      let lastId: string | undefined
      const batchSize = 50

      // Paginate through accounts
      while (true) {
        const accounts = await this.getAccountsWithPositions(chain, accountIds, {
          first: batchSize,
          lastId,
        })

        if (accounts.length === 0) break

        allAccounts.push(...accounts)

        if (accounts.length < batchSize) break

        lastId = accounts[accounts.length - 1].id
      }

      result[chain] = allAccounts
    }

    return result
  }
}
