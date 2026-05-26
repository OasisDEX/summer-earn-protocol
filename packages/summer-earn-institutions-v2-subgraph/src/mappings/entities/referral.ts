import { BigInt, Bytes, ethereum } from '@graphprotocol/graph-ts'
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
 * 3. Tracks unique users referred through amountOfReferred counter
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
 * - Tracks unique users referred through amountOfReferred counter
 * - Each new referral increments the counter by 1
 * - Referral data is updated on each new referral
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
  context: string,
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

  // If account already has referral data, return it
  if (maybeReferredAccount.referralData) {
    return maybeReferredAccount.referralData
  }

  // Try to extract referral code from event logs for new referrals
  // Only deposits can have referral codes (not withdrawals/unstakes)
  const referralCode = extractReferralCodeFromEvent(event, maybeReferredAccount.id)
  if (referralCode) {
    // Create new referral data and link to account
    return createNewReferralData(referralCode, maybeReferredAccount, event)
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
  const data = dataToTuple(
    admiralQuartersReferralLog.data,
    '(uint256,uint256,uint256,uint256,bytes32)',
  )
  if (data == null || data.length != 5) {
    return null
  }
  const rawReferralCode = data[4].toBytes()
  const referralCode = extractReferralCodeFromFleetEnteredWithReferral(
    rawReferralCode,
    data[3].toBigInt(),
  )
  const eventAddress = logTopicToAddress(admiralQuartersReferralLog.topics[1])

  // Validate that the event address matches the account
  if (eventAddress.toHexString() != accountId) {
    return null
  }

  return referralCode.toString()
}

function extractReferralCodeFromFleetEnteredWithReferral(data: Bytes, length: BigInt): BigInt {
  if (length.le(BigIntConstants.ZERO)) {
    return BigIntConstants.ZERO
  }
  const trimmedArray = data.subarray(0, length.toI32())
  const trimmedBytes = Bytes.fromUint8Array(trimmedArray.reverse())

  const bigInt = BigInt.fromUnsignedBytes(trimmedBytes)
  if (bigInt.le(BigIntConstants.ZERO)) {
    return BigIntConstants.ZERO
  }
  return bigInt
}

/**
 * Creates new referral data for first-time referred user.
 *
 * @param referralCode - Referral code from event
 * @param referredAccount - Account being referred
 * @returns Referral data ID for event tracking
 */
function createNewReferralData(
  referralCode: string,
  referredAccount: Account,
  event: ethereum.Event,
): string {
  const referralData = getOrCreateReferralData(referralCode)

  // Always increment the referred count when creating new referral data
  // This tracks unique users referred, regardless of deposit amount
  referralData.amountOfReferred = referralData.amountOfReferred.plus(BigInt.fromI32(1))
  referralData.save()

  // Link the account to referral data for future tracking
  // This enables withdrawal/unstake events to be tracked under the same referral
  referredAccount.referralData = referralData.id
  referredAccount.referralTimestamp = event.block.timestamp
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
  }
  return referralData
}
