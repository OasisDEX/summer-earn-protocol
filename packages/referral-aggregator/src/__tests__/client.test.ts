import { ReferralClient } from '../client'
import { Account, Position, ReferralData } from '../types'

// Mock the GraphQL client
jest.mock('graphql-request', () => ({
  GraphQLClient: jest.fn().mockImplementation(() => ({
    request: jest.fn()
  }))
}))

// Add custom matcher for BigInt
expect.extend({
  toBeBigInt(received: unknown, expected: bigint) {
    const pass = received === expected
    return {
      message: () => `expected ${received} ${pass ? 'not ' : ''}to be ${expected}`,
      pass
    }
  }
})

describe('ReferralClient', () => {
  let client: ReferralClient
  let mockGraphQLClient: any

  const mockReferralData: ReferralData = {
    id: '0x123',
    amountOfReferred: BigInt(5),
    protocol: 'summer-earn'
  }

  const mockPosition: Position = {
    id: '0x456',
    account: '0x789',
    vault: '0xabc',
    inputTokenDeposits: BigInt(1000),
    inputTokenDepositsNormalized: 1000,
    inputTokenWithdrawalsNormalized: 0,
    inputTokenDepositsNormalizedInUSD: 1000,
    inputTokenWithdrawals: BigInt(0),
    inputTokenWithdrawalsNormalizedInUSD: 0,
    inputTokenBalance: BigInt(1000),
    outputTokenBalance: BigInt(1000),
    stakedInputTokenBalance: BigInt(1000),
    stakedOutputTokenBalance: BigInt(1000),
    unstakedInputTokenBalance: BigInt(0),
    unstakedOutputTokenBalance: BigInt(0),
    inputTokenBalanceNormalized: 1000,
    stakedInputTokenBalanceNormalized: 1000,
    unstakedInputTokenBalanceNormalized: 0,
    inputTokenBalanceNormalizedInUSD: 1000,
    stakedInputTokenBalanceNormalizedInUSD: 1000,
    unstakedInputTokenBalanceNormalizedInUSD: 0,
    createdTimestamp: BigInt(1234567890),
    createdBlockNumber: BigInt(12345678),
    claimedSummerToken: BigInt(100),
    claimedSummerTokenNormalized: 100,
    claimableSummerToken: BigInt(50),
    claimableSummerTokenNormalized: 50,
    referralData: null
  }

  const mockAccount: Account = {
    id: '0x789',
    positions: [mockPosition],
    stakedSummerToken: BigInt(1000),
    stakedSummerTokenNormalized: 1000,
    lastUpdateBlock: BigInt(12345678),
    claimedSummerToken: BigInt(100),
    claimedSummerTokenNormalized: 100,
    referralData: mockReferralData,
    referralTimestamp: BigInt(1234567890)
  }

  beforeEach(() => {
    jest.clearAllMocks()
    client = new ReferralClient()
    mockGraphQLClient = (client as any).clients.Ethereum
  })

  describe('getAccount', () => {
    it('should fetch account data successfully', async () => {
      const mockResponse = {
        account: mockAccount
      }

      mockGraphQLClient.request.mockResolvedValueOnce(mockResponse)

      const result = await client.getAccount('Ethereum', '0x789')

      expect(result).toEqual(mockAccount)
      expect(mockGraphQLClient.request).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          id: '0x789'
        })
      )
    })

    it('should return null when account is not found', async () => {
      const mockResponse = {
        account: null
      }

      mockGraphQLClient.request.mockResolvedValueOnce(mockResponse)

      const result = await client.getAccount('Ethereum', '0x789')

      expect(result).toBeNull()
    })

    it('should handle GraphQL errors', async () => {
      const error = new Error('GraphQL error')
      mockGraphQLClient.request.mockRejectedValueOnce(error)

      await expect(client.getAccount('Ethereum', '0x789')).rejects.toThrow('GraphQL error')
    })
  })

  describe('getPositions', () => {
    it('should fetch positions successfully', async () => {
      const mockResponse = {
        positions: [mockPosition]
      }

      mockGraphQLClient.request.mockResolvedValueOnce(mockResponse)

      const result = await client.getPositions('Ethereum', '0x789')

      expect(result).toEqual([mockPosition])
      expect(mockGraphQLClient.request).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          account: '0x789'
        })
      )
    })

    it('should return empty array when no positions are found', async () => {
      const mockResponse = {
        positions: []
      }

      mockGraphQLClient.request.mockResolvedValueOnce(mockResponse)

      const result = await client.getPositions('Ethereum', '0x789')

      expect(result).toEqual([])
    })

    it('should handle GraphQL errors', async () => {
      const error = new Error('GraphQL error')
      mockGraphQLClient.request.mockRejectedValueOnce(error)

      await expect(client.getPositions('Ethereum', '0x789')).rejects.toThrow('GraphQL error')
    })
  })

  describe('getAllChainData', () => {
    it('should fetch data from all chains successfully', async () => {
      const mockResponse = {
        account: mockAccount,
        positions: [mockPosition]
      }

      // Mock successful responses for all chains
      Object.values((client as any).clients).forEach((chainClient: any) => {
        chainClient.request.mockResolvedValueOnce(mockResponse)
      })

      const result = await client.getAllChainData('0x789')

      expect(result).toEqual({
        Ethereum: mockResponse,
        Polygon: mockResponse,
        Arbitrum: mockResponse,
        Base: mockResponse
      })
    })

    it('should handle errors from individual chains', async () => {
      const mockResponse = {
        account: mockAccount,
        positions: [mockPosition]
      }

      // Mock successful responses for some chains and errors for others
      const clients = (client as any).clients
      clients.Ethereum.request.mockResolvedValueOnce(mockResponse)
      clients.Polygon.request.mockRejectedValueOnce(new Error('Polygon error'))
      clients.Arbitrum.request.mockResolvedValueOnce(mockResponse)
      clients.Base.request.mockRejectedValueOnce(new Error('Base error'))

      const result = await client.getAllChainData('0x789')

      expect(result).toEqual({
        Ethereum: mockResponse,
        Polygon: { account: null, positions: [] },
        Arbitrum: mockResponse,
        Base: { account: null, positions: [] }
      })
    })
  })
}) 