import { ReferralClient } from '../client'
import { DatabaseService } from '../db'
import { Logger, ReferralProcessor } from '../processor'

// Mock dependencies
jest.mock('../db')
jest.mock('../client')

describe('ReferralProcessor', () => {
  let processor: ReferralProcessor
  let mockLogger: Logger
  let mockClient: jest.Mocked<ReferralClient>

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks()

    // Create mock logger
    mockLogger = {
      log: jest.fn(),
      error: jest.fn(),
      warn: jest.fn(),
    }

    // Mock ReferralClient
    mockClient = {
      getValidReferredAccounts: jest.fn(),
      getAllPositionsWithHourlySnapshots: jest.fn(),
      validateAccounts: jest.fn(),
    } as any

    // Mock the ReferralClient constructor
    ;(ReferralClient as jest.MockedClass<typeof ReferralClient>).mockImplementation(
      () => mockClient,
    )

    // Mock rawDb with Kysely-like interface
    const mockRawDb = {
      selectFrom: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue([]),
      executeTakeFirst: jest.fn().mockResolvedValue(null),
      executeQuery: jest.fn().mockResolvedValue({ rows: [] }),
    }

    const mockConfig = {
      getConfig: jest.fn().mockResolvedValue({
        activeUserThresholdUsd: '100',
        pointsFormulaBase: 0.00005,
        pointsFormulaLogMultiplier: 0.0005,
      }),
    }

    const mockRawPool = {
      connect: jest.fn().mockResolvedValue({
        query: jest.fn(),
        release: jest.fn(),
      }),
    }

    // Mock the DatabaseService implementation
    ;(DatabaseService as jest.MockedClass<typeof DatabaseService>).mockImplementation(
      () =>
        ({
          rawDb: mockRawDb,
          rawPool: mockRawPool,
          config: mockConfig,
          getLastProcessedTimestamp: jest.fn(),
          updateProcessingCheckpoint: jest.fn(),
          upsertUser: jest.fn(),
          updatePosition: jest.fn(),
          updateUserTotals: jest.fn(),
          recalculateReferralStats: jest.fn(),
          updateDailyRatesAndPoints: jest.fn(),
          updateDailyStats: jest.fn(),
          getTopReferralCodes: jest.fn(),
          close: jest.fn(),
          migrate: jest.fn(),
          ensureReferralCode: jest.fn(),
        }) as any,
    )

    // Create processor with mock logger
    processor = new ReferralProcessor({ logger: mockLogger })
  })

  describe('processLatest', () => {
    it('should process successfully when there is new data', async () => {
      const mockDb = (processor as any).db
      const now = new Date()
      now.setMinutes(0, 0, 0)
      const periodStart = new Date(now.getTime() - 60 * 60 * 1000) // 1 hour ago

      // Mock last processed timestamp
      mockDb.getLastProcessedTimestamp.mockResolvedValue(periodStart)

      // Mock client methods
      mockClient.getValidReferredAccounts.mockResolvedValue({
        validAccounts: [
          {
            id: 'user1',
            referralData: { id: 'referrer1' },
            referralChain: 'Base',
            referralTimestamp: '1704067200',
          },
          {
            id: 'user2',
            referralData: { id: 'referrer1' },
            referralChain: 'Base',
            referralTimestamp: '1704067200',
          },
        ],
      })

      // Mock positions data
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({
        base: [
          {
            id: 'user1',
            positions: [
              {
                id: 'pos1',
                createdTimestamp: '1704067200',
                hourlySnapshots: [
                  {
                    id: 'snapshot1',
                    timestamp: Math.floor(now.getTime() / 1000).toString(),
                    inputTokenBalanceNormalizedInUSD: '1000',
                  },
                ],
              },
            ],
          },
        ],
      })

      // Mock database queries
      mockDb.rawDb.selectFrom.mockReturnValue(mockDb.rawDb)
      mockDb.rawDb.execute.mockResolvedValue([{ id: 'user1' }, { id: 'user2' }])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '2' })

      const result = await processor.processLatest()

      if (!result.success) {
        console.error('Test failed with error:', result.error)
      }

      expect(result.success).toBe(true)
      expect(result.usersProcessed).toBe(2)
      expect(result.activeUsers).toBe(2)
      expect(mockDb.updateProcessingCheckpoint).toHaveBeenCalledWith(now)
      expect(mockDb.upsertUser).toHaveBeenCalledTimes(2)
      expect(mockDb.updatePosition).toHaveBeenCalled()
      expect(mockDb.recalculateReferralStats).toHaveBeenCalled()
      expect(mockDb.updateDailyRatesAndPoints).toHaveBeenCalled()
    })

    it('should handle first run (no previous timestamp)', async () => {
      const mockDb = (processor as any).db

      // Mock no previous timestamp (first run)
      mockDb.getLastProcessedTimestamp.mockResolvedValue(null)

      // Mock empty data
      mockClient.getValidReferredAccounts.mockResolvedValue({ validAccounts: [] })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})
      mockDb.rawDb.execute.mockResolvedValue([])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '0' })

      const result = await processor.processLatest()

      expect(result.success).toBe(true)
      expect(mockLogger.log).toHaveBeenCalledWith(expect.stringContaining('First run'))
    })

    it('should handle no new data gracefully', async () => {
      const mockDb = (processor as any).db
      const now = new Date()
      now.setMinutes(0, 0, 0)

      // Mock timestamps showing no new data
      mockDb.getLastProcessedTimestamp.mockResolvedValue(now)

      const result = await processor.processLatest()

      expect(result.success).toBe(true)
      expect(result.usersProcessed).toBe(0)
      expect(result.activeUsers).toBe(0)
      expect(mockLogger.log).toHaveBeenCalledWith(expect.stringContaining('No new data to process'))
    })

    it('should handle errors gracefully', async () => {
      const mockDb = (processor as any).db
      mockDb.getLastProcessedTimestamp.mockRejectedValue(new Error('Database error'))

      const result = await processor.processLatest()

      expect(result.success).toBe(false)
      expect(result.error).toBeDefined()
      expect(mockLogger.error).toHaveBeenCalled()
    })
  })

  describe('processPeriod', () => {
    it('should process period successfully with positions', async () => {
      const mockDb = (processor as any).db
      const periodStart = new Date('2024-01-01T00:00:00Z')
      const periodEnd = new Date('2024-01-01T01:00:00Z')

      // Mock client methods
      mockClient.getValidReferredAccounts.mockResolvedValue({
        validAccounts: [
          {
            id: 'user1',
            referralData: { id: 'referrer1' },
            referralChain: 'Base',
            referralTimestamp: '1704067200',
          },
        ],
      })

      // Mock positions with hourly snapshots
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({
        base: [
          {
            id: 'user1',
            positions: [
              {
                id: 'pos1',
                createdTimestamp: '1704067200',
                hourlySnapshots: [
                  {
                    id: 'snapshot1',
                    timestamp: Math.floor(periodEnd.getTime() / 1000).toString(),
                    inputTokenBalanceNormalizedInUSD: '1000',
                  },
                ],
              },
            ],
          },
        ],
      })

      // Mock database queries
      mockDb.rawDb.execute.mockResolvedValue([{ id: 'user1' }])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '1' })

      const result = await processor.processPeriod(periodStart, periodEnd)

      expect(result.success).toBe(true)
      expect(result.usersProcessed).toBe(1)
      expect(result.activeUsers).toBe(1)
      expect(mockDb.upsertUser).toHaveBeenCalledWith('user1', {
        referrerId: 'referrer1',
        referralChain: 'Base',
        referralTimestamp: new Date(1704067200000),
      })
      expect(mockDb.updatePosition).toHaveBeenCalledWith('pos1', 'base', 'user1', 1000)
      expect(mockDb.updateUserTotals).toHaveBeenCalledWith('user1')
      expect(mockDb.recalculateReferralStats).toHaveBeenCalled()
      expect(mockDb.updateDailyRatesAndPoints).toHaveBeenCalled()
      expect(mockDb.updateDailyStats).toHaveBeenCalled()
    })

    it('should handle multiple chains correctly', async () => {
      const mockDb = (processor as any).db
      const periodStart = new Date('2024-01-01T00:00:00Z')
      const periodEnd = new Date('2024-01-01T01:00:00Z')

      mockClient.getValidReferredAccounts.mockResolvedValue({ validAccounts: [] })

      // Mock positions on multiple chains
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({
        base: [
          {
            id: 'user1',
            positions: [
              {
                id: 'pos1',
                createdTimestamp: '1704067200',
                hourlySnapshots: [
                  {
                    id: 'snapshot1',
                    timestamp: Math.floor(periodEnd.getTime() / 1000).toString(),
                    inputTokenBalanceNormalizedInUSD: '500',
                  },
                ],
              },
            ],
          },
        ],
        ethereum: [
          {
            id: 'user1',
            positions: [
              {
                id: 'pos2',
                createdTimestamp: '1704067200',
                hourlySnapshots: [
                  {
                    id: 'snapshot2',
                    timestamp: Math.floor(periodEnd.getTime() / 1000).toString(),
                    inputTokenBalanceNormalizedInUSD: '750',
                  },
                ],
              },
            ],
          },
        ],
      })

      mockDb.rawDb.execute.mockResolvedValue([{ id: 'user1' }])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '1' })

      const result = await processor.processPeriod(periodStart, periodEnd)

      expect(result.success).toBe(true)
      expect(mockDb.updatePosition).toHaveBeenCalledTimes(2)
      expect(mockDb.updatePosition).toHaveBeenCalledWith('pos1', 'base', 'user1', 500)
      expect(mockDb.updatePosition).toHaveBeenCalledWith('pos2', 'ethereum', 'user1', 750)
      expect(mockDb.updateUserTotals).toHaveBeenCalledTimes(2) // Once per chain with positions
    })

    it('should filter snapshots by period correctly', async () => {
      const mockDb = (processor as any).db
      const periodStart = new Date('2024-01-01T00:00:00Z')
      const periodEnd = new Date('2024-01-01T01:00:00Z')

      mockClient.getValidReferredAccounts.mockResolvedValue({ validAccounts: [] })

      // Mock positions with snapshots before, during, and after period
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({
        base: [
          {
            id: 'user1',
            positions: [
              {
                id: 'pos1',
                createdTimestamp: '1704067200',
                hourlySnapshots: [
                  {
                    id: 'snapshot1',
                    timestamp: Math.floor(periodStart.getTime() / 1000 - 3600).toString(), // Before period
                    inputTokenBalanceNormalizedInUSD: '100',
                  },
                  {
                    id: 'snapshot2',
                    timestamp: Math.floor(periodStart.getTime() / 1000 + 1800).toString(), // During period
                    inputTokenBalanceNormalizedInUSD: '200',
                  },
                  {
                    id: 'snapshot3',
                    timestamp: Math.floor(periodEnd.getTime() / 1000 - 1).toString(), // Latest in period
                    inputTokenBalanceNormalizedInUSD: '300',
                  },
                  {
                    id: 'snapshot4',
                    timestamp: Math.floor(periodEnd.getTime() / 1000 + 3600).toString(), // After period
                    inputTokenBalanceNormalizedInUSD: '400',
                  },
                ],
              },
            ],
          },
        ],
      })

      mockDb.rawDb.execute.mockResolvedValue([{ id: 'user1' }])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '1' })

      const result = await processor.processPeriod(periodStart, periodEnd)

      expect(result.success).toBe(true)
      // Should use the latest snapshot within the period (300, not 400)
      expect(mockDb.updatePosition).toHaveBeenCalledWith('pos1', 'base', 'user1', 300)
    })
  })

  describe('backfill', () => {
    it('should backfill successfully from earliest referral', async () => {
      const mockDb = (processor as any).db
      const earliestDate = new Date('2024-01-01')
      const now = new Date()

      // Mock earliest referral date query
      mockDb.rawDb.executeTakeFirst.mockResolvedValueOnce({ earliest: earliestDate })

      // Mock period processing
      mockClient.getValidReferredAccounts.mockResolvedValue({ validAccounts: [] })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})
      mockDb.rawDb.execute.mockResolvedValue([])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '0' })

      const result = await processor.backfill()

      expect(result.success).toBe(true)
      expect(result.periodStart).toEqual(earliestDate)
      expect(mockDb.updateProcessingCheckpoint).toHaveBeenCalled()
      expect(mockLogger.log).toHaveBeenCalledWith(expect.stringContaining('Backfilling from'))
    })

    it('should backfill from specified date', async () => {
      const mockDb = (processor as any).db
      const fromDate = new Date('2024-06-01')

      // Mock period processing
      mockClient.getValidReferredAccounts.mockResolvedValue({ validAccounts: [] })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})
      mockDb.rawDb.execute.mockResolvedValue([])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '0' })

      const result = await processor.backfill(fromDate)

      expect(result.success).toBe(true)
      expect(result.periodStart).toEqual(fromDate)
      expect(mockLogger.log).toHaveBeenCalledWith(expect.stringContaining('Backfilling from'))
    })

    it('should handle no referral data', async () => {
      const mockDb = (processor as any).db

      // No earliest date
      mockDb.rawDb.executeTakeFirst.mockResolvedValueOnce({ earliest: null })

      // Mock period processing
      mockClient.getValidReferredAccounts.mockResolvedValue({ validAccounts: [] })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})
      mockDb.rawDb.execute.mockResolvedValue([])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '0' })

      const result = await processor.backfill()

      expect(result.success).toBe(true)
      // Should use current date if no data
      expect(result.periodStart).toBeDefined()
    })

    it('should handle backfill errors', async () => {
      const mockDb = (processor as any).db
      mockDb.rawDb.executeTakeFirst.mockRejectedValue(new Error('Database error'))

      const result = await processor.backfill()

      expect(result.success).toBe(false)
      expect(result.error).toBeDefined()
      expect(mockLogger.error).toHaveBeenCalledWith(
        expect.stringContaining('Backfill failed'),
        expect.any(Error),
      )
    })
  })

  describe('getStats', () => {
    it('should return comprehensive statistics', async () => {
      const mockDb = (processor as any).db
      const mockDate = new Date('2024-01-01T12:00:00Z')

      mockDb.getLastProcessedTimestamp.mockResolvedValue(mockDate)

      // Mock count queries
      mockDb.rawDb.executeTakeFirst
        .mockResolvedValueOnce({ count: '10' }) // total referral codes
        .mockResolvedValueOnce({ count: '50' }) // total active users

      // Mock top referrers
      mockDb.getTopReferralCodes.mockResolvedValue([
        {
          id: 'top1',
          custom_code: 'CUSTOM1',
          total_points_earned: 1000,
          points_per_day: 100,
          active_users_count: 5,
          total_deposits_usd: 5000,
        },
      ])

      const stats = await processor.getStats()

      expect(stats.lastProcessed).toEqual(mockDate)
      expect(stats.totalReferralCodes).toBe(10)
      expect(stats.totalActiveUsers).toBe(50)
      expect(stats.topReferrers).toHaveLength(1)
      expect(stats.topReferrers[0]).toEqual({
        id: 'top1',
        customCode: 'CUSTOM1',
        totalPoints: 1000,
        pointsPerDay: 100,
        activeUsers: 5,
        totalDeposits: 5000,
      })
    })

    it('should handle empty statistics', async () => {
      const mockDb = (processor as any).db

      mockDb.getLastProcessedTimestamp.mockResolvedValue(null)
      mockDb.rawDb.executeTakeFirst
        .mockResolvedValueOnce({ count: '0' })
        .mockResolvedValueOnce({ count: '0' })
      mockDb.getTopReferralCodes.mockResolvedValue([])

      const stats = await processor.getStats()

      expect(stats.lastProcessed).toBeNull()
      expect(stats.totalReferralCodes).toBe(0)
      expect(stats.totalActiveUsers).toBe(0)
      expect(stats.topReferrers).toHaveLength(0)
    })
  })

  describe('close', () => {
    it('should close database connection', async () => {
      const mockDb = (processor as any).db
      await processor.close()
      expect(mockDb.close).toHaveBeenCalled()
    })
  })

  describe('getLatestSnapshot', () => {
    it('should return null for empty snapshots', () => {
      const result = (processor as any).getLatestSnapshot(
        undefined,
        new Date('2024-01-01'),
        new Date('2024-01-02'),
      )
      expect(result).toBeNull()

      const result2 = (processor as any).getLatestSnapshot(
        [],
        new Date('2024-01-01'),
        new Date('2024-01-02'),
      )
      expect(result2).toBeNull()
    })

    it('should return latest snapshot within period', () => {
      const periodStart = new Date('2024-01-01T00:00:00Z')
      const periodEnd = new Date('2024-01-01T06:00:00Z')

      const snapshots = [
        { id: 'snap1', timestamp: '1704070800', inputTokenBalanceNormalizedInUSD: '100' }, // 01:00
        { id: 'snap2', timestamp: '1704074400', inputTokenBalanceNormalizedInUSD: '200' }, // 02:00
        { id: 'snap3', timestamp: '1704078000', inputTokenBalanceNormalizedInUSD: '300' }, // 03:00
      ]

      const result = (processor as any).getLatestSnapshot(snapshots, periodStart, periodEnd)

      expect(result).toEqual(snapshots[2])
    })

    it('should filter out snapshots outside period', () => {
      const periodStart = new Date('2024-01-01T02:00:00Z')
      const periodEnd = new Date('2024-01-01T04:00:00Z')

      const snapshots = [
        { id: 'snap1', timestamp: '1704070800', inputTokenBalanceNormalizedInUSD: '100' }, // 01:00 - before
        { id: 'snap2', timestamp: '1704078000', inputTokenBalanceNormalizedInUSD: '200' }, // 03:00 - in period
        { id: 'snap3', timestamp: '1704085200', inputTokenBalanceNormalizedInUSD: '300' }, // 05:00 - after
      ]

      const result = (processor as any).getLatestSnapshot(snapshots, periodStart, periodEnd)

      expect(result).toEqual(snapshots[1])
    })
  })
})
