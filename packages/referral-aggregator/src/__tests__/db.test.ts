import { sql } from 'kysely'
import { Pool } from 'pg'
import { ConfigService } from '../config-updated'
import { DatabaseService } from '../db'

// Mock dependencies
jest.mock('pg')
jest.mock('../config-updated')
jest.mock('../migrations/kysely-migrator')

// Mock kysely sql template literals
const mockCompiledQuery = {
  sql: 'mock sql',
  parameters: [],
}

jest.mock('kysely', () => ({
  ...jest.requireActual('kysely'),
  sql: jest.fn(() => ({
    compile: jest.fn(() => mockCompiledQuery),
  })),
}))

describe('DatabaseService', () => {
  let db: DatabaseService
  let mockPool: jest.Mocked<Pool>
  let mockKysely: any
  let mockConfig: jest.Mocked<ConfigService>

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks()

    // Mock Pool
    mockPool = {
      connect: jest.fn(),
      query: jest.fn(),
      end: jest.fn(),
    } as any

    // Mock ConfigService
    mockConfig = {
      getConfig: jest.fn().mockResolvedValue({
        activeUserThresholdUsd: '100',
        pointsFormulaBase: 0.00005,
        pointsFormulaLogMultiplier: 0.0005,
      }),
    } as any

    // Mock Kysely methods with chaining
    mockKysely = {
      insertInto: jest.fn().mockReturnThis(),
      values: jest.fn().mockReturnThis(),
      onConflict: jest.fn().mockReturnThis(),
      doNothing: jest.fn().mockReturnThis(),
      doUpdateSet: jest.fn().mockReturnThis(),
      column: jest.fn().mockReturnThis(),
      columns: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue({ rows: [] }),
      updateTable: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      selectFrom: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      selectAll: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      executeTakeFirst: jest.fn().mockResolvedValue(null),
      executeQuery: jest.fn().mockResolvedValue({ rows: [] }),
      destroy: jest.fn(),
      fn: {
        count: jest.fn().mockReturnValue({ as: jest.fn().mockReturnValue('mock_count') }),
        sum: jest.fn().mockReturnValue({ as: jest.fn().mockReturnValue('mock_sum') }),
      },
    }

    // Mock Pool constructor
    ;(Pool as jest.MockedClass<typeof Pool>).mockImplementation(() => mockPool)

    // Mock ConfigService constructor
    ;(ConfigService as jest.MockedClass<typeof ConfigService>).mockImplementation(() => mockConfig)

    // Create service instance
    db = new DatabaseService()

    // Replace the Kysely instance with our mock
    ;(db as any).db = mockKysely
  })

  describe('constructor', () => {
    it('should initialize with default database config', () => {
      expect(Pool).toHaveBeenCalledWith({
        host: '127.0.0.1',
        port: 5432,
        database: 'referral_points',
        user: 'postgres',
        password: 'postgres',
      })
    })
  })

  describe('hasAnyData', () => {
    it('should return true when data exists', async () => {
      mockKysely.executeTakeFirst.mockResolvedValue({ count: '5' })

      const result = await db.hasAnyData()

      expect(result).toBe(true)
      expect(mockKysely.selectFrom).toHaveBeenCalledWith('users')
      expect(mockKysely.executeTakeFirst).toHaveBeenCalled()
    })

    it('should return false when no data exists', async () => {
      mockKysely.executeTakeFirst.mockResolvedValue({ count: '0' })

      const result = await db.hasAnyData()

      expect(result).toBe(false)
    })

    it('should return false when result is null', async () => {
      mockKysely.executeTakeFirst.mockResolvedValue(null)

      const result = await db.hasAnyData()

      expect(result).toBe(false)
    })
  })

  describe('ensureReferralCode', () => {
    it('should create referral code with defaults', async () => {
      await db.ensureReferralCode('ref123')

      expect(mockKysely.insertInto).toHaveBeenCalledWith('referral_codes')
      expect(mockKysely.values).toHaveBeenCalledWith({
        id: 'ref123',
        custom_code: null,
        total_points_earned: '0',
        total_deposits_usd: '0',
        active_users_count: 0,
        points_per_day: '0',
        fees_per_day: '0',
      })
      expect(mockKysely.execute).toHaveBeenCalled()
    })

    it('should create referral code with custom code', async () => {
      await db.ensureReferralCode('ref123', 'CUSTOM123')

      expect(mockKysely.values).toHaveBeenCalledWith(
        expect.objectContaining({
          id: 'ref123',
          custom_code: 'CUSTOM123',
        }),
      )
    })

    it('should handle conflicts with doNothing', async () => {
      await db.ensureReferralCode('ref123')

      expect(mockKysely.onConflict).toHaveBeenCalled()
    })
  })

  describe('upsertUser', () => {
    it('should insert new user with referral info', async () => {
      await db.upsertUser('user123', {
        referrerId: 'ref123',
        referralChain: 'Base' as any,
        referralTimestamp: new Date('2024-01-01'),
      })

      // Should ensure referral code exists first
      expect(mockKysely.insertInto).toHaveBeenCalledWith('referral_codes')

      // Then insert user
      expect(mockKysely.insertInto).toHaveBeenCalledWith('users')
      expect(mockKysely.values).toHaveBeenCalledWith({
        id: 'user123',
        referrer_id: 'ref123',
        referral_chain: 'Base',
        referral_timestamp: new Date('2024-01-01'),
        total_deposits_usd: '0',
        is_active: false,
      })
    })

    it('should handle user without referrer', async () => {
      await db.upsertUser('user123', {})

      expect(mockKysely.insertInto).toHaveBeenCalledWith('users')
      expect(mockKysely.values).toHaveBeenCalledWith({
        id: 'user123',
        referrer_id: null,
        referral_chain: null,
        referral_timestamp: null,
        total_deposits_usd: '0',
        is_active: false,
      })
    })

    it('should handle conflicts with doUpdateSet', async () => {
      await db.upsertUser('user123', { referrerId: 'ref123' })

      expect(mockKysely.onConflict).toHaveBeenCalled()
    })
  })

  describe('updatePosition', () => {
    it('should insert new position', async () => {
      await db.updatePosition('pos123', 'Base' as any, 'user123', 1000.5)

      expect(mockKysely.insertInto).toHaveBeenCalledWith('positions')
      expect(mockKysely.values).toHaveBeenCalledWith({
        id: 'pos123',
        chain: 'Base',
        user_id: 'user123',
        current_deposit_usd: '1000.5',
        last_synced_at: expect.any(Date),
      })
    })

    it('should handle conflicts with doUpdateSet', async () => {
      await db.updatePosition('pos123', 'Base' as any, 'user123', 1000.5)

      expect(mockKysely.onConflict).toHaveBeenCalled()
    })
  })

  describe('updateUserTotals', () => {
    it('should update user totals and mark as active', async () => {
      // Mock position sum query
      mockKysely.executeTakeFirst.mockResolvedValue({ total_deposits: '500' })

      await db.updateUserTotals('user123')

      expect(mockKysely.selectFrom).toHaveBeenCalledWith('positions')
      expect(mockKysely.where).toHaveBeenCalledWith('user_id', '=', 'user123')

      expect(mockKysely.updateTable).toHaveBeenCalledWith('users')
      expect(mockKysely.set).toHaveBeenCalledWith({
        total_deposits_usd: '500',
        is_active: true, // 500 > 100 threshold
        last_activity_at: expect.any(Date),
      })
    })

    it('should mark user as inactive when below threshold', async () => {
      mockKysely.executeTakeFirst.mockResolvedValue({ total_deposits: '50' })

      await db.updateUserTotals('user123')

      expect(mockKysely.set).toHaveBeenCalledWith(
        expect.objectContaining({
          is_active: false,
        }),
      )
    })

    it('should handle null result from position sum', async () => {
      mockKysely.executeTakeFirst.mockResolvedValue(null)

      await db.updateUserTotals('user123')

      expect(mockKysely.set).toHaveBeenCalledWith(
        expect.objectContaining({
          total_deposits_usd: '0',
          is_active: false,
        }),
      )
    })
  })

  describe('recalculateReferralStats', () => {
    it('should execute stats update query', async () => {
      await db.recalculateReferralStats()

      expect(mockKysely.executeQuery).toHaveBeenCalled()
      expect(sql).toHaveBeenCalled()
    })
  })

  describe('updateDailyRatesAndPoints', () => {
    it('should update daily rates and accumulate points', async () => {
      // Mock active users count
      mockKysely.executeTakeFirst.mockResolvedValue({ count: '100' })

      await db.updateDailyRatesAndPoints()

      expect(mockKysely.selectFrom).toHaveBeenCalledWith('users')
      expect(mockKysely.where).toHaveBeenCalledWith('is_active', '=', true)
      expect(mockKysely.executeQuery).toHaveBeenCalled()
      expect(sql).toHaveBeenCalled()
    })

    it('should handle no active users', async () => {
      mockKysely.executeTakeFirst.mockResolvedValue({ count: '0' })

      await db.updateDailyRatesAndPoints()

      expect(mockKysely.executeQuery).toHaveBeenCalled()
    })
  })

  describe('updateDailyStats', () => {
    it('should insert or update daily stats', async () => {
      await db.updateDailyStats()

      expect(mockKysely.executeQuery).toHaveBeenCalled()
      expect(sql).toHaveBeenCalled()
    })
  })

  describe('getLastProcessedTimestamp', () => {
    it('should return last processed timestamp', async () => {
      const mockDate = new Date('2024-01-01T12:00:00Z')
      mockKysely.executeTakeFirst.mockResolvedValue({
        last_processed_timestamp: mockDate,
      })

      const result = await db.getLastProcessedTimestamp()

      expect(result).toEqual(mockDate)
      expect(mockKysely.selectFrom).toHaveBeenCalledWith('processing_checkpoint')
      expect(mockKysely.orderBy).toHaveBeenCalledWith('id', 'desc')
      expect(mockKysely.limit).toHaveBeenCalledWith(1)
    })

    it('should return null when no checkpoint exists', async () => {
      mockKysely.executeTakeFirst.mockResolvedValue(null)

      const result = await db.getLastProcessedTimestamp()

      expect(result).toBeNull()
    })
  })

  describe('updateProcessingCheckpoint', () => {
    it('should insert new checkpoint', async () => {
      const timestamp = new Date('2024-01-01T12:00:00Z')

      await db.updateProcessingCheckpoint(timestamp)

      expect(mockKysely.insertInto).toHaveBeenCalledWith('processing_checkpoint')
      expect(mockKysely.values).toHaveBeenCalledWith({
        last_processed_timestamp: timestamp,
      })
    })
  })

  describe('getReferralCode', () => {
    it('should return referral code with converted numbers', async () => {
      mockKysely.executeTakeFirst.mockResolvedValue({
        id: 'ref123',
        custom_code: 'CUSTOM',
        total_points_earned: '1000.5',
        total_deposits_usd: '5000',
        active_users_count: 10,
        points_per_day: '100.25',
        fees_per_day: '500.75',
        last_calculated_at: new Date(),
        created_at: new Date(),
        updated_at: new Date(),
      })

      const result = await db.getReferralCode('ref123')

      expect(result).toEqual({
        id: 'ref123',
        custom_code: 'CUSTOM',
        total_points_earned: 1000.5,
        total_deposits_usd: 5000,
        active_users_count: 10,
        points_per_day: 100.25,
        fees_per_day: 500.75,
        last_calculated_at: expect.any(Date),
        created_at: expect.any(Date),
        updated_at: expect.any(Date),
      })
    })

    it('should return null when referral code not found', async () => {
      mockKysely.executeTakeFirst.mockResolvedValue(null)

      const result = await db.getReferralCode('nonexistent')

      expect(result).toBeNull()
    })

    it('should handle missing dates with defaults', async () => {
      mockKysely.executeTakeFirst.mockResolvedValue({
        id: 'ref123',
        custom_code: null,
        total_points_earned: '0',
        total_deposits_usd: '0',
        active_users_count: 0,
        points_per_day: '0',
        fees_per_day: '0',
        last_calculated_at: null,
        created_at: null,
        updated_at: null,
      })

      const result = await db.getReferralCode('ref123')

      expect(result!.created_at).toBeInstanceOf(Date)
      expect(result!.updated_at).toBeInstanceOf(Date)
    })
  })

  describe('getUsersReferredBy', () => {
    it('should return users with converted data', async () => {
      mockKysely.execute.mockResolvedValue([
        {
          id: 'user1',
          referrer_id: 'ref123',
          referral_chain: 'Base',
          referral_timestamp: new Date('2024-01-01'),
          total_deposits_usd: '1000',
          is_active: true,
          last_activity_at: new Date(),
          created_at: new Date(),
          updated_at: new Date(),
        },
      ])

      const result = await db.getUsersReferredBy('ref123')

      expect(result).toHaveLength(1)
      expect(result[0]).toEqual(
        expect.objectContaining({
          id: 'user1',
          total_deposits_usd: 1000,
          is_active: true,
        }),
      )
    })

    it('should handle missing dates with defaults', async () => {
      mockKysely.execute.mockResolvedValue([
        {
          id: 'user1',
          referrer_id: 'ref123',
          referral_chain: null,
          referral_timestamp: null,
          total_deposits_usd: '0',
          is_active: false,
          last_activity_at: null,
          created_at: null,
          updated_at: null,
        },
      ])

      const result = await db.getUsersReferredBy('ref123')

      expect(result[0].created_at).toBeInstanceOf(Date)
      expect(result[0].updated_at).toBeInstanceOf(Date)
    })
  })

  describe('getActiveUsersReferredBy', () => {
    it('should only return active users', async () => {
      mockKysely.execute.mockResolvedValue([
        {
          id: 'user1',
          referrer_id: 'ref123',
          total_deposits_usd: '1000',
          is_active: true,
          created_at: new Date(),
          updated_at: new Date(),
        },
      ])

      const result = await db.getActiveUsersReferredBy('ref123')

      expect(mockKysely.where).toHaveBeenCalledWith('referrer_id', '=', 'ref123')
      expect(mockKysely.where).toHaveBeenCalledWith('is_active', '=', true)
      expect(result).toHaveLength(1)
    })
  })

  describe('getTopReferralCodes', () => {
    it('should return top referral codes by points', async () => {
      mockKysely.execute.mockResolvedValue([
        {
          id: 'ref1',
          custom_code: 'TOP1',
          total_points_earned: '5000',
          total_deposits_usd: '10000',
          active_users_count: 50,
          points_per_day: '500',
          fees_per_day: '1000',
          created_at: new Date(),
          updated_at: new Date(),
        },
      ])

      const result = await db.getTopReferralCodes(10)

      expect(mockKysely.orderBy).toHaveBeenCalledWith('total_points_earned', 'desc')
      expect(mockKysely.limit).toHaveBeenCalledWith(10)
      expect(result).toHaveLength(1)
      expect(result[0].total_points_earned).toBe(5000)
    })

    it('should use default limit of 100', async () => {
      mockKysely.execute.mockResolvedValue([])

      await db.getTopReferralCodes()

      expect(mockKysely.limit).toHaveBeenCalledWith(100)
    })
  })

  describe('close', () => {
    it('should destroy database connection', async () => {
      await db.close()

      expect(mockKysely.destroy).toHaveBeenCalled()
    })
  })

  describe('getters', () => {
    it('should return raw database instance', () => {
      expect(db.rawDb).toBe(mockKysely)
    })

    it('should return raw pool instance', () => {
      expect(db.rawPool).toBe(mockPool)
    })
  })

  describe('migrate', () => {
    it('should run migrations', async () => {
      const mockMigrator = {
        runMigrations: jest.fn().mockResolvedValue(undefined),
      }

      // Mock the KyselyMigrator
      const { KyselyMigrator } = require('../migrations/kysely-migrator')
      KyselyMigrator.mockImplementation(() => mockMigrator)

      await db.migrate()

      expect(KyselyMigrator).toHaveBeenCalledWith(mockPool)
      expect(mockMigrator.runMigrations).toHaveBeenCalled()
    })
  })
})
