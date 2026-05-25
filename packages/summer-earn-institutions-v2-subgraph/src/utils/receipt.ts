import { Address, BigInt, Bytes, ethereum, log } from '@graphprotocol/graph-ts'
import { ReceiptTransfer } from '../../generated/schema'
import {
  getOrCreateAccount,
  getOrCreateReceipt,
  getOrCreateRound,
  getRoundsVaultByAddress,
} from '../common/initializers'
import { ADDRESS_ZERO, BigIntConstants } from '../common/constants'

export class TransferKindStr {
  static MINT(): string {
    return 'MINT'
  }
  static BURN(): string {
    return 'BURN'
  }
  static TRANSFER(): string {
    return 'TRANSFER'
  }
  static REDEEM(): string {
    return 'REDEEM'
  }
}

/**
 * Apply a single ERC-1155 receipt transfer:
 *   - update per-user receipt balance + mint/burn counters
 *   - update vault-level `currentRoundReceiptSupply` and `pendingSettlementAmount`
 *     denormalized counters (rules described inline)
 *   - emit an immutable ReceiptTransfer row
 *
 * Mints always target the current OPENED round (see RoundsVaultBase._getMintId).
 * Burns happen via:
 *   - `redeem`            on a still-OPENED round  → decrement pending
 *   - `redeemExchangeAsset` on a SETTLED round     → no pending change
 */
export function applyReceiptTransfer(
  vaultAddr: Address,
  operator: Address,
  from: Address,
  to: Address,
  roundId: BigInt,
  amount: BigInt,
  event: ethereum.Event,
  batchIndex: i32,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) {
    log.warning('Receipt transfer for unknown vault {}', [vaultAddr.toHexString()])
    return
  }
  let round = getOrCreateRound(vault, roundId, event.block)

  let isMint = from.equals(ADDRESS_ZERO)
  let isBurn = to.equals(ADDRESS_ZERO)
  let kind: string
  if (isMint) {
    kind = TransferKindStr.MINT()
  } else if (isBurn) {
    kind = TransferKindStr.BURN()
  } else {
    kind = TransferKindStr.TRANSFER()
  }

  if (!isMint) {
    let sender = getOrCreateAccount(from.toHexString())
    let senderReceipt = getOrCreateReceipt(vault, round, sender, event.block)
    senderReceipt.balance = senderReceipt.balance.minus(amount)
    senderReceipt.totalBurned = senderReceipt.totalBurned.plus(amount)
    senderReceipt.lastUpdated = event.block.timestamp
    senderReceipt.lastUpdatedBlock = event.block.number
    senderReceipt.save()
  }
  if (!isBurn) {
    let receiver = getOrCreateAccount(to.toHexString())
    let receiverReceipt = getOrCreateReceipt(vault, round, receiver, event.block)
    receiverReceipt.balance = receiverReceipt.balance.plus(amount)
    receiverReceipt.totalMinted = receiverReceipt.totalMinted.plus(amount)
    receiverReceipt.lastUpdated = event.block.timestamp
    receiverReceipt.lastUpdatedBlock = event.block.number
    receiverReceipt.save()
  }

  // Vault-level supply counters
  if (isMint) {
    vault.currentRoundReceiptSupply = vault.currentRoundReceiptSupply.plus(amount)
    vault.pendingSettlementAmount = vault.pendingSettlementAmount.plus(amount)
  } else if (isBurn) {
    // Only OPENED-state burns reduce pending; SETTLED-state burns are
    // already excluded (RoundSettled subtracted the supply once).
    if (round.state == 'OPENED') {
      if (roundId.equals(vault.currentRound)) {
        vault.currentRoundReceiptSupply = vault.currentRoundReceiptSupply.minus(amount)
      }
      vault.pendingSettlementAmount = vault.pendingSettlementAmount.minus(amount)
    }
  }
  if (vault.currentRoundReceiptSupply.lt(BigIntConstants.ZERO)) {
    vault.currentRoundReceiptSupply = BigIntConstants.ZERO
  }
  if (vault.pendingSettlementAmount.lt(BigIntConstants.ZERO)) {
    vault.pendingSettlementAmount = BigIntConstants.ZERO
  }
  vault.save()

  let transferId =
    event.transaction.hash.toHexString() +
    '-' +
    event.logIndex.toString() +
    '-' +
    batchIndex.toString()
  let transfer = new ReceiptTransfer(transferId)
  transfer.vault = vault.id
  transfer.round = round.id
  transfer.from = from as Bytes
  transfer.to = to as Bytes
  transfer.operator = operator as Bytes
  transfer.amount = amount
  transfer.kind = kind
  transfer.blockNumber = event.block.number
  transfer.timestamp = event.block.timestamp
  transfer.txHash = event.transaction.hash
  transfer.save()
}

/**
 * Mark an already-burned receipt amount as having been redeemed for the
 * exchange asset. Called from WithdrawExchangeAsset handlers AFTER
 * applyReceiptTransfer has already booked the burn.
 */
export function markExchangeAssetRedemption(
  vaultAddr: Address,
  owner: Address,
  roundId: BigInt,
  receiptAmount: BigInt,
  exchangeAmount: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return
  let round = getOrCreateRound(vault, roundId, event.block)
  let user = getOrCreateAccount(owner.toHexString())
  let receipt = getOrCreateReceipt(vault, round, user, event.block)
  receipt.totalRedeemedForExchangeAsset =
    receipt.totalRedeemedForExchangeAsset.plus(receiptAmount)
  receipt.exchangeAssetReceived = receipt.exchangeAssetReceived.plus(exchangeAmount)
  receipt.lastUpdated = event.block.timestamp
  receipt.lastUpdatedBlock = event.block.number
  receipt.save()

  vault.cumulativeExchangeAssetWithdrawn = vault.cumulativeExchangeAssetWithdrawn.plus(
    exchangeAmount,
  )
  vault.save()
}
