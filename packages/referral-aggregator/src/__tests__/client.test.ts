import { GraphQLClient } from 'graphql-request'
import { ReferralClient } from '../client'
import { Account, Chain, Position, ReferralData } from '../types'

// Mock the GraphQL client
jest.mock('graphql-request', () => ({
  GraphQLClient: jest.fn().mockImplementation(() => ({
    request: jest.fn(),
  })),
}))

// Add custom matcher for BigInt
expect.extend({
  toBeBigInt(received: unknown, expected: bigint) {
    const pass = received === expected
    return {
      message: () => `expected ${received} ${pass ? 'not ' : ''}to be ${expected}`,
      pass,
    }
  },
})

describe('ReferralClient', () => {
  let client: ReferralClient
  let mockGraphQLClient: jest.Mocked<GraphQLClient>

  const mockReferralData: ReferralData = {
    id: '0x123',
    amountOfReferred: BigInt(5),
  }

  const mockPosition: Position = {
    id: '0x456',
    account: { id: '0x789' },
    vault: { id: '0xabc' },
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
    referralData: null,
    depositAmountUsd: BigInt(1),
    createdAt: BigInt(1234567880),
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
    referralTimestamp: BigInt(1234567890),
  }

  beforeEach(() => {
    jest.clearAllMocks()
    client = new ReferralClient()
    mockGraphQLClient = (client as any).clients['Ethereum']
  })

  describe('getAccount', () => {
    it('should fetch account data', async () => {
      const accountId = '0x123'
      const mockAccount = {
        id: accountId,
        positions: [{ id: '0x456' }],
        stakedSummerToken: '1000',
        stakedSummerTokenNormalized: 1000,
        lastUpdateBlock: '12345678',
        claimedSummerToken: '100',
        claimedSummerTokenNormalized: 100,
        referralData: {
          id: '0x789',
          amountOfReferred: '5',
        },
        referralTimestamp: '1704067200',
      }

      mockGraphQLClient.request.mockResolvedValueOnce({ account: mockAccount })

      const result = await client.getAccount('Ethereum', accountId)

      expect(mockGraphQLClient.request).toHaveBeenCalledWith(expect.any(Object), { id: accountId })
      expect(result).toEqual({
        id: accountId,
        positions: [{ id: '0x456' }],
        stakedSummerToken: BigInt(1000),
        stakedSummerTokenNormalized: 1000,
        lastUpdateBlock: BigInt(12345678),
        claimedSummerToken: BigInt(100),
        claimedSummerTokenNormalized: 100,
        referralData: {
          id: '0x789',
          amountOfReferred: BigInt(5),
        },
        referralTimestamp: BigInt(1704067200),
      })
    })

    it('should return null on error', async () => {
      const accountId = '0x123'
      mockGraphQLClient.request.mockRejectedValueOnce(new Error('Network error'))

      const result = await client.getAccount('Ethereum', accountId)

      expect(result).toBeNull()
    })
  })

  describe('getPositions', () => {
    it('should fetch positions for account', async () => {
      const accountId = '0x123'
      const mockPositions = [
        {
          id: '0x456',
          account: { id: accountId },
          vault: { id: '0x789' },
          inputTokenDeposits: '1000',
          inputTokenDepositsNormalized: 1000,
          inputTokenWithdrawalsNormalized: 0,
          inputTokenDepositsNormalizedInUSD: 1000,
          inputTokenWithdrawals: '0',
          inputTokenWithdrawalsNormalizedInUSD: 0,
          inputTokenBalance: '1000',
          outputTokenBalance: '1000',
          stakedInputTokenBalance: '1000',
          stakedOutputTokenBalance: '1000',
          unstakedInputTokenBalance: '0',
          unstakedOutputTokenBalance: '0',
          inputTokenBalanceNormalized: 1000,
          stakedInputTokenBalanceNormalized: 1000,
          unstakedInputTokenBalanceNormalized: 0,
          inputTokenBalanceNormalizedInUSD: 1000,
          stakedInputTokenBalanceNormalizedInUSD: 1000,
          unstakedInputTokenBalanceNormalizedInUSD: 0,
          createdTimestamp: '1704067200',
          createdBlockNumber: '12345678',
          claimedSummerToken: '0',
          claimedSummerTokenNormalized: 0,
          claimableSummerToken: '0',
          claimableSummerTokenNormalized: 0,
          depositAmountUsd: '1000',
          createdAt: '1704067200',
          referralData: null,
        },
      ]

      mockGraphQLClient.request.mockResolvedValueOnce({ positions: mockPositions })

      const result = await client.getPositions('Ethereum', accountId)

      expect(mockGraphQLClient.request).toHaveBeenCalledWith(expect.any(Object), {
        account: accountId,
      })
      expect(result).toHaveLength(1)
      expect(result[0]).toEqual({
        id: '0x456',
        account: { id: accountId },
        vault: { id: '0x789' },
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
        createdTimestamp: BigInt(1704067200),
        createdBlockNumber: BigInt(12345678),
        claimedSummerToken: BigInt(0),
        claimedSummerTokenNormalized: 0,
        claimableSummerToken: BigInt(0),
        claimableSummerTokenNormalized: 0,
        depositAmountUsd: BigInt(1000),
        createdAt: BigInt(1704067200),
        referralData: null,
      })
    })

    it('should return empty array on error', async () => {
      const accountId = '0x123'
      mockGraphQLClient.request.mockRejectedValueOnce(new Error('Network error'))

      const result = await client.getPositions('Ethereum', accountId)

      expect(result).toEqual([])
    })
  })

  describe('getAllChainData', () => {
    it('should fetch data from all chains', async () => {
      const accountId = '0x123'
      const mockAccount = {
        id: accountId,
        positions: [],
        stakedSummerToken: '1000',
        stakedSummerTokenNormalized: 1000,
        lastUpdateBlock: '12345678',
        claimedSummerToken: '100',
        claimedSummerTokenNormalized: 100,
        referralData: null,
        referralTimestamp: null,
      }

      const mockPositions = [
        {
          id: '0x456',
          account: { id: accountId },
          vault: { id: '0x789' },
          inputTokenDeposits: '1000',
          inputTokenDepositsNormalized: 1000,
          inputTokenWithdrawalsNormalized: 0,
          inputTokenDepositsNormalizedInUSD: 1000,
          inputTokenWithdrawals: '0',
          inputTokenWithdrawalsNormalizedInUSD: 0,
          inputTokenBalance: '1000',
          outputTokenBalance: '1000',
          stakedInputTokenBalance: '1000',
          stakedOutputTokenBalance: '1000',
          unstakedInputTokenBalance: '0',
          unstakedOutputTokenBalance: '0',
          inputTokenBalanceNormalized: 1000,
          stakedInputTokenBalanceNormalized: 1000,
          unstakedInputTokenBalanceNormalized: 0,
          inputTokenBalanceNormalizedInUSD: 1000,
          stakedInputTokenBalanceNormalizedInUSD: 1000,
          unstakedInputTokenBalanceNormalizedInUSD: 0,
          createdTimestamp: '1704067200',
          createdBlockNumber: '12345678',
          claimedSummerToken: '0',
          claimedSummerTokenNormalized: 0,
          claimableSummerToken: '0',
          claimableSummerTokenNormalized: 0,
          depositAmountUsd: '1000',
          createdAt: '1704067200',
          referralData: null,
        },
      ]

      // Mock responses for each chain
      const chains: Chain[] = ['Ethereum', 'Polygon', 'Arbitrum', 'Base']
      chains.forEach((chain) => {
        const mockClient = (client as any).clients[chain]
        mockClient.request
          .mockResolvedValueOnce({ account: mockAccount })
          .mockResolvedValueOnce({ positions: mockPositions })
      })

      const result = await client.getAllChainData(accountId)

      // Verify data for each chain
      chains.forEach((chain) => {
        expect(result[chain]).toEqual({
          account: {
            id: accountId,
            positions: [],
            stakedSummerToken: BigInt(1000),
            stakedSummerTokenNormalized: 1000,
            lastUpdateBlock: BigInt(12345678),
            claimedSummerToken: BigInt(100),
            claimedSummerTokenNormalized: 100,
            referralData: null,
            referralTimestamp: null,
          },
          positions: [
            {
              id: '0x456',
              account: { id: accountId },
              vault: { id: '0x789' },
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
              createdTimestamp: BigInt(1704067200),
              createdBlockNumber: BigInt(12345678),
              claimedSummerToken: BigInt(0),
              claimedSummerTokenNormalized: 0,
              claimableSummerToken: BigInt(0),
              claimableSummerTokenNormalized: 0,
              depositAmountUsd: BigInt(1000),
              createdAt: BigInt(1704067200),
              referralData: null,
            },
          ],
        })
      })
    })
  })
})
