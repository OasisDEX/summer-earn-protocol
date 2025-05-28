import { Pool } from 'pg'
import { DatabaseService } from '../db'
import { Chain } from '../types'

// Mock the pg Pool
jest.mock('pg', () => ({
  Pool: jest.fn().mockImplementation(() => ({
    query: jest.fn(),
    end: jest.fn()
  }))
}))

describe('DatabaseService', () => {
  let db: DatabaseService
  let mockPool: jest.Mocked<Pool>

  beforeEach(() => {
    jest.clearAllMocks()
    db = new DatabaseService()
    mockPool = (db as any).pool
  })

  describe('upsertReferralPoints', () => {
    it('should insert new referral points', async () => {
      const accountId = '0x123'
      const points = 1.5
      const totalDepositsUsd = 3000
      const activeReferredUsers = 2

      await db.upsertReferralPoints(accountId, points, totalDepositsUsd, activeReferredUsers)

      expect(mockPool.query).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO referral_points'),
        [accountId, points, totalDepositsUsd, activeReferredUsers]
      )
    })
  })

  describe('upsertReferralRelationship', () => {
    it('should insert new referral relationship', async () => {
      const referrerId = '0x123'
      const referredId = '0x456'
      const chain: Chain = 'Ethereum'
      const referralTimestamp = new Date('2024-01-01T00:00:00Z')

      await db.upsertReferralRelationship(referrerId, referredId, chain, referralTimestamp)

      expect(mockPool.query).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO referral_relationships'),
        [referrerId, referredId, chain, referralTimestamp]
      )
    })
  })

  describe('savePositionSnapshot', () => {
    it('should save position snapshot', async () => {
      const accountId = '0x123'
      const chain: Chain = 'Ethereum'
      const positionId = '0x789'
      const depositAmountUsd = 1000
      const createdTimestamp = new Date('2024-01-01T00:00:00Z')
      const referralTimestamp = new Date('2024-01-01T00:00:00Z')

      await db.savePositionSnapshot(
        accountId,
        chain,
        positionId,
        depositAmountUsd,
        createdTimestamp,
        referralTimestamp
      )

      expect(mockPool.query).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO position_snapshots'),
        [accountId, chain, positionId, depositAmountUsd, createdTimestamp, referralTimestamp]
      )
    })

    it('should save position snapshot without referral timestamp', async () => {
      const accountId = '0x123'
      const chain: Chain = 'Ethereum'
      const positionId = '0x789'
      const depositAmountUsd = 1000
      const createdTimestamp = new Date('2024-01-01T00:00:00Z')

      await db.savePositionSnapshot(
        accountId,
        chain,
        positionId,
        depositAmountUsd,
        createdTimestamp
      )

      expect(mockPool.query).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO position_snapshots'),
        [accountId, chain, positionId, depositAmountUsd, createdTimestamp, undefined]
      )
    })
  })

  describe('getReferralPoints', () => {
    it('should return referral points for account', async () => {
      const accountId = '0x123'
      const mockPoints = {
        points: 1.5,
        totalDepositsUsd: 3000,
        activeReferredUsers: 2,
        lastUpdated: new Date('2024-01-01T00:00:00Z')
      }

      mockPool.query.mockResolvedValueOnce({ rows: [mockPoints] })

      const result = await db.getReferralPoints(accountId)

      expect(mockPool.query).toHaveBeenCalledWith(
        expect.stringContaining('SELECT points, total_deposits_usd'),
        [accountId]
      )
      expect(result).toEqual(mockPoints)
    })

    it('should return null if no points found', async () => {
      const accountId = '0x123'
      mockPool.query.mockResolvedValueOnce({ rows: [] })

      const result = await db.getReferralPoints(accountId)

      expect(result).toBeNull()
    })
  })

  describe('getReferredUsers', () => {
    it('should return referred users for account', async () => {
      const accountId = '0x123'
      const mockReferredUsers = [
        {
          referredId: '0x456',
          chain: 'Ethereum' as Chain,
          referralTimestamp: new Date('2024-01-01T00:00:00Z')
        }
      ]

      mockPool.query.mockResolvedValueOnce({ rows: mockReferredUsers })

      const result = await db.getReferredUsers(accountId)

      expect(mockPool.query).toHaveBeenCalledWith(
        expect.stringContaining('SELECT referred_id, chain, referral_timestamp'),
        [accountId]
      )
      expect(result).toEqual(mockReferredUsers)
    })
  })

  describe('getPositionSnapshots', () => {
    it('should return position snapshots for account', async () => {
      const accountId = '0x123'
      const fromTimestamp = new Date('2024-01-01T00:00:00Z')
      const mockSnapshots = [
        {
          chain: 'Ethereum' as Chain,
          positionId: '0x789',
          depositAmountUsd: 1000,
          createdTimestamp: new Date('2024-01-01T00:00:00Z'),
          referralTimestamp: new Date('2024-01-01T00:00:00Z'),
          snapshotTimestamp: new Date('2024-01-01T00:00:00Z')
        }
      ]

      mockPool.query.mockResolvedValueOnce({ rows: mockSnapshots })

      const result = await db.getPositionSnapshots(accountId, fromTimestamp)

      expect(mockPool.query).toHaveBeenCalledWith(
        expect.stringContaining('SELECT chain, position_id, deposit_amount_usd'),
        [accountId, fromTimestamp]
      )
      expect(result).toEqual(mockSnapshots)
    })
  })

  describe('close', () => {
    it('should close the database connection', async () => {
      await db.close()
      expect(mockPool.end).toHaveBeenCalled()
    })
  })
}) 