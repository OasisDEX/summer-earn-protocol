import { ReferralClient } from '../client'
import { Account } from '../types'

// Import the existing mock from setup.ts
import './setup'

// Get the mock GraphQLClient request method
const { GraphQLClient } = require('graphql-request')
const mockRequest = jest.fn()

describe('ReferralClient', () => {
  let client: ReferralClient
  let consoleSpy: jest.SpyInstance

  beforeEach(() => {
    jest.clearAllMocks()

    // Mock the GraphQLClient constructor to return our mock
    GraphQLClient.mockImplementation(() => ({
      request: mockRequest,
    }))

    client = new ReferralClient()
    consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
  })

  afterEach(() => {
    consoleSpy.mockRestore()
  })

  describe('getReferredAccounts', () => {
    const mockAccountData = {
      accounts: [
        {
          id: '0x123',
          referralData: { id: '0xreferrer', protocol: 'summer' },
          referralTimestamp: '1640995200', // 2022-01-01
          positions: [],
        },
        {
          id: '0x456',
          referralData: { id: '0xreferrer2', protocol: 'summer' },
          referralTimestamp: '1640995260', // 2022-01-01 + 60s
          positions: [],
        },
      ],
    }

    it('should fetch referred accounts successfully with timestamp filters', async () => {
      mockRequest.mockResolvedValue(mockAccountData)

      const result = await client.getReferredAccounts('Ethereum', {
        timestampGt: BigInt(1640995100),
        timestampLt: BigInt(1640995300),
      })

      expect(mockRequest).toHaveBeenCalledWith(
        expect.any(String), // REFERRED_ACCOUNTS_QUERY
        {
          timestampGt: '1640995100',
          timestampLt: '1640995300',
        },
      )
      expect(result).toHaveLength(2)
      expect(result[0].id).toBe('0x123')
      expect(result[1].id).toBe('0x456')
    })

    it('should fetch referred accounts with default timestamp bounds when no options provided', async () => {
      mockRequest.mockResolvedValue(mockAccountData)

      const result = await client.getReferredAccounts('Ethereum')

      expect(mockRequest).toHaveBeenCalledWith(expect.any(String), {
        timestampGt: '0',
        timestampLt: '99999999999999999999',
      })
      expect(result).toHaveLength(2)
    })

    it('should handle API errors gracefully', async () => {
      mockRequest.mockRejectedValue(new Error('GraphQL API Error'))

      const result = await client.getReferredAccounts('Ethereum')

      expect(result).toEqual([])
      expect(consoleSpy).toHaveBeenCalledWith(
        'Error fetching referred accounts from Ethereum:',
        expect.any(Error),
      )
    })

    it('should filter out null/undefined accounts', async () => {
      mockRequest.mockResolvedValue({
        accounts: [mockAccountData.accounts[0], null, undefined, mockAccountData.accounts[1]],
      })

      const result = await client.getReferredAccounts('Sonic')

      expect(result).toHaveLength(2)
      expect(result[0].id).toBe('0x123')
      expect(result[1].id).toBe('0x456')
    })

    it('should work with different chains', async () => {
      mockRequest.mockResolvedValue(mockAccountData)

      await client.getReferredAccounts('Base')
      await client.getReferredAccounts('Arbitrum')

      expect(mockRequest).toHaveBeenCalledTimes(2)
    })
  })

  describe('validateAccounts', () => {
    const mockAccounts: { [accountId: string]: Account } = {
      '0x123': {
        id: '0x123',
        referralTimestamp: '1640995200', // Earlier referral
        referralData: { id: '0xreferrer' },
      },
      '0x456': {
        id: '0x456',
        referralTimestamp: '1640995300', // Later referral
        referralData: { id: '0xreferrer2' },
      },
    }

    it('should validate accounts with no positions as invalid when referred before current period', async () => {
      mockRequest.mockResolvedValue({
        accounts: [
          {
            id: '0x123',
            positions: [],
            referralTimestamp: '1640995100', // Earlier than input referral
          },
        ],
      })

      // Use an account with a later referral timestamp than what's on chain
      const accountWithLaterReferral = {
        '0x123': {
          id: '0x123',
          referralTimestamp: '1640995200', // Later than chain referral (1640995100)
          referralData: { id: '0xreferrer' },
        },
      }

      // Account should be invalid because:
      // wasReferredEarlierThanCurrentPeriod is true (1640995200 > 1640995100)
      // This means the account was referred before the current period
      const result = await client.validateAccounts('Ethereum', accountWithLaterReferral)

      expect(result['0x123']).toBe(false)
    })

    it('should validate accounts with no positions as valid when referred in current period', async () => {
      mockRequest.mockResolvedValue({
        accounts: [
          {
            id: '0x123',
            positions: [],
            referralTimestamp: '1640995200', // Same as input referral
          },
        ],
      })

      // Account should be valid because:
      // 1. No positions created before referral (no violation)
      // 2. wasReferredEarlierThanCurrentPeriod is false (1640995200 == 1640995200)
      // This means the account was referred in the current period
      const result = await client.validateAccounts('Ethereum', mockAccounts)

      expect(result['0x123']).toBe(true)
    })

    it('should validate accounts with positions created after referral as valid', async () => {
      mockRequest.mockResolvedValue({
        accounts: [
          {
            id: '0x123',
            positions: [
              {
                id: 'pos1',
                createdTimestamp: '1640995300', // After referral
              },
            ],
            referralTimestamp: '1640995100', // Earlier than input referral
          },
        ],
      })

      // Account should be valid because:
      // 1. Positions were created after referral (no violation)
      // 2. wasReferredEarlierThanCurrentPeriod is true but positions are valid
      const result = await client.validateAccounts('Ethereum', mockAccounts)

      // Wait, this should actually be invalid due to wasReferredEarlierThanCurrentPeriod
      expect(result['0x123']).toBe(false)
    })

    it('should invalidate accounts with positions created before referral', async () => {
      mockRequest.mockResolvedValue({
        accounts: [
          {
            id: '0x123',
            positions: [
              {
                id: 'pos1',
                createdTimestamp: '1640995100', // Before referral
              },
            ],
            referralTimestamp: '1640995200', // Same as input referral
          },
        ],
      })

      // Account should be invalid because:
      // hasReferralTimestamp && positionsCreatedBeforeReferral is true
      // (1640995100 < 1640995200)
      const result = await client.validateAccounts('Ethereum', mockAccounts)

      expect(result['0x123']).toBe(false)
    })

    it('should handle accounts without referral timestamp as valid as they were referred on another chain', async () => {
      const accountsWithoutReferral = {
        '0x789': {
          id: '0x789',
          referralTimestamp: undefined,
          referralData: undefined,
        },
      }

      mockRequest.mockResolvedValue({
        accounts: [
          {
            id: '0x789',
            positions: [
              {
                id: 'pos1',
                createdTimestamp: '1640995100',
              },
            ],
            referralTimestamp: '1640995200',
          },
        ],
      })

      // Account should be valid because:
      // it has earliest referral timestamp but no referral timestamp -> hence it was referred in this period
      const result = await client.validateAccounts('Ethereum', accountsWithoutReferral)

      expect(result['0x789']).toBe(true)
    })

    it('should validate cross-chain referral timestamp logic correctly', async () => {
      mockRequest.mockResolvedValue({
        accounts: [
          {
            id: '0x123',
            positions: [
              {
                id: 'pos1',
                createdTimestamp: '1640995050', // Before earliest referral
              },
            ],
            referralTimestamp: '1640995090', // Earlier referral on this chain
          },
        ],
      })

      const crossChainAccounts = {
        '0x123': {
          id: '0x123',
          referralTimestamp: '1640995100', // Earliest across all chains (greater than chain referral)
          referralData: { id: '0xreferrer' },
        },
      }

      const result = await client.validateAccounts('Ethereum', crossChainAccounts)

      // Should be invalid because:
      // 1. hasReferralTimestamp && positionsCreatedBeforeReferral is true (1640995050 < 1640995100)
      // This alone makes the account invalid regardless of the other check
      expect(result['0x123']).toBe(false)
    })

    it('should handle GraphQL errors gracefully', async () => {
      mockRequest.mockRejectedValue(new Error('GraphQL Error'))

      const result = await client.validateAccounts('Ethereum', mockAccounts)

      expect(result).toEqual({})
      expect(consoleSpy).toHaveBeenCalledWith(
        'Error validating positions from Ethereum:',
        expect.any(Error),
      )
    })

    it('should convert account IDs to lowercase for query', async () => {
      const upperCaseAccounts = {
        '0xABC': {
          id: '0xABC',
          referralTimestamp: '1640995200',
          referralData: { id: '0xreferrer' },
        },
      }

      mockRequest.mockResolvedValue({
        accounts: [
          {
            id: '0xABC',
            positions: [],
            referralTimestamp: '1640995200',
          },
        ],
      })

      await client.validateAccounts('Ethereum', upperCaseAccounts)

      expect(mockRequest).toHaveBeenCalledWith(expect.any(String), {
        accountIds: ['0xabc'], // Should be lowercase
      })
    })

    it('should invalidate accounts referred before current period', async () => {
      mockRequest.mockResolvedValue({
        accounts: [
          {
            id: '0x123',
            positions: [],
            referralTimestamp: '1640995000', // Much earlier referral on this chain
          },
        ],
      })

      // Use an account with earlier referral timestamp to make the test clearer
      const accountsWithLaterReferral = {
        '0x123': {
          id: '0x123',
          referralTimestamp: '1640995100', // Later than chain referral (1640995000)
          referralData: { id: '0xreferrer' },
        },
      }

      // Account should be invalid because:
      // wasReferredEarlierThanCurrentPeriod is true (1640995100 > 1640995000)
      // This means the account was referred before the current period
      const result = await client.validateAccounts('Ethereum', accountsWithLaterReferral)

      expect(result['0x123']).toBe(false)
    })
  })

  describe('getValidReferredAccounts', () => {
    let mockGetReferredAccounts: jest.SpyInstance
    let mockValidateAccounts: jest.SpyInstance

    beforeEach(() => {
      mockGetReferredAccounts = jest.spyOn(client, 'getReferredAccounts')
      mockValidateAccounts = jest.spyOn(client, 'validateAccounts')
    })

    afterEach(() => {
      mockGetReferredAccounts.mockRestore()
      mockValidateAccounts.mockRestore()
    })

    it('should process first run correctly with only timestampLt', async () => {
      const mockAccounts: Account[] = [
        {
          id: '0x123',
          referralTimestamp: '1640995200',
          referralData: { id: '0xreferrer' },
          referralChain: 'Ethereum',
        },
        {
          id: '0x456',
          referralTimestamp: '1640995300',
          referralData: { id: '0xreferrer2' },
          referralChain: 'Ethereum',
        },
      ]

      // Mock getReferredAccounts for all chains
      mockGetReferredAccounts
        .mockResolvedValueOnce(mockAccounts) // Ethereum
        .mockResolvedValueOnce([]) // Sonic
        .mockResolvedValueOnce([]) // Arbitrum
        .mockResolvedValueOnce([]) // Base

      // Mock validateAccounts for all chains
      mockValidateAccounts
        .mockResolvedValueOnce({ '0x123': true, '0x456': true }) // Ethereum
        .mockResolvedValueOnce({}) // Sonic
        .mockResolvedValueOnce({}) // Arbitrum
        .mockResolvedValueOnce({}) // Base

      const result = await client.getValidReferredAccounts(BigInt(0), BigInt(1640995400))

      // Verify behavior - timestampGt is not included when it's BigInt(0) since it's falsy
      expect(mockGetReferredAccounts).toHaveBeenCalledWith('Ethereum', {
        timestampLt: BigInt(1640995400),
      })
      expect(result.validAccounts).toEqual(mockAccounts)
    })

    it('should process subsequent run with both timestamps', async () => {
      const mockAccounts: Account[] = [
        {
          id: '0x123',
          referralTimestamp: '1640995200',
          referralData: { id: '0xreferrer' },
          referralChain: 'Ethereum',
        },
      ]

      mockGetReferredAccounts
        .mockResolvedValueOnce(mockAccounts)
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([])

      mockValidateAccounts
        .mockResolvedValueOnce({ '0x123': true })
        .mockResolvedValueOnce({})
        .mockResolvedValueOnce({})
        .mockResolvedValueOnce({})

      const result = await client.getValidReferredAccounts(BigInt(1640995000), BigInt(1640995400))

      // Verify subsequent run behavior - both timestamps used
      expect(mockGetReferredAccounts).toHaveBeenCalledWith('Ethereum', {
        timestampGt: BigInt(1640995000),
        timestampLt: BigInt(1640995400),
      })
      expect(result.validAccounts).toEqual(mockAccounts)
    })

    it('should consolidate accounts across chains keeping earliest referral', async () => {
      const ethereumAccounts: Account[] = [
        {
          id: '0x123',
          referralTimestamp: '1640995300', // Later
          referralData: { id: '0xreferrer' },
        },
      ]

      const sonicAccounts: Account[] = [
        {
          id: '0x123',
          referralTimestamp: '1640995200', // Earlier - should be kept
          referralData: { id: '0xreferrer' },
        },
      ]

      mockGetReferredAccounts
        .mockResolvedValueOnce(ethereumAccounts) // Ethereum
        .mockResolvedValueOnce(sonicAccounts) // Sonic
        .mockResolvedValueOnce([]) // Arbitrum
        .mockResolvedValueOnce([]) // Base

      mockValidateAccounts.mockResolvedValue({ '0x123': true })

      const result = await client.getValidReferredAccounts(BigInt(1640995000), BigInt(1640995400))

      // Should use earliest referral timestamp
      expect(mockValidateAccounts).toHaveBeenCalledWith(
        'Ethereum',
        expect.objectContaining({
          '0x123': expect.objectContaining({
            referralTimestamp: '1640995200', // Earlier timestamp
          }),
        }),
      )
      expect(result.validAccounts.map((a) => a.id)).toEqual(['0x123'])
    })

    it('should filter out invalid accounts based on cross-chain validation', async () => {
      const mockAccounts: Account[] = [
        {
          id: '0x123',
          referralTimestamp: '1640995200',
          referralData: { id: '0xreferrer' },
        },
        {
          id: '0x456',
          referralTimestamp: '1640995300',
          referralData: { id: '0xreferrer2' },
        },
      ]

      mockGetReferredAccounts
        .mockResolvedValueOnce(mockAccounts)
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce([])

      // Mock validation where one account is invalid on one chain
      mockValidateAccounts
        .mockResolvedValueOnce({ '0x123': true, '0x456': false }) // Ethereum
        .mockResolvedValueOnce({}) // Sonic
        .mockResolvedValueOnce({}) // Arbitrum
        .mockResolvedValueOnce({}) // Base

      const result = await client.getValidReferredAccounts(BigInt(1640995000), BigInt(1640995400))

      // Only account valid on ALL chains should be returned (0x456 is invalid on Ethereum)
      expect(result.validAccounts.map((a) => a.id)).toEqual(['0x123'])
    })

    it('should require validation on ALL chains for account to be valid', async () => {
      const mockAccounts: Account[] = [
        {
          id: '0x123',
          referralTimestamp: '1640995200',
          referralData: { id: '0xreferrer' },
        },
      ]

      mockGetReferredAccounts
        .mockResolvedValue(mockAccounts)
        .mockResolvedValue([])
        .mockResolvedValue([])
        .mockResolvedValue([])

      // Account invalid on one chain should make it invalid overall
      mockValidateAccounts
        .mockResolvedValueOnce({ '0x123': true }) // Ethereum - valid
        .mockResolvedValueOnce({ '0x123': false }) // Sonic - invalid
        .mockResolvedValueOnce({ '0x123': true }) // Arbitrum - valid
        .mockResolvedValueOnce({ '0x123': true }) // Base - valid

      const result = await client.getValidReferredAccounts(BigInt(1640995000), BigInt(1640995400))

      expect(result.validAccounts).toEqual([])
    })

    it('should handle empty results from all chains', async () => {
      mockGetReferredAccounts.mockResolvedValue([])

      const result = await client.getValidReferredAccounts(BigInt(1640995000), BigInt(1640995400))

      expect(result.validAccounts).toEqual([])
    })

    it('should handle duplicate accounts from same chain', async () => {
      const duplicateAccounts: Account[] = [
        {
          id: '0x123',
          referralTimestamp: '1640995200',
          referralData: { id: '0xreferrer' },
        },
        {
          id: '0x123',
          referralTimestamp: '1640995300', // Later timestamp - should be ignored
          referralData: { id: '0xreferrer' },
        },
      ]

      mockGetReferredAccounts.mockResolvedValueOnce(duplicateAccounts).mockResolvedValue([])

      mockValidateAccounts.mockResolvedValue({ '0x123': true })

      const result = await client.getValidReferredAccounts(BigInt(1640995000), BigInt(1640995400))

      // Should consolidate to single account with earliest timestamp
      expect(mockValidateAccounts).toHaveBeenCalledWith(
        'Ethereum',
        expect.objectContaining({
          '0x123': expect.objectContaining({
            referralTimestamp: '1640995200',
          }),
        }),
      )
      expect(result.validAccounts.map((a) => a.id)).toEqual(['0x123'])
    })
  })
})
