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

    // Mock DatabaseService constructor to return our mocked methods
    const mockRawDb = {
      query: jest.fn(),
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
          getAllReferredActiveUsers: jest.fn(),
          updateUserActivityStatus: jest.fn(),
          recordPointDistribution: jest.fn(),
          close: jest.fn(),
          migrate: jest.fn(),
          updateReferralRelationships: jest.fn(),
          updatePositionSnapshots: jest.fn(),
          getReferralPoints: jest.fn(),
          getLastCalculationTimestamp: jest.fn(),
          hasAnyData: jest.fn(),
          storeReferredAccounts: jest.fn(),
          upsertUser: jest.fn(),
          savePositionSnapshot: jest.fn(),
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
        validAccounts: [{ id: 'user1' }, { id: 'user2' }],
      })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})

      // Mock database methods
      mockDb.hasAnyData.mockResolvedValue(true) // Not first run
      mockDb.rawDb.query
        .mockResolvedValueOnce({ rows: [{ value: '2024-01-01T00:00:00Z' }] }) // getLastExecutionTimestamp
        .mockResolvedValueOnce({ rows: [] }) // updateUserActivityForPeriod query 1
        .mockResolvedValueOnce({ rows: [] }) // updateUserActivityForPeriod query 2
        .mockResolvedValueOnce({ rows: [] }) // updateLastExecutionTimestamp

      // Mock referral data
      mockDb.getAllReferredActiveUsers.mockResolvedValue([
        {
          referrerId: 'user1',
          referredUsers: [
            {
              referredId: 'user2',
              chain: 'base' as any,
              referralTimestamp: new Date('2024-01-01'),
              totalDepositsUsd: 100,
              isActive: true,
            },
          ],
        },
      ])

      const result = await processor.processLatest()

      expect(result.success).toBe(true)
      expect(result.pointsDistributed).toBeGreaterThan(0)
      expect(result.usersProcessed).toBe(1)
      expect(result.activeUsers).toBe(1)
      expect(mockDb.recordPointDistribution).toHaveBeenCalledTimes(1)
    })

    it('should handle no new data gracefully', async () => {
      const mockDb = (processor as any).db

      // Mock timestamps showing no new data
      const now = new Date()
      now.setMinutes(0, 0, 0)

      mockDb.rawDb.query.mockResolvedValueOnce({ rows: [{ value: now.toISOString() }] }) // Same as current hour

      const result = await processor.processLatest()

      expect(result.success).toBe(true)
      expect(result.pointsDistributed).toBe(0)
      expect(result.usersProcessed).toBe(0)
      expect(mockLogger.log).toHaveBeenCalledWith(expect.stringContaining('No new data to process'))
    })

    it('should handle errors gracefully', async () => {
      const mockDb = (processor as any).db
      mockDb.rawDb.query.mockRejectedValue(new Error('Database error'))

      const result = await processor.processLatest()

      expect(result.success).toBe(false)
      expect(result.error).toBeDefined()
      expect(mockLogger.error).toHaveBeenCalled()
    })
  })

  describe('backfill', () => {
    it('should backfill successfully from earliest referral', async () => {
      const mockDb = (processor as any).db

      // Mock config check - already set in beforeEach

      // Mock earliest referral date
      mockDb.rawDb.query
        .mockResolvedValueOnce({ rows: [{ earliest_referral: new Date('2024-01-01') }] }) // getEarliestReferralDate
        .mockResolvedValue({ rows: [] }) // All other queries

      // Mock referral data
      mockDb.getAllReferredActiveUsers.mockResolvedValue([
        {
          referrerId: 'user1',
          referredUsers: [
            {
              referredId: 'user2',
              chain: 'base' as any,
              referralTimestamp: new Date('2024-01-01'),
              totalDepositsUsd: 100,
              isActive: true,
            },
          ],
        },
      ])

      const result = await processor.backfill()

      expect(result.success).toBe(true)
      expect(result.periodStart).toBeDefined()
      expect(result.periodEnd).toBeDefined()
      expect(mockLogger.log).toHaveBeenCalledWith(expect.stringContaining('Backfilling from'))
    })

    it('should reject backfill when disabled in config', async () => {
      const mockDb = (processor as any).db

      mockDb.config.getConfig.mockResolvedValue({
        enableBackfill: false,
      })

      const result = await processor.backfill()

      expect(result.success).toBe(false)
      expect(result.error?.message).toContain('Backfill is disabled')
    })

    it('should handle no referral data', async () => {
      const mockDb = (processor as any).db

      mockDb.rawDb.query.mockResolvedValueOnce({ rows: [{ earliest_referral: null }] })

      const result = await processor.backfill()

      expect(result.success).toBe(true)
      expect(result.pointsDistributed).toBe(0)
      expect(mockLogger.log).toHaveBeenCalledWith(expect.stringContaining('No referral data found'))
    })
  })

  describe('processPeriod', () => {
    it('should calculate points correctly using the formula', async () => {
      const mockDb = (processor as any).db
      const periodStart = new Date('2024-01-01T00:00:00Z')
      const periodEnd = new Date('2024-01-01T01:00:00Z')

      // Mock client methods
      mockClient.getValidReferredAccounts.mockResolvedValue({
        validAccounts: [{ id: 'user1' }, { id: 'user2' }],
      })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})

      // Mock database methods
      mockDb.hasAnyData.mockResolvedValue(true) // Not first run
      mockDb.rawDb.query.mockResolvedValue({ rows: [] })

      // Mock referral data with multiple users
      mockDb.getAllReferredActiveUsers.mockResolvedValue([
        {
          referrerId: 'referrer1',
          referredUsers: [
            {
              referredId: 'user1',
              chain: 'base' as any,
              referralTimestamp: new Date('2024-01-01'),
              totalDepositsUsd: 100,
              isActive: true,
            },
            {
              referredId: 'user2',
              chain: 'base' as any,
              referralTimestamp: new Date('2024-01-01'),
              totalDepositsUsd: 200,
              isActive: true,
            },
          ],
        },
      ])

      const result = await processor.processPeriod(periodStart, periodEnd)

      expect(result.success).toBe(true)
      expect(result.activeUsers).toBe(2)

      // Verify points calculation: totalDeposits * (base + log_multiplier * ln(activeUsers + 1))
      // totalDeposits = 300, base = 1, log_multiplier = 0.1, activeUsers = 2
      // points = 300 * (1 + 0.1 * ln(3)) ≈ 300 * 1.1099 ≈ 332.97
      expect(result.pointsDistributed).toBeCloseTo(332.97, 1)

      expect(mockDb.recordPointDistribution).toHaveBeenCalledWith(
        'referrer1',
        'referrer1',
        expect.any(Number),
        300,
        2,
        periodStart,
        periodEnd,
      )
    })

    it('should skip referrers with no active users', async () => {
      const mockDb = (processor as any).db

      // Mock client methods
      mockClient.getValidReferredAccounts.mockResolvedValue({ validAccounts: [] })
      mockClient.getAllPositionsWithHourlySnapshots.mockResolvedValue({})

      // Mock database methods
      mockDb.hasAnyData.mockResolvedValue(true) // Not first run
      mockDb.rawDb.query.mockResolvedValue({ rows: [] })

      mockDb.getAllReferredActiveUsers.mockResolvedValue([
        {
          referrerId: 'referrer1',
          referredUsers: [
            {
              referredId: 'user1',
              chain: 'base' as any,
              referralTimestamp: new Date('2024-01-01'),
              totalDepositsUsd: 100,
              isActive: false, // Not active
            },
          ],
        },
      ])

      const result = await processor.processPeriod(
        new Date('2024-01-01T00:00:00Z'),
        new Date('2024-01-01T01:00:00Z'),
      )

      expect(result.success).toBe(true)
      expect(result.pointsDistributed).toBe(0)
      expect(result.usersProcessed).toBe(0)
      expect(mockDb.recordPointDistribution).not.toHaveBeenCalled()
    })
  })

  describe('getStats', () => {
    it('should return comprehensive statistics', async () => {
      const mockDb = (processor as any).db
      const mockDate = new Date('2024-01-01T12:00:00Z')

      mockDb.rawDb.query
        .mockResolvedValueOnce({ rows: [{ value: mockDate.toISOString() }] }) // last execution
        .mockResolvedValueOnce({ rows: [{ count: '10' }] }) // total referrers
        .mockResolvedValueOnce({ rows: [{ count: '50' }] }) // total active users
        .mockResolvedValueOnce({ rows: [{ count: '100' }] }) // total distributions
        .mockResolvedValueOnce({
          rows: [
            {
              account_id: 'top1',
              points: 1000,
              total_deposits_usd: 5000,
              active_referred_users: 5,
            },
          ],
        }) // top referrers

      const stats = await processor.getStats()

      expect(stats.lastExecution).toEqual(mockDate)
      expect(stats.totalReferrers).toBe(10)
      expect(stats.totalActiveUsers).toBe(50)
      expect(stats.totalPointDistributions).toBe(100)
      expect(stats.topReferrers).toHaveLength(1)
      expect(stats.topReferrers[0].accountId).toBe('top1')
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
