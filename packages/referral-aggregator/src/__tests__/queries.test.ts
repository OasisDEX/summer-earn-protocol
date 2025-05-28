import { ACCOUNT_QUERY, POSITIONS_QUERY } from '../queries'

describe('GraphQL Queries', () => {
  describe('ACCOUNT_QUERY', () => {
    it('should be a valid GraphQL query string', () => {
      expect(typeof ACCOUNT_QUERY).toBe('string')
      expect(ACCOUNT_QUERY).toContain('query')
      expect(ACCOUNT_QUERY).toContain('account')
      expect(ACCOUNT_QUERY).toContain('id')
    })

    it('should include all required fields', () => {
      const requiredFields = [
        'id',
        'stakedSummerToken',
        'stakedSummerTokenNormalized',
        'lastUpdateBlock',
        'claimedSummerToken',
        'claimedSummerTokenNormalized',
        'referralData',
        'referralTimestamp'
      ]

      requiredFields.forEach(field => {
        expect(ACCOUNT_QUERY).toContain(field)
      })
    })

    it('should include nested referral data fields', () => {
      const referralFields = [
        'id',
        'amountOfReferred',
        'protocol'
      ]

      referralFields.forEach(field => {
        expect(ACCOUNT_QUERY).toContain(field)
      })
    })
  })

  describe('POSITIONS_QUERY', () => {
    it('should be a valid GraphQL query string', () => {
      expect(typeof POSITIONS_QUERY).toBe('string')
      expect(POSITIONS_QUERY).toContain('query')
      expect(POSITIONS_QUERY).toContain('positions')
      expect(POSITIONS_QUERY).toContain('account')
    })

    it('should include all required fields', () => {
      const requiredFields = [
        'id',
        'account',
        'vault',
        'inputTokenDeposits',
        'inputTokenDepositsNormalized',
        'inputTokenWithdrawalsNormalized',
        'inputTokenDepositsNormalizedInUSD',
        'inputTokenWithdrawals',
        'inputTokenWithdrawalsNormalizedInUSD',
        'inputTokenBalance',
        'outputTokenBalance',
        'stakedInputTokenBalance',
        'stakedOutputTokenBalance',
        'unstakedInputTokenBalance',
        'unstakedOutputTokenBalance',
        'inputTokenBalanceNormalized',
        'stakedInputTokenBalanceNormalized',
        'unstakedInputTokenBalanceNormalized',
        'inputTokenBalanceNormalizedInUSD',
        'stakedInputTokenBalanceNormalizedInUSD',
        'unstakedInputTokenBalanceNormalizedInUSD',
        'createdTimestamp',
        'createdBlockNumber',
        'claimedSummerToken',
        'claimedSummerTokenNormalized',
        'claimableSummerToken',
        'claimableSummerTokenNormalized',
        'referralData'
      ]

      requiredFields.forEach(field => {
        expect(POSITIONS_QUERY).toContain(field)
      })
    })

    it('should include nested referral data fields', () => {
      const referralFields = [
        'id',
        'amountOfReferred',
        'protocol'
      ]

      referralFields.forEach(field => {
        expect(POSITIONS_QUERY).toContain(field)
      })
    })
  })
}) 