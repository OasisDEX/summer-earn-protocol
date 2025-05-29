import { GraphQLClient } from 'graphql-request'
import { GetAccountsQuery, GetReferredAccountsQuery } from './generated/graphql'
import {
  ACCOUNTS_QUERY,
  ACCOUNTS_WITH_POSITIONS_QUERY,
  REFERRED_ACCOUNTS_QUERY,
  VALIDATE_POSITIONS_QUERY,
} from './queries'
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

  async validatePositions(
    chain: Chain,
    accountIds: string[],
  ): Promise<{ [accountId: string]: boolean }> {
    try {
      const lowercasedIds = accountIds.map((id) => id.toLowerCase())
      const data = (await this.clients[chain].request(VALIDATE_POSITIONS_QUERY, {
        accountIds: lowercasedIds,
      })) as any

      const result: { [accountId: string]: boolean } = {}
      for (const account of data.accounts) {
        // If account has positions created before referral timestamp, it's invalid
        result[account.id] = !(
          account.positions.length > 0 &&
          account.positions[0].createdTimestamp < account.referralTimestamp
        )
      }
      return result
    } catch (error) {
      console.error(`Error validating positions from ${chain}:`, error)
      return {}
    }
  }

  // New method for hourly processing
  async processReferredAccountsHourly(
    timestampGt?: bigint,
    timestampLt?: bigint,
    isFirstRun: boolean = false,
  ): Promise<{ validAccounts: string[]; allReferredAccounts: Account[] }> {
    const allReferredAccounts: Account[] = []
    const accountIds = new Set<string>()

    // Step 1: Get all referred accounts from all chains
    for (const chain of CHAINS) {
      const options: ReferredAccountsOptions = {}
      if (isFirstRun) {
        if (timestampLt) options.timestampLt = timestampLt
      } else {
        if (timestampGt) options.timestampGt = timestampGt
        if (timestampLt) options.timestampLt = timestampLt
      }

      const accounts = await this.getReferredAccounts(chain, options)
      allReferredAccounts.push(...accounts)
      accounts.forEach((account) => accountIds.add(account.id))
    }

    // Step 2: Validate accounts across all chains (check if they have positions before referral)
    const validationResults: { [accountId: string]: boolean } = {}
    for (const chain of CHAINS) {
      const chainValidation = await this.validatePositions(chain, Array.from(accountIds))
      Object.entries(chainValidation).forEach(([accountId, isValid]) => {
        if (validationResults[accountId] === undefined) {
          validationResults[accountId] = isValid
        } else {
          // Account is valid only if it's valid on ALL chains
          validationResults[accountId] = validationResults[accountId] && isValid
        }
      })
    }

    const validAccounts = Object.entries(validationResults)
      .filter(([_, isValid]) => isValid)
      .map(([accountId]) => accountId)

    return { validAccounts, allReferredAccounts }
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
