import { GraphQLClient } from 'graphql-request'
import { Account, Position, convertAccount, convertPosition } from './types'
import { ACCOUNT_QUERY, POSITIONS_QUERY } from './graphql/operations'
import { GetAccountQuery, GetPositionsQuery } from './generated/graphql'

const CHAINS = ['Ethereum', 'Polygon', 'Arbitrum', 'Base'] as const
type Chain = typeof CHAINS[number]

const SUBGRAPH_URLS: Record<Chain, string> = {
  Ethereum: 'https://api.thegraph.com/subgraphs/name/summer-earn/ethereum',
  Polygon: 'https://api.thegraph.com/subgraphs/name/summer-earn/polygon',
  Arbitrum: 'https://api.thegraph.com/subgraphs/name/summer-earn/arbitrum',
  Base: 'https://api.thegraph.com/subgraphs/name/summer-earn/base',
}

export class ReferralClient {
  private clients: Record<Chain, GraphQLClient>

  constructor() {
    this.clients = CHAINS.reduce((acc, chain) => {
      acc[chain] = new GraphQLClient(SUBGRAPH_URLS[chain])
      return acc
    }, {} as Record<Chain, GraphQLClient>)
  }

  async getAccount(chain: Chain, id: string): Promise<Account | null> {
    try {
      const data = await this.clients[chain].request<GetAccountQuery>(ACCOUNT_QUERY, { id })
      return convertAccount(data.account as any)
    } catch (error) {
      console.error(`Error fetching account from ${chain}:`, error)
      return null
    }
  }

  async getPositions(chain: Chain, accountId: string): Promise<Position[]> {
    try {
      const data = await this.clients[chain].request<GetPositionsQuery>(POSITIONS_QUERY, { account: accountId })
      return data.positions
        .map(p => convertPosition(p as any))
        .filter((p): p is Position => p !== null)
    } catch (error) {
      console.error(`Error fetching positions from ${chain}:`, error)
      return []
    }
  }

  async getAllChainData(accountId: string): Promise<Record<Chain, { account: Account | null; positions: Position[] }>> {
    const results = await Promise.all(
      CHAINS.map(async (chain) => {
        const [account, positions] = await Promise.all([
          this.getAccount(chain, accountId),
          this.getPositions(chain, accountId),
        ])
        return { chain, account, positions }
      })
    )

    return results.reduce((acc, { chain, account, positions }) => {
      acc[chain] = { account, positions }
      return acc
    }, {} as Record<Chain, { account: Account | null; positions: Position[] }>)
  }
} 