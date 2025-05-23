import { BigDecimal, ethereum } from '@graphprotocol/graph-ts'
import { Account, ReferralAmount, ReferralData } from '../../../generated/schema'
import { EventSignature } from '../../common/constants'
import { PositionDetails } from '../../types'
import { dataToTuple, getEventLogs } from '../../utils/events'

export function handleReferrals(
  event: ethereum.Event,
  referredAccount: Account,
  positionDetails: PositionDetails,
): void {
  if (referredAccount.referralData) {
    const referralData = getOrCreateReferralData(
      referredAccount.referralData!,
      positionDetails.inputTokenDeltaNormalizedUSD,
    )
    getOrCreateReferralAmount(
      `${positionDetails.account}-${positionDetails.vault}`,
      referralData.id,
      positionDetails,
    )
  } else {
    const admiralsQuartersReferralLogs = getEventLogs(
      event,
      EventSignature.FleetEnteredWithReferral,
    )
    if (admiralsQuartersReferralLogs.length > 0) {
      const admiralQuartersReferralLog = admiralsQuartersReferralLogs[0]
      const referralCode = dataToTuple(
        admiralQuartersReferralLog.data,
        '(uint256,uint256,bytes)',
      )[2]
        .toBytes()
        .toHexString()

      if (admiralQuartersReferralLog.topics[1].toHexString() == referredAccount.id) {
        const referralData = getOrCreateReferralData(
          referralCode,
          positionDetails.inputTokenDeltaNormalizedUSD,
        ).id
        referredAccount.referralData = referralData
        getOrCreateReferralAmount(
          `${positionDetails.account}-${positionDetails.vault}`,
          referralData,
          positionDetails,
        )
        referredAccount.save()
      }
    }
  }
}

function getOrCreateReferralData(referralCode: string, amountInUSD: BigDecimal): ReferralData {
  let referralData = ReferralData.load(referralCode)
  if (!referralData) {
    referralData = new ReferralData(referralCode)
    referralData.totalReferredUSD = amountInUSD

    referralData.save()
  } else {
    referralData.totalReferredUSD = referralData.totalReferredUSD.plus(amountInUSD)
    referralData.save()
  }
  return referralData
}

export function getOrCreateReferralAmount(
  id: string,
  referralDataId: string,
  positionDetails: PositionDetails,
): ReferralAmount {
  let referralAmount = ReferralAmount.load(id)
  if (!referralAmount) {
    referralAmount = new ReferralAmount(id)
    referralAmount.amount = positionDetails.inputTokenDelta
    referralAmount.amountNormalized = positionDetails.inputTokenDeltaNormalized
    referralAmount.amountInUSD = positionDetails.inputTokenDeltaNormalizedUSD
    referralAmount.refferalData = referralDataId
    referralAmount.token = positionDetails.inputToken.id
    referralAmount.save()
    return referralAmount
  } else {
    referralAmount.amount = referralAmount.amount.plus(positionDetails.inputTokenDelta)
    referralAmount.amountNormalized = referralAmount.amountNormalized.plus(
      positionDetails.inputTokenDeltaNormalized,
    )
    referralAmount.amountInUSD = referralAmount.amountInUSD.plus(
      positionDetails.inputTokenDeltaNormalizedUSD,
    )
    referralAmount.save()
    return referralAmount
  }
}
