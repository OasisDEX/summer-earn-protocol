import { ReferralClient } from '../client'
import { DatabaseService } from '../db'
import { HourlyProcessor } from '../hourly-processor'
import { Account } from '../types'

// Mock the dependencies
jest.mock('../client')
jest.mock('../db')

const MockReferralClient = ReferralClient as jest.MockedClass<typeof ReferralClient>
const MockDatabaseService = DatabaseService as jest.MockedClass<typeof DatabaseService>

describe('HourlyProcessor', () => {
  let processor: HourlyProcessor
  let mockClient: jest.Mocked<ReferralClient>
  let mockDb: jest.Mocked<DatabaseService>

  beforeEach(() => {
    jest.clearAllMocks()
    mockClient = new MockReferralClient() as jest.Mocked<ReferralClient>
    mockDb = new MockDatabaseService() as jest.Mocked<DatabaseService>
    processor = new HourlyProcessor(mockClient, mockDb)
  })

  describe('processHourly', () => {
    it('should process first run correctly', async () => {
      // Mock first run
      mockDb.hasAnyData.mockResolvedValue(false)

      // Mock client responses
      const mockAccounts: Account[] = [
        {
          id: '0x123',
          positions: [
            {
              id: '0x456',
              account: { id: '0x123' },
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
          referralData: {
            id: '0xreferrer',
            amountOfReferred: BigInt(1),
          },
          referralTimestamp: BigInt(1704067200),
        },
      ]

      mockClient.processReferredAccountsHourly.mockResolvedValue({
        validAccounts: ['0x123'],
        allReferredAccounts: mockAccounts,
      })

      mockClient.getAllPositionsForAccounts.mockResolvedValue({
        Ethereum: mockAccounts,
      })

      // Run the processor
      await processor.processHourly()

      // Verify calls
      expect(mockClient.processReferredAccountsHourly).toHaveBeenCalledWith(
        undefined, // timestampGt should be undefined for first run
        expect.any(BigInt), // timestampLt should be current time
        true, // isFirstRun should be true
      )

      expect(mockClient.getAllPositionsForAccounts).toHaveBeenCalledWith(['0x123'])

      // Verify database operations
      expect(mockDb.upsertReferralRelationship).toHaveBeenCalledWith(
        '0xreferrer',
        '0x123',
        'Ethereum',
        expect.any(Date),
      )

      expect(mockDb.savePositionSnapshot).toHaveBeenCalledWith(
        '0x123',
        'Ethereum',
        '0x456',
        1000,
        expect.any(Date),
        expect.any(Date),
      )
    })

    it('should process subsequent runs correctly', async () => {
      // Mock subsequent run
      mockDb.hasAnyData.mockResolvedValue(true)

      mockClient.processReferredAccountsHourly.mockResolvedValue({
        validAccounts: [],
        allReferredAccounts: [],
      })

      // Run the processor
      await processor.processHourly()

      // Verify calls
      expect(mockClient.processReferredAccountsHourly).toHaveBeenCalledWith(
        expect.any(BigInt), // timestampGt should be one hour ago
        expect.any(BigInt), // timestampLt should be current time
        false, // isFirstRun should be false
      )

      // Should not call getAllPositionsForAccounts if no valid accounts
      expect(mockClient.getAllPositionsForAccounts).not.toHaveBeenCalled()
    })

    it('should handle accounts without referral data', async () => {
      mockDb.hasAnyData.mockResolvedValue(false)

      const mockAccounts: Account[] = [
        {
          id: '0x123',
          positions: [
            {
              id: '0x456',
              account: { id: '0x123' },
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
          referralData: null, // No referral data
          referralTimestamp: null,
        },
      ]

      mockClient.processReferredAccountsHourly.mockResolvedValue({
        validAccounts: ['0x123'],
        allReferredAccounts: mockAccounts,
      })

      mockClient.getAllPositionsForAccounts.mockResolvedValue({
        Ethereum: mockAccounts,
      })

      await processor.processHourly()

      // Should not call upsertReferralRelationship for accounts without referral data
      expect(mockDb.upsertReferralRelationship).not.toHaveBeenCalled()

      // Should still save position snapshots
      expect(mockDb.savePositionSnapshot).toHaveBeenCalledWith(
        '0x123',
        'Ethereum',
        '0x456',
        1000,
        expect.any(Date),
        undefined, // No referral timestamp
      )
    })
  })
})
