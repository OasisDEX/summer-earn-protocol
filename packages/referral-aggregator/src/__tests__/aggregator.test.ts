import { ReferralAggregator } from '../aggregator'
import { ReferralClient } from '../client'
import { Chain } from '../types'

// Mock the referral client
jest.mock('../client')
const MockReferralClient = ReferralClient as jest.MockedClass<typeof ReferralClient>

describe('ReferralAggregator', () => {
  let client: jest.Mocked<ReferralClient>
  let aggregator: ReferralAggregator

  beforeEach(() => {
    jest.clearAllMocks()
    client = new MockReferralClient() as jest.Mocked<ReferralClient>
    aggregator = new ReferralAggregator()
  })

  describe('aggregateAccount', () => {
    const accountId = '0x123'
    const mockAccount = {
      id: accountId,
      positions: [],
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
    }

    const mockPosition = {
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
    }

    it('should aggregate data from all chains', async () => {
      // Mock responses for each chain
      const chains: Chain[] = ['Ethereum', 'Polygon', 'Arbitrum', 'Base']
      chains.forEach((chain) => {
        client.getAccount.mockResolvedValueOnce(mockAccount)
        client.getPositions.mockResolvedValueOnce([mockPosition])
      })

      const result = await aggregator.aggregateAccount(accountId)

      expect(result).toEqual({
        id: accountId,
        positions: Array(4).fill(mockPosition), // One position from each chain
        totalStakedSummerToken: BigInt(4000), // 1000 from each chain
        totalStakedSummerTokenNormalized: 4000,
        lastUpdateBlock: BigInt(12345678),
        totalClaimedSummerToken: BigInt(400), // 100 from each chain
        totalClaimedSummerTokenNormalized: 400,
        referralData: mockAccount.referralData,
        referralTimestamp: mockAccount.referralTimestamp,
        chainData: {
          Ethereum: {
            stakedSummerToken: BigInt(1000),
            stakedSummerTokenNormalized: 1000,
            claimedSummerToken: BigInt(100),
            claimedSummerTokenNormalized: 100,
            referralData: mockAccount.referralData,
            referralTimestamp: mockAccount.referralTimestamp,
          },
          Polygon: {
            stakedSummerToken: BigInt(1000),
            stakedSummerTokenNormalized: 1000,
            claimedSummerToken: BigInt(100),
            claimedSummerTokenNormalized: 100,
            referralData: mockAccount.referralData,
            referralTimestamp: mockAccount.referralTimestamp,
          },
          Arbitrum: {
            stakedSummerToken: BigInt(1000),
            stakedSummerTokenNormalized: 1000,
            claimedSummerToken: BigInt(100),
            claimedSummerTokenNormalized: 100,
            referralData: mockAccount.referralData,
            referralTimestamp: mockAccount.referralTimestamp,
          },
          Base: {
            stakedSummerToken: BigInt(1000),
            stakedSummerTokenNormalized: 1000,
            claimedSummerToken: BigInt(100),
            claimedSummerTokenNormalized: 100,
            referralData: mockAccount.referralData,
            referralTimestamp: mockAccount.referralTimestamp,
          },
        },
      })
    })

    it('should handle missing data from some chains', async () => {
      // Mock responses for each chain
      const chains: Chain[] = ['Ethereum', 'Polygon', 'Arbitrum', 'Base']
      chains.forEach((chain, index) => {
        if (index % 2 === 0) {
          // Even indices have data
          client.getAccount.mockResolvedValueOnce(mockAccount)
          client.getPositions.mockResolvedValueOnce([mockPosition])
        } else {
          // Odd indices have no data
          client.getAccount.mockResolvedValueOnce(null)
          client.getPositions.mockResolvedValueOnce([])
        }
      })

      const result = await aggregator.aggregateAccount(accountId)

      expect(result).toEqual({
        id: accountId,
        positions: Array(2).fill(mockPosition), // Two positions from even-indexed chains
        totalStakedSummerToken: BigInt(2000), // 1000 from each even-indexed chain
        totalStakedSummerTokenNormalized: 2000,
        lastUpdateBlock: BigInt(12345678),
        totalClaimedSummerToken: BigInt(200), // 100 from each even-indexed chain
        totalClaimedSummerTokenNormalized: 200,
        referralData: mockAccount.referralData,
        referralTimestamp: mockAccount.referralTimestamp,
        chainData: {
          Ethereum: {
            stakedSummerToken: BigInt(1000),
            stakedSummerTokenNormalized: 1000,
            claimedSummerToken: BigInt(100),
            claimedSummerTokenNormalized: 100,
            referralData: mockAccount.referralData,
            referralTimestamp: mockAccount.referralTimestamp,
          },
          Polygon: {
            stakedSummerToken: BigInt(0),
            stakedSummerTokenNormalized: 0,
            claimedSummerToken: BigInt(0),
            claimedSummerTokenNormalized: 0,
            referralData: null,
            referralTimestamp: null,
          },
          Arbitrum: {
            stakedSummerToken: BigInt(1000),
            stakedSummerTokenNormalized: 1000,
            claimedSummerToken: BigInt(100),
            claimedSummerTokenNormalized: 100,
            referralData: mockAccount.referralData,
            referralTimestamp: mockAccount.referralTimestamp,
          },
          Base: {
            stakedSummerToken: BigInt(0),
            stakedSummerTokenNormalized: 0,
            claimedSummerToken: BigInt(0),
            claimedSummerTokenNormalized: 0,
            referralData: null,
            referralTimestamp: null,
          },
        },
      })
    })

    it('should return null if no data found on any chain', async () => {
      // Mock no data for all chains
      const chains: Chain[] = ['Ethereum', 'Polygon', 'Arbitrum', 'Base']
      chains.forEach(() => {
        client.getAccount.mockResolvedValueOnce(null)
        client.getPositions.mockResolvedValueOnce([])
      })

      const result = await aggregator.aggregateAccount(accountId)

      expect(result).toBeNull()
    })
  })
})
