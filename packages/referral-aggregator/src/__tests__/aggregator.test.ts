import { ReferralAggregator } from '../aggregator'
import { ReferralClient } from '../client'
import { Account, Position, ReferralData } from '../types'

// Mock the ReferralClient
jest.mock('../client')

describe('ReferralAggregator', () => {
  let aggregator: ReferralAggregator
  let mockClient: jest.Mocked<ReferralClient>

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
    // Clear all mocks before each test
    jest.clearAllMocks()

    // Create a new instance of ReferralAggregator
    aggregator = new ReferralAggregator()
    mockClient = new ReferralClient() as jest.Mocked<ReferralClient>
    ;(ReferralClient as jest.Mock).mockImplementation(() => mockClient)
  })

  describe('aggregateAccount', () => {
    it('should return null when no data is found on any chain', async () => {
      // Mock the client to return no data
      mockClient.getAllChainData.mockResolvedValue({
        Ethereum: { account: null, positions: [] },
        Polygon: { account: null, positions: [] },
        Arbitrum: { account: null, positions: [] },
        Base: { account: null, positions: [] }
      })

      const result = await aggregator.aggregateAccount('0x789')
      expect(result).toBeNull()
    })

    it('should aggregate data from multiple chains', async () => {
      // Mock the client to return data from multiple chains
      mockClient.getAllChainData.mockResolvedValue({
        Ethereum: { account: mockAccount, positions: [mockPosition] },
        Polygon: { 
          account: {
            ...mockAccount,
            stakedSummerToken: BigInt(500),
            stakedSummerTokenNormalized: 500,
            claimedSummerToken: BigInt(50),
            claimedSummerTokenNormalized: 50
          },
          positions: []
        },
        Arbitrum: { account: null, positions: [] },
        Base: { account: null, positions: [] }
      })

      const result = await aggregator.aggregateAccount('0x789')

      expect(result).not.toBeNull()
      expect(result?.totalStakedSummerToken).toBe(BigInt(1500))
      expect(result?.totalStakedSummerTokenNormalized).toBe(1500)
      expect(result?.totalClaimedSummerToken).toBe(BigInt(150))
      expect(result?.totalClaimedSummerTokenNormalized).toBe(150)
      expect(result?.positions).toHaveLength(1)
      expect(result?.referralData).toEqual(mockReferralData)
    })

    it('should use the earliest referral timestamp', async () => {
      const earlierTimestamp = BigInt(1234567880)
      const laterTimestamp = BigInt(1234567890)

      mockClient.getAllChainData.mockResolvedValue({
        Ethereum: { 
          account: {
            ...mockAccount,
            referralTimestamp: laterTimestamp
          },
          positions: []
        },
        Polygon: { 
          account: {
            ...mockAccount,
            referralTimestamp: earlierTimestamp
          },
          positions: []
        },
        Arbitrum: { account: null, positions: [] },
        Base: { account: null, positions: [] }
      })

      const result = await aggregator.aggregateAccount('0x789')

      expect(result).not.toBeNull()
      expect(result?.referralTimestamp).toBe(earlierTimestamp)
    })

    it('should handle missing referral data', async () => {
      mockClient.getAllChainData.mockResolvedValue({
        Ethereum: { 
          account: {
            ...mockAccount,
            referralData: null,
            referralTimestamp: null
          },
          positions: []
        },
        Polygon: { 
          account: {
            ...mockAccount,
            referralData: mockReferralData,
            referralTimestamp: BigInt(1234567890)
          },
          positions: []
        },
        Arbitrum: { account: null, positions: [] },
        Base: { account: null, positions: [] }
      })

      const result = await aggregator.aggregateAccount('0x789')

      expect(result).not.toBeNull()
      expect(result?.referralData).toEqual(mockReferralData)
      expect(result?.referralTimestamp).toBe(BigInt(1234567890))
    })
  })
}) 