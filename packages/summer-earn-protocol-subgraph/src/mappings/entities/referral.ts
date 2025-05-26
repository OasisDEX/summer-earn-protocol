import { BigDecimal, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { Account, ReferralData } from '../../../generated/schema'
import * as constants from '../../common/constants'
import { BigDecimalConstants, BigIntConstants, EventSignature } from '../../common/constants'
import { PositionDetails } from '../../types'
import { dataToTuple, getEventLogs, logTopicToAddress } from '../../utils/events'

/**
 * Handles referral tracking for deposits and stakes.
 *
 * REFERRAL TRACKING LOGIC:
 * 1. Only processes deposits/stakes (positive inputTokenDeltaNormalizedUSD)
 * 2. Only tracks users who don't already have referral data (prevents double-referrals)
 * 3. Credits the full deposit amount in USD to the referral
 * 4. Links accounts to referral codes on first referral deposit
 *
 * REFERRAL ELIGIBILITY:
 * - New users (no existing positions) can always be referred
 * - Existing users can only earn referral credits if they already have referral data
 * - This prevents existing users from being referred for the first time
 * - Ensures first referrals are only for genuine new user acquisition
 * - But allows previously referred users to continue earning credits on new deposits
 *
 * SIMPLIFIED TRACKING:
 * - No complex max tracking or cross-vault gaming protection needed
 * - Full deposit amount is credited to referral (no partial crediting)
 * - Referral data is updated hourly, minimizing gaming risks
 *
 * WITHDRAWAL/UNSTAKE TRACKING:
 * - Withdrawals/unstakes are tracked separately in fleetCommander.ts
 * - They use account.referralData directly for analytics (no new referral processing)
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
  // Skip referral tracking for existing users who don't already have referral data
  // This means: only new users (no positions) OR existing users with referral data can be processed
  // Prevents existing users from being referred for the first time (only new users can get first referrals)
  if (maybeReferredAccount.positions.load().length != 0 && !maybeReferredAccount.referralData) {
    return null
  }

  // Early exit for withdrawals, unstakes, and zero amounts
  // These are tracked separately in fleetCommander.ts using account.referralData
  if (positionDetails.inputTokenDeltaNormalizedUSD.le(BigDecimalConstants.ZERO)) {
    return null
  }

  // Credit the full deposit amount to referral (no complex max tracking needed)
  // Since only first deposits count, there's no risk of gaming
  // they are updated hourly - minimizing the risk of gaming
  const amountToAddToReferral = positionDetails.inputTokenDeltaNormalizedUSD

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
    referralData.protocol = constants.Protocol.NAME
    referralData.amountOfReferred = BigIntConstants.ZERO
    referralData.totalReferredUSD = BigDecimalConstants.ZERO
  }
  return referralData
}
