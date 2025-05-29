import { ReferralClient } from '../client'
import { DatabaseService } from '../db'
import { ReferralPointsService } from '../points'
import { Chain } from '../types'

// Mock the database service
jest.mock('../db')
const MockDatabaseService = DatabaseService as jest.MockedClass<typeof DatabaseService>

// Mock the referral client
jest.mock('../client')
const MockReferralClient = ReferralClient as jest.MockedClass<typeof ReferralClient>

describe('ReferralPointsService', () => {
  let db: jest.Mocked<DatabaseService>
  let client: jest.Mocked<ReferralClient>
  let service: ReferralPointsService

  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks()

    // Initialize mocked services
    db = new MockDatabaseService() as jest.Mocked<DatabaseService>
    client = new MockReferralClient() as jest.Mocked<ReferralClient>
    service = new ReferralPointsService(db, client)
  })

  describe('calculatePoints', () => {
    const accountId = '0x123'
    const referredId = '0x456'
    const chain: Chain = 'Ethereum'
    const referralTimestamp = new Date('2024-01-01T00:00:00Z')

    it('should calculate points correctly for a single referred user with one position', async () => {
      // Mock database to return one referred user
      db.getReferredUsers.mockResolvedValue([
        {
          referredId,
          chain,
          referralTimestamp,
        },
      ])

      // Mock client to return one position for the referred user
      client.getPositions.mockResolvedValue([
        {
          id: '0x789',
          account: { id: referredId },
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
          createdTimestamp: BigInt(1704067200), // 2024-01-01T00:00:00Z
          createdBlockNumber: BigInt(12345678),
          claimedSummerToken: BigInt(0),
          claimedSummerTokenNormalized: 0,
          claimableSummerToken: BigInt(0),
          claimableSummerTokenNormalized: 0,
          depositAmountUsd: BigInt(1000),
          createdAt: BigInt(1704067200),
          referralData: null,
        },
      ])

      // Calculate points
      await service.calculatePoints(accountId)

      // Verify points calculation
      // Formula: total_deposits * (0.00005 + 0.0005 * ln(active_referred_users + 1))
      // For 1 active user: 1000 * (0.00005 + 0.0005 * ln(2)) ≈ 0.396
      expect(db.upsertReferralPoints).toHaveBeenCalledWith(
        accountId,
        expect.closeTo(0.396, 2),
        1000, // totalDepositsUsd
        1, // activeReferredUsers
      )
    })

    it('should calculate points correctly for multiple referred users with multiple positions', async () => {
      const referredId2 = '0x789'
      const referralTimestamp2 = new Date('2024-01-02T00:00:00Z')

      // Mock database to return two referred users
      db.getReferredUsers.mockResolvedValue([
        { referredId, chain, referralTimestamp },
        { referredId: referredId2, chain, referralTimestamp: referralTimestamp2 },
      ])

      // Mock client to return positions for both referred users
      client.getPositions.mockResolvedValueOnce([
        {
          id: '0x789',
          account: { id: referredId },
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
          createdTimestamp: BigInt(1704067200), // 2024-01-01T00:00:00Z
          createdBlockNumber: BigInt(12345678),
          claimedSummerToken: BigInt(0),
          claimedSummerTokenNormalized: 0,
          claimableSummerToken: BigInt(0),
          claimableSummerTokenNormalized: 0,
          depositAmountUsd: BigInt(1000),
          createdAt: BigInt(1704067200),
          referralData: null,
        },
      ])

      client.getPositions.mockResolvedValueOnce([
        {
          id: '0xdef',
          account: { id: referredId2 },
          vault: { id: '0xabc' },
          inputTokenDeposits: BigInt(2000),
          inputTokenDepositsNormalized: 2000,
          inputTokenWithdrawalsNormalized: 0,
          inputTokenDepositsNormalizedInUSD: 2000,
          inputTokenWithdrawals: BigInt(0),
          inputTokenWithdrawalsNormalizedInUSD: 0,
          inputTokenBalance: BigInt(2000),
          outputTokenBalance: BigInt(2000),
          stakedInputTokenBalance: BigInt(2000),
          stakedOutputTokenBalance: BigInt(2000),
          unstakedInputTokenBalance: BigInt(0),
          unstakedOutputTokenBalance: BigInt(0),
          inputTokenBalanceNormalized: 2000,
          stakedInputTokenBalanceNormalized: 2000,
          unstakedInputTokenBalanceNormalized: 0,
          inputTokenBalanceNormalizedInUSD: 2000,
          stakedInputTokenBalanceNormalizedInUSD: 2000,
          unstakedInputTokenBalanceNormalizedInUSD: 0,
          createdTimestamp: BigInt(1704153600), // 2024-01-02T00:00:00Z
          createdBlockNumber: BigInt(12345679),
          claimedSummerToken: BigInt(0),
          claimedSummerTokenNormalized: 0,
          claimableSummerToken: BigInt(0),
          claimableSummerTokenNormalized: 0,
          depositAmountUsd: BigInt(2000),
          createdAt: BigInt(1704153600),
          referralData: null,
        },
      ])

      // Calculate points
      await service.calculatePoints(accountId)

      // Verify points calculation
      // Formula: total_deposits * (0.00005 + 0.0005 * ln(active_referred_users + 1))
      // For 2 active users: 3000 * (0.00005 + 0.0005 * ln(3)) ≈ 1.65
      expect(db.upsertReferralPoints).toHaveBeenCalledWith(
        accountId,
        expect.closeTo(1.65, 2),
        3000, // totalDepositsUsd
        2, // activeReferredUsers
      )
    })

    it('should not count positions created before referral timestamp', async () => {
      // Mock database to return one referred user
      db.getReferredUsers.mockResolvedValue([
        {
          referredId,
          chain,
          referralTimestamp,
        },
      ])

      // Mock client to return one position created before referral
      client.getPositions.mockResolvedValue([
        {
          id: '0x789',
          account: { id: referredId },
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
          createdTimestamp: BigInt(1703980800), // 2023-12-31T00:00:00Z
          createdBlockNumber: BigInt(12345677),
          claimedSummerToken: BigInt(0),
          claimedSummerTokenNormalized: 0,
          claimableSummerToken: BigInt(0),
          claimableSummerTokenNormalized: 0,
          depositAmountUsd: BigInt(1000),
          createdAt: BigInt(1703980800),
          referralData: null,
        },
      ])

      // Calculate points
      await service.calculatePoints(accountId)

      // Verify points calculation - should be 0 since position was created before referral
      expect(db.upsertReferralPoints).toHaveBeenCalledWith(
        accountId,
        0,
        0, // totalDepositsUsd
        0, // activeReferredUsers
      )
    })
  })
})
