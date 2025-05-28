import { Account, Position, ReferralData } from '../types'

describe('Type Definitions', () => {
  describe('ReferralData', () => {
    it('should have the correct shape', () => {
      const referralData: ReferralData = {
        id: '0x123',
        amountOfReferred: BigInt(5)
      }

      expect(referralData).toHaveProperty('id')
      expect(referralData).toHaveProperty('amountOfReferred')
      expect(referralData).toHaveProperty('protocol')
      expect(typeof referralData.id).toBe('string')
      expect(typeof referralData.amountOfReferred).toBe('bigint')

    })
  })

  describe('Position', () => {
    it('should have the correct shape', () => {
      const position: Position = {
        id: '0x456',
        account:{id: '0x789'},
        vault: {id: '0xabc'},
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
        referralData: null,
        depositAmountUsd: BigInt(1),
        createdAt: BigInt(1234567880)
      }

      // Check required string properties
      expect(typeof position.id).toBe('string')
      expect(typeof position.account).toBe('string')
      expect(typeof position.vault).toBe('string')

      // Check BigInt properties
      expect(typeof position.inputTokenDeposits).toBe('bigint')
      expect(typeof position.inputTokenWithdrawals).toBe('bigint')
      expect(typeof position.inputTokenBalance).toBe('bigint')
      expect(typeof position.outputTokenBalance).toBe('bigint')
      expect(typeof position.stakedInputTokenBalance).toBe('bigint')
      expect(typeof position.stakedOutputTokenBalance).toBe('bigint')
      expect(typeof position.unstakedInputTokenBalance).toBe('bigint')
      expect(typeof position.unstakedOutputTokenBalance).toBe('bigint')
      expect(typeof position.createdTimestamp).toBe('bigint')
      expect(typeof position.createdBlockNumber).toBe('bigint')
      expect(typeof position.claimedSummerToken).toBe('bigint')
      expect(typeof position.claimableSummerToken).toBe('bigint')

      // Check number properties
      expect(typeof position.inputTokenDepositsNormalized).toBe('number')
      expect(typeof position.inputTokenWithdrawalsNormalized).toBe('number')
      expect(typeof position.inputTokenDepositsNormalizedInUSD).toBe('number')
      expect(typeof position.inputTokenWithdrawalsNormalizedInUSD).toBe('number')
      expect(typeof position.inputTokenBalanceNormalized).toBe('number')
      expect(typeof position.stakedInputTokenBalanceNormalized).toBe('number')
      expect(typeof position.unstakedInputTokenBalanceNormalized).toBe('number')
      expect(typeof position.inputTokenBalanceNormalizedInUSD).toBe('number')
      expect(typeof position.stakedInputTokenBalanceNormalizedInUSD).toBe('number')
      expect(typeof position.unstakedInputTokenBalanceNormalizedInUSD).toBe('number')
      expect(typeof position.claimedSummerTokenNormalized).toBe('number')
      expect(typeof position.claimableSummerTokenNormalized).toBe('number')

      // Check optional properties
      expect(position.referralData).toBeNull()
    })
  })

  describe('Account', () => {
    it('should have the correct shape', () => {
      const account: Account = {
        id: '0x789',
        positions: [],
        stakedSummerToken: BigInt(1000),
        stakedSummerTokenNormalized: 1000,
        lastUpdateBlock: BigInt(12345678),
        claimedSummerToken: BigInt(100),
        claimedSummerTokenNormalized: 100,
        referralData: null,
        referralTimestamp: null
      }

      // Check required string properties
      expect(typeof account.id).toBe('string')

      // Check array properties
      expect(Array.isArray(account.positions)).toBe(true)

      // Check BigInt properties
      expect(typeof account.stakedSummerToken).toBe('bigint')
      expect(typeof account.lastUpdateBlock).toBe('bigint')
      expect(typeof account.claimedSummerToken).toBe('bigint')

      // Check number properties
      expect(typeof account.stakedSummerTokenNormalized).toBe('number')
      expect(typeof account.claimedSummerTokenNormalized).toBe('number')

      // Check optional properties
      expect(account.referralData).toBeNull()
      expect(account.referralTimestamp).toBeNull()
    })

    it('should allow optional properties to be set', () => {
      const referralData: ReferralData = {
        id: '0x123',
        amountOfReferred: BigInt(5)
      }

      const account: Account = {
        id: '0x789',
        positions: [],
        stakedSummerToken: BigInt(1000),
        stakedSummerTokenNormalized: 1000,
        lastUpdateBlock: BigInt(12345678),
        claimedSummerToken: BigInt(100),
        claimedSummerTokenNormalized: 100,
        referralData,
        referralTimestamp: BigInt(1234567890)
      }

      expect(account.referralData).toEqual(referralData)
      expect(typeof account.referralTimestamp).toBe('bigint')
    })
  })
}) 