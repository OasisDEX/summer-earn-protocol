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
}

/**
 * Apply a single ERC-1155 receipt transfer:
 *   - update per-user Receipt balance and mint/burn counters
 *   - update per-round `receiptSupply` (live mirror of on-chain totalSupply)
 *   - emit an immutable ReceiptTransfer row
 *
 * Mints always target the current OPENED round (see RoundsVaultBase._getMintId).
 * Burns happen via:
 *   - `redeem`              on an OPENED round  (post-rollback is also OPENED)
 *   - `redeemExchangeAsset` on a SETTLED round
 * In all cases supply decreases by `amount`, so this branch is uniform.
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

  if (isMint) {
    round.receiptSupply = round.receiptSupply.plus(amount)
    round.save()
  } else if (isBurn) {
    round.receiptSupply = round.receiptSupply.minus(amount)
    round.save()
  }

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
 * Mark an already-burned receipt amount as having been queue-cancel-redeemed
 * (OPENED-phase `redeem`), returning underlying 1:1 to the user. Called from
 * RedeemReceipt handlers AFTER applyReceiptTransfer has already booked the
 * burn. The 1:1 invariant comes from ERC4626MultiToken._redeem:
 *   _burn(owner, id, amount);
 *   safeTransfer(_asset, receiver, amount);
 * so the underlying returned equals the receipt amount burned.
 */
export function markUnderlyingRedemption(
  vaultAddr: Address,
  owner: Address,
  roundId: BigInt,
  amount: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return
  let round = getOrCreateRound(vault, roundId, event.block)
  let user = getOrCreateAccount(owner.toHexString())
  let receipt = getOrCreateReceipt(vault, round, user, event.block)
  receipt.underlyingRedeemed = receipt.underlyingRedeemed.plus(amount)
  receipt.lastUpdated = event.block.timestamp
  receipt.lastUpdatedBlock = event.block.number
  receipt.save()

  round.depositsRedeemed = round.depositsRedeemed.plus(amount)
  round.save()
}

/**
 * Apply a batched queue-cancel redemption. Per-id underlying returned equals
 * per-id receipt `amount` (no rate, no dust — the contract does a single
 * safeTransfer(sum(amounts)) so summing per-id is exact).
 */
export function markUnderlyingRedemptionBatch(
  vaultAddr: Address,
  owner: Address,
  ids: BigInt[],
  amounts: BigInt[],
  event: ethereum.Event,
): void {
  for (let i = 0; i < ids.length; i++) {
    markUnderlyingRedemption(vaultAddr, owner, ids[i], amounts[i], event)
  }
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
  receipt.totalRedeemedForExchangeAsset = receipt.totalRedeemedForExchangeAsset.plus(receiptAmount)
  receipt.exchangeAssetReceived = receipt.exchangeAssetReceived.plus(exchangeAmount)
  receipt.lastUpdated = event.block.timestamp
  receipt.lastUpdatedBlock = event.block.number
  receipt.save()

  round.exchangeAssetWithdrawn = round.exchangeAssetWithdrawn.plus(exchangeAmount)
  round.save()
}

/**
 * Attribute a batched exchange-asset redemption per-id, mirroring the contract's
 * per-id `mulDiv(receiptAmount, base, quote)` against each round's settled rate
 * (stored on the Round entity from RoundSettled). Rounding dust between the sum
 * of per-id amounts and the event's total is folded onto the last row so the
 * cumulative counters still equal the on-chain transfer.
 */
export function markExchangeAssetRedemptionBatch(
  vaultAddr: Address,
  owner: Address,
  ids: BigInt[],
  amounts: BigInt[],
  totalExchangeAsset: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return

  let computed = new Array<BigInt>(ids.length)
  let sumComputed = BigIntConstants.ZERO
  for (let i = 0; i < ids.length; i++) {
    let round = getOrCreateRound(vault, ids[i], event.block)
    let base = round.exchangeRateBase
    let quote = round.exchangeRateQuote
    let part: BigInt
    if (base === null || quote === null || quote.equals(BigIntConstants.ZERO)) {
      log.warning('Exchange-asset batch redemption on unsettled round {} for vault {}', [
        ids[i].toString(),
        vaultAddr.toHexString(),
      ])
      part = BigIntConstants.ZERO
    } else {
      part = amounts[i].times(base).div(quote)
    }
    computed[i] = part
    sumComputed = sumComputed.plus(part)
  }

  let dust = totalExchangeAsset.minus(sumComputed)
  if (dust.notEqual(BigIntConstants.ZERO) && computed.length > 0) {
    let lastIdx = computed.length - 1
    computed[lastIdx] = computed[lastIdx].plus(dust)
  }

  for (let i = 0; i < ids.length; i++) {
    markExchangeAssetRedemption(vaultAddr, owner, ids[i], amounts[i], computed[i], event)
  }
}
