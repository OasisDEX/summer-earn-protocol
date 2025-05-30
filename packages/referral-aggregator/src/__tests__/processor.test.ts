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
      selectAll: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue([]),
      executeTakeFirst: jest.fn().mockResolvedValue(null),
      executeQuery: jest.fn().mockResolvedValue({ rows: [] }),
    }

    const mockConfig = {
      getConfig: jest.fn().mockResolvedValue({
        enableBackfill: true,
        processingIntervalHours: 1,
        activeUserThresholdUsd: 1,
        pointsFormulaBase: 1,
        pointsFormulaLogMultiplier: 0.1,
      }),
    }

    // Mock the DatabaseService implementation
    ;(DatabaseService as jest.MockedClass<typeof DatabaseService>).mockImplementation(
      () =>
        ({
          rawDb: mockRawDb,
          config: mockConfig,
          hasAnyData: jest.fn(),
          ensureReferralCode: jest.fn(),
          upsertUser: jest.fn(),
          updatePosition: jest.fn(),
          updateUserTotals: jest.fn(),
          recalculateReferralStats: jest.fn(),
          updateDailyRatesAndPoints: jest.fn(),
          updateDailyStats: jest.fn(),
          getLastProcessedTimestamp: jest.fn(),
          updateProcessingCheckpoint: jest.fn(),
          getReferralCode: jest.fn(),
          getUsersReferredBy: jest.fn(),
          getActiveUsersReferredBy: jest.fn(),
          getTopReferralCodes: jest.fn(),
          close: jest.fn(),
          migrate: jest.fn(),
        }) as any,
    )

    // Create processor with mock logger
    processor = new ReferralProcessor({ logger: mockLogger })
  })

  describe('processLatest', () => {
    it('should process successfully when there is new data', async () => {
      const mockDb = (processor as any).db

      // Mock client methods
      mockClient.getValidReferredAccounts.mockResolvedValue({
        validAccounts: [
          { 
            id: 'user1', 
            referralData: { id: 'ref1' },
            referralChain: 'Base' as any,
            referralTimestamp: String(Date.now() / 1000)
          }, 
          { 
            id: 'user2', 
            referralData: { id: 'ref2' },
            referralChain: 'Base' as any,
            referralTimestamp: String(Date.now() / 1000)
          }
        ],
      })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({
        Base: [{
          id: 'user1',
          positions: [{
            id: 'pos1',
            createdTimestamp: '1234567890',
            hourlySnapshots: [{
              id: 'snap1',
              timestamp: String(Date.now() / 1000),
              inputTokenBalanceNormalizedInUSD: '1000'
            }]
          }]
        }]
      })

      // Mock database methods
      mockDb.hasAnyData.mockResolvedValue(true) // Not first run
      mockDb.getLastProcessedTimestamp.mockResolvedValue(new Date(Date.now() - 3600000)) // 1 hour ago
      mockDb.rawDb.select.mockReturnThis()
      mockDb.rawDb.execute.mockResolvedValue([{ id: 'user1' }, { id: 'user2' }])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '2' })

      const result = await processor.processLatest()

      expect(result.success).toBe(true)
      expect(result.usersProcessed).toBe(2)
      expect(result.activeUsers).toBe(2)
      expect(mockDb.upsertUser).toHaveBeenCalledTimes(2)
      expect(mockDb.updateUserTotals).toHaveBeenCalled()
      expect(mockDb.recalculateReferralStats).toHaveBeenCalled()
      expect(mockDb.updateDailyRatesAndPoints).toHaveBeenCalled()
    })

    it('should handle no new data gracefully', async () => {
      const mockDb = (processor as any).db

      // Mock timestamps showing no new data
      const now = new Date()
      now.setMinutes(0, 0, 0)

      mockDb.getLastProcessedTimestamp.mockResolvedValue(now) // Same as current hour

      const result = await processor.processLatest()

      expect(result.success).toBe(true)
      expect(result.usersProcessed).toBe(0)
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

    it('should handle first run (no previous timestamp)', async () => {
      const mockDb = (processor as any).db

      // Mock no previous timestamp (first run)
      mockDb.getLastProcessedTimestamp.mockResolvedValue(null)

      // Mock client methods
      mockClient.getValidReferredAccounts.mockResolvedValue({ validAccounts: [] })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})
      
      // Mock database queries  
      mockDb.rawDb.execute.mockResolvedValue([])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '0' })

      const result = await processor.processLatest()

      expect(result.success).toBe(true)
      expect(mockLogger.log).toHaveBeenCalledWith(expect.stringContaining('First run'))
    })
  })

  describe('backfill', () => {
    it('should backfill successfully from earliest referral', async () => {
      const mockDb = (processor as any).db

      // Mock earliest referral date
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ earliest: new Date('2024-01-01') })
      
      // Mock client methods
      mockClient.getValidReferredAccounts.mockResolvedValue({ validAccounts: [] })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})
      
      // Mock database queries
      mockDb.rawDb.execute.mockResolvedValue([])

      const result = await processor.backfill()

      expect(result.success).toBe(true)
      expect(result.periodStart).toBeDefined()
      expect(result.periodEnd).toBeDefined()
      expect(mockLogger.log).toHaveBeenCalledWith(expect.stringContaining('Backfilling from'))
    })

    it('should handle no referral data', async () => {
      const mockDb = (processor as any).db

      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ earliest: null })
      
      // Mock client methods
      mockClient.getValidReferredAccounts.mockResolvedValue({ validAccounts: [] })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})
      
      // Mock database queries
      mockDb.rawDb.execute.mockResolvedValue([])

      const result = await processor.backfill()

      expect(result.success).toBe(true)
      expect(mockLogger.log).toHaveBeenCalledWith(expect.stringContaining('Backfilling from'))
    })
  })

  describe('processPeriod', () => {
    it('should process period correctly', async () => {
      const mockDb = (processor as any).db
      const periodStart = new Date('2024-01-01T00:00:00Z')
      const periodEnd = new Date('2024-01-01T01:00:00Z')

      // Mock client methods
      mockClient.getValidReferredAccounts.mockResolvedValue({
        validAccounts: [
          { 
            id: 'user1', 
            referralData: { id: 'ref1' },
            referralChain: 'Base' as any,
            referralTimestamp: String(Date.now() / 1000)
          }, 
          { 
            id: 'user2', 
            referralData: { id: 'ref2' },
            referralChain: 'Base' as any,
            referralTimestamp: String(Date.now() / 1000)
          }
        ],
      })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})

      // Mock database methods
      mockDb.rawDb.execute.mockResolvedValue([{ id: 'user1' }, { id: 'user2' }])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '2' })

      const result = await processor.processPeriod(periodStart, periodEnd)

      expect(result.success).toBe(true)
      expect(result.activeUsers).toBe(2)
      expect(mockDb.upsertUser).toHaveBeenCalledTimes(2)
      expect(mockDb.recalculateReferralStats).toHaveBeenCalled()
      expect(mockDb.updateDailyRatesAndPoints).toHaveBeenCalled()
    })

    it('should handle empty results', async () => {
      const mockDb = (processor as any).db

      // Mock client methods
      mockClient.getValidReferredAccounts.mockResolvedValue({ validAccounts: [] })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})

      // Mock database methods
      mockDb.rawDb.execute.mockResolvedValue([])
      mockDb.rawDb.executeTakeFirst.mockResolvedValue({ count: '0' })

      const result = await processor.processPeriod(
        new Date('2024-01-01T00:00:00Z'),
        new Date('2024-01-01T01:00:00Z'),
      )

      expect(result.success).toBe(true)
      expect(result.usersProcessed).toBe(0)
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
          total_points: 1000,
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
      expect(stats.topReferrers[0].id).toBe('top1')
    })
  })

  describe('close', () => {
    it('should close database connection', async () => {
      const mockDb = (processor as any).db
      await processor.close()
      expect(mockDb.close).toHaveBeenCalled()
    })
  })
})
