import { DatabaseService } from '../db'
import { Kysely, sql } from 'kysely'
import { Pool } from 'pg'

// Mock dependencies
jest.mock('pg')
jest.mock('../config-updated')

// Mock kysely sql template
jest.mock('kysely', () => ({
  ...jest.requireActual('kysely'),
  sql: {
    raw: jest.fn((value) => ({ compile: jest.fn(() => ({ sql: value, parameters: [] })) })),
    __proto__: {
      compile: jest.fn(() => ({ sql: 'mock sql', parameters: [] }))
    }
  }
}))

describe('DatabaseService', () => {
  let db: DatabaseService
  let mockPool: jest.Mocked<Pool>
  let mockKysely: any

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks()

    // Mock Pool
    mockPool = {
      connect: jest.fn(),
      query: jest.fn(),
      end: jest.fn(),
    } as any

    // Mock Kysely methods
    mockKysely = {
      insertInto: jest.fn().mockReturnThis(),
      values: jest.fn().mockReturnThis(),
      onConflict: jest.fn().mockReturnThis(),
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
    }

    // Mock Pool constructor
    ;(Pool as jest.MockedClass<typeof Pool>).mockImplementation(() => mockPool)

    // Create service instance
    db = new DatabaseService()
    
    // Replace the Kysely instance with our mock
    ;(db as any).db = mockKysely
  })

  describe('ensureReferralCode', () => {
    it('should create referral code with defaults', async () => {
      await db.ensureReferralCode('ref123')

      expect(mockKysely.insertInto).toHaveBeenCalledWith('referral_codes')
      expect(mockKysely.values).toHaveBeenCalledWith({
        id: 'ref123',
        custom_code: null,
        total_points: '0',
        total_deposits_usd: '0',
        active_users_count: 0,
        points_per_day: '0',
        deposits_per_day: '0',
      })
      expect(mockKysely.execute).toHaveBeenCalled()
    })

    it('should create referral code with custom code', async () => {
      await db.ensureReferralCode('ref123', 'CUSTOM123')

      expect(mockKysely.values).toHaveBeenCalledWith(
        expect.objectContaining({
          id: 'ref123',
          custom_code: 'CUSTOM123',
        })
      )
    })
  })

  describe('upsertUser', () => {
    it('should insert new user with referral info', async () => {
      await db.upsertUser('user123', {
        referrerId: 'ref123',
        referralChain: 'Base',
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
  })

  describe('updatePosition', () => {
    it('should update position with current deposit', async () => {
      await db.updatePosition('pos123', 'Base', 'user123', 1000.5)

      expect(mockKysely.insertInto).toHaveBeenCalledWith('positions')
      expect(mockKysely.values).toHaveBeenCalledWith({
        id: 'pos123',
        chain: 'Base',
        user_id: 'user123',
        current_deposit_usd: '1000.5',
        last_synced_at: expect.any(Date),
      })
    })
  })

  describe('updateUserTotals', () => {
    it('should update user totals based on positions', async () => {
      // Mock config
      const mockConfig = { activeUserThresholdUsd: '100' }
      ;(db.config.getConfig as jest.Mock).mockResolvedValue(mockConfig)

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
      const mockConfig = { activeUserThresholdUsd: '100' }
      ;(db.config.getConfig as jest.Mock).mockResolvedValue(mockConfig)

      mockKysely.executeTakeFirst.mockResolvedValue({ total_deposits: '50' })

      await db.updateUserTotals('user123')

      expect(mockKysely.set).toHaveBeenCalledWith(
        expect.objectContaining({
          is_active: false,
        })
      )
    })
  })

  describe('recalculateReferralStats', () => {
    it('should execute stats update query', async () => {
      await db.recalculateReferralStats()

      expect(mockKysely.executeQuery).toHaveBeenCalled()
      const query = mockKysely.executeQuery.mock.calls[0][0]
      expect(query).toBeDefined()
    })
  })

  describe('updateDailyRatesAndPoints', () => {
    it('should update daily rates and accumulate points', async () => {
      const mockConfig = {
        pointsFormulaBase: 0.00005,
        pointsFormulaLogMultiplier: 0.0005,
      }
      ;(db.config.getConfig as jest.Mock).mockResolvedValue(mockConfig)

      // Mock active users count
      mockKysely.executeTakeFirst.mockResolvedValue({ count: '100' })

      await db.updateDailyRatesAndPoints()

      expect(mockKysely.selectFrom).toHaveBeenCalledWith('users')
      expect(mockKysely.where).toHaveBeenCalledWith('is_active', '=', true)
      expect(mockKysely.executeQuery).toHaveBeenCalled()
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
        total_points: '1000.5',
        total_deposits_usd: '5000',
        active_users_count: 10,
        points_per_day: '100.25',
        deposits_per_day: '500.75',
        last_calculated_at: new Date(),
        created_at: new Date(),
        updated_at: new Date(),
      })

      const result = await db.getReferralCode('ref123')

      expect(result).toEqual({
        id: 'ref123',
        custom_code: 'CUSTOM',
        total_points: 1000.5,
        total_deposits_usd: 5000,
        active_users_count: 10,
        points_per_day: 100.25,
        deposits_per_day: 500.75,
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
        })
      )
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
          total_points: '5000',
          total_deposits_usd: '10000',
          active_users_count: 50,
          points_per_day: '500',
          deposits_per_day: '1000',
          created_at: new Date(),
          updated_at: new Date(),
        },
      ])

      const result = await db.getTopReferralCodes(10)

      expect(mockKysely.orderBy).toHaveBeenCalledWith('total_points', 'desc')
      expect(mockKysely.limit).toHaveBeenCalledWith(10)
      expect(result).toHaveLength(1)
      expect(result[0].total_points).toBe(5000)
    })
  })

  describe('updateDailyStats', () => {
    it('should insert or update daily stats', async () => {
      await db.updateDailyStats()

      expect(mockKysely.executeQuery).toHaveBeenCalled()
      const query = mockKysely.executeQuery.mock.calls[0][0]
      expect(query).toBeDefined()
    })
  })

  describe('close', () => {
    it('should destroy database connection', async () => {
      await db.close()

      expect(mockKysely.destroy).toHaveBeenCalled()
    })
  })

  describe('rawDb and rawPool getters', () => {
    it('should return raw database instance', () => {
      expect(db.rawDb).toBe(mockKysely)
    })

    it('should return raw pool instance', () => {
      expect(db.rawPool).toBe(mockPool)
    })
  })
}) 