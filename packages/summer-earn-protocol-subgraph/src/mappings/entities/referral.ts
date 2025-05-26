import { BigDecimal, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { Account, ReferralData } from '../../../generated/schema'
import { BigDecimalConstants, EventSignature } from '../../common/constants'
import { getOrCreatePosition } from '../../common/initializers'
import { PositionDetails } from '../../types'
import { dataToTuple, getEventLogs, logTopicToAddress } from '../../utils/events'

/**
 * Handles referral tracking for deposits and stakes.
 *
 * REFERRAL TRACKING LOGIC:
 * 1. Only processes deposits/stakes (positive inputTokenDeltaNormalizedUSD)
 * 2. Tracks maxEverDepositedUSD per position AND per account to prevent gaming
 * 3. Only credits referral totals for incremental increases in BOTH position and account max
 * 4. Links accounts to referral codes on first deposit with referral
 *
 * ANTI-GAMING PROTECTION:
 * - Per-position tracking: Allows legitimate multi-vault usage
 * - Per-account tracking: Prevents cross-vault capital recycling
 * - Credits minimum of (position increase, account increase)
 *
 * WITHDRAWAL/UNSTAKE TRACKING:
 * - Withdrawals/unstakes are tracked separately in fleetCommander.ts
 * - They use account.referralData directly for analytics (no new referral processing)
 *
 * EXAMPLES:
 * - User deposits $100 USDC → $100 credited to referral
 * - User deposits $100 USDT → $100 credited (different position, account total now $200)
 * - User increases USDC to $200 → $100 credited (position increase, account total now $300)
 * - User withdraws $100 USDC, swaps to ETH, deposits $100 ETH → $0 credited (account max already $300)
 *
 * @param event - The blockchain event (deposit/stake)
 * @param maybeReferredAccount - Account that might have been referred
 * @param positionDetails - Position details with current and delta amounts
 * @returns Referral data ID if referral exists, null otherwise
 */
export function handleReferrals(
  event: ethereum.Event,
  maybeReferredAccount: Account,
  positionDetails: PositionDetails,
): string | null {
  // Early exit for withdrawals, unstakes, and zero amounts
  // These are tracked separately in fleetCommander.ts using account.referralData
  if (positionDetails.inputTokenDeltaNormalizedUSD.le(BigDecimalConstants.ZERO)) {
    return null
  }

  // Load the position to get per-position max deposited tracking
  // We track per position (not per account) because users can have multiple positions
  // across different vaults, and each should be tracked independently
  const position = getOrCreatePosition(positionDetails.positionId, event.block)

  // Calculate total account balance across all positions
  const accountTotalBalance = calculateAccountTotalBalance(maybeReferredAccount)

  // Get current values for comparison
  const currentDepositUSD = positionDetails.inputTokenDeltaNormalizedUSD
  const currentPositionBalanceUSD = positionDetails.inputTokenBalanceNormalizedUSD

  const previousPositionBalanceUSD = currentPositionBalanceUSD
    .minus(currentDepositUSD)
    .gt(BigDecimalConstants.ZERO)
    ? currentPositionBalanceUSD.minus(currentDepositUSD)
    : BigDecimalConstants.ZERO
  const previousAccountBalanceUSD = accountTotalBalance
    .minus(currentDepositUSD)
    .gt(BigDecimalConstants.ZERO)
    ? accountTotalBalance.minus(currentDepositUSD)
    : BigDecimalConstants.ZERO

  const maxEverDepositedPerPosition = position.maxEverDepositedUSD
    ? position.maxEverDepositedUSD
    : previousPositionBalanceUSD
  const maxEverDepositedPerAccount = maybeReferredAccount.maxEverDepositedUSD
    ? maybeReferredAccount.maxEverDepositedUSD
    : previousAccountBalanceUSD

  // Calculate potential increases for both position and account
  const positionIncrease = currentPositionBalanceUSD.gt(maxEverDepositedPerPosition!)
    ? currentPositionBalanceUSD.minus(maxEverDepositedPerPosition!)
    : BigDecimalConstants.ZERO

  const accountIncrease = accountTotalBalance.gt(maxEverDepositedPerAccount!)
    ? accountTotalBalance.minus(maxEverDepositedPerAccount!)
    : BigDecimalConstants.ZERO

  // Credit the minimum of position increase and account increase
  // This prevents gaming while allowing legitimate multi-vault usage
  const amountToAddToReferral = positionIncrease.lt(accountIncrease)
    ? positionIncrease
    : accountIncrease

  // Update max values if there are increases
  if (positionIncrease.gt(BigDecimalConstants.ZERO)) {
    position.maxEverDepositedUSD = currentPositionBalanceUSD
    position.save()
  }

  if (accountIncrease.gt(BigDecimalConstants.ZERO)) {
    maybeReferredAccount.maxEverDepositedUSD = accountTotalBalance
    maybeReferredAccount.save()
  }

  // If account already has referral data, update it
  // This handles subsequent deposits from users who were previously referred
  if (maybeReferredAccount.referralData) {
    return updateExistingReferralData(maybeReferredAccount.referralData!, amountToAddToReferral)
  }

  // Try to extract referral code from event logs for new referrals
  // Only deposits can have referral codes (not withdrawals/unstakes)
  const referralCode = extractReferralCodeFromEvent(event, maybeReferredAccount.id)
  if (referralCode) {
    // Create new referral data and link to account
    return createNewReferralData(referralCode, maybeReferredAccount, amountToAddToReferral)
  }

  return null
}

/**
 * Calculates total USD balance across all positions for an account.
 * This is used for account-level max tracking to prevent cross-vault gaming.
 *
 * @param account - Account to calculate total balance for
 * @returns Total USD balance across all positions
 */
function calculateAccountTotalBalance(account: Account): BigDecimal {
  let totalBalance = BigDecimalConstants.ZERO

  // Sum up balances from all positions
  const positions = account.positions.load()
  for (let i = 0; i < positions.length; i++) {
    const position = positions[i]
    totalBalance = totalBalance.plus(position.inputTokenBalanceNormalizedInUSD)
  }

  return totalBalance
}

/**
 * Extracts referral code from FleetEnteredWithReferral event logs.
 *
 * @param event - The blockchain event
 * @param accountId - Account ID to validate against event
 * @returns Referral code as hex string, or null if not found/invalid
 */
function extractReferralCodeFromEvent(event: ethereum.Event, accountId: string): string | null {
  const admiralsQuartersReferralLogs = getEventLogs(event, EventSignature.FleetEnteredWithReferral)

  if (admiralsQuartersReferralLogs.length == 0) {
    return null
  }

  const admiralQuartersReferralLog = admiralsQuartersReferralLogs[0]

  // Extract referral code from event data (5th element in tuple)
  const referralCode = dataToTuple(
    admiralQuartersReferralLog.data,
    '(uint256,uint256,uint256,uint256,bytes32)',
  )[4]
    .toBytes()
    .toHexString()

  const eventAddress = logTopicToAddress(admiralQuartersReferralLog.topics[1])

  // Validate that the event address matches the account
  if (eventAddress.toHexString() != accountId) {
    return null
  }

  return referralCode
}

/**
 * Updates existing referral data with new deposit amount.
 *
 * @param referralDataId - ID of existing referral data
 * @param amountToAdd - Amount to add to referral total (can be zero)
 * @returns Referral data ID for event tracking
 */
function updateExistingReferralData(referralDataId: string, amountToAdd: BigDecimal): string {
  const referralData = getOrCreateReferralData(referralDataId)

  // Only add to total if there's an incremental amount
  // Always return ID for event tracking (even if amount is zero)
  if (amountToAdd.gt(BigDecimalConstants.ZERO)) {
    referralData.totalReferredUSD = referralData.totalReferredUSD.plus(amountToAdd)
    referralData.save()
  }
  return referralData.id
}

/**
 * Creates new referral data for first-time referred user.
 *
 * @param referralCode - Referral code from event
 * @param referredAccount - Account being referred
 * @param amountToAdd - Initial amount to add to referral total
 * @returns Referral data ID for event tracking
 */
function createNewReferralData(
  referralCode: string,
  referredAccount: Account,
  amountToAdd: BigDecimal,
): string {
  const referralData = getOrCreateReferralData(referralCode)

  // Always increment the referred count when creating new referral data
  // This tracks unique users referred, regardless of deposit amount
  referralData.amountOfReferred = referralData.amountOfReferred.plus(BigInt.fromI32(1))

  // Only add to total if there's an incremental amount
  if (amountToAdd.gt(BigDecimalConstants.ZERO)) {
    referralData.totalReferredUSD = referralData.totalReferredUSD.plus(amountToAdd)
  }
  referralData.save()

  // Link the account to referral data for future tracking
  // This enables withdrawal/unstake events to be tracked under the same referral
  referredAccount.referralData = referralData.id
  referredAccount.save()

  return referralData.id
}

/**
 * Gets or creates referral data entity.
 *
 * @param referralCode - Referral code as hex string
 * @returns ReferralData entity
 */
function getOrCreateReferralData(referralCode: string): ReferralData {
  let referralData = ReferralData.load(referralCode)
  if (!referralData) {
    referralData = new ReferralData(referralCode)
    referralData.amountOfReferred = BigInt.fromI32(0)
    referralData.totalReferredUSD = BigDecimal.fromString('0')
  }
  return referralData
}
