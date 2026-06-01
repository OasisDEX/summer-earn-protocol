import { Address, BigInt, Bytes, ethereum, log } from '@graphprotocol/graph-ts'
import {
  Account,
  Receipt as RVReceipt,
  ReceiptActivity,
  Round as RVRound,
  RoundsVault as RVRoundsVault,
} from '../../generated/schema'
import {
  getOrCreateAccount,
  getOrCreateReceipt,
  getOrCreateRound,
  getRoundsVaultByAddress,
} from '../common/initializers'
import { ADDRESS_ZERO } from '../common/constants'

export class ReceiptActivityTypeStr {
  static DEPOSIT(): string {
    return 'DEPOSIT'
  }
  static REDEEM_CURRENT(): string {
    return 'REDEEM_CURRENT'
  }
  static REDEEM_EXCHANGE(): string {
    return 'REDEEM_EXCHANGE'
  }
  static TRANSFER(): string {
    return 'TRANSFER'
  }
}

/**
 * Append one immutable ReceiptActivity row. This is the single feed that replaces the former
 * running counters — lifetime/volumetric figures are reconstructed by summing these rows, so
 * a handler bug can never silently drift a stored aggregate.
 *
 * `idSuffix` is '' for a single-line event and '-{i}' for the i-th line of a batch event, so
 * each row gets a unique id within its {txHash}-{logIndex}.
 */
export function recordReceiptActivity(
  vault: RVRoundsVault,
  round: RVRound,
  receipt: RVReceipt,
  account: Account,
  type: string,
  caller: Address,
  receiver: Address,
  receiptAmount: BigInt,
  assetAmount: BigInt | null,
  assetToken: string | null,
  event: ethereum.Event,
  idSuffix: string,
): void {
  const id = event.transaction.hash.toHexString() + '-' + event.logIndex.toString() + idSuffix
  const activity = new ReceiptActivity(id)
  activity.vault = vault.id
  activity.round = round.id
  activity.receipt = receipt.id
  activity.account = account.id
  activity.type = type
  activity.caller = caller as Bytes
  activity.receiver = receiver as Bytes
  activity.receiptAmount = receiptAmount
  activity.assetAmount = assetAmount
  activity.assetToken = assetToken
  activity.roundStateAtAction = round.state
  activity.blockNumber = event.block.number
  activity.timestamp = event.block.timestamp
  activity.txHash = event.transaction.hash
  activity.save()
}

/**
 * Apply a single ERC-1155 receipt transfer:
 *   - update per-user Receipt balance (the single source of truth)
 *   - update per-round `receiptSupply` (live mirror of on-chain totalSupply)
 *   - for a pure user-to-user transfer (from!=0 && to!=0) append a TRANSFER activity row
 *
 * Mints (from=0) and burns (to=0) do NOT log here — their activity rows come from the semantic
 * handlers (DepositWithReceipt, RedeemReceipt[Batch], WithdrawExchangeAsset[Batch]) which also
 * carry the realized counter-asset amount. Logging mints/burns here too would double-count.
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

  let senderAccount: Account | null = null
  let senderReceipt: RVReceipt | null = null
  if (!isMint) {
    senderAccount = getOrCreateAccount(from.toHexString())
    senderReceipt = getOrCreateReceipt(vault, round, senderAccount as Account, event.block)
    senderReceipt.balance = senderReceipt.balance.minus(amount)
    senderReceipt.lastUpdated = event.block.timestamp
    senderReceipt.lastUpdatedBlock = event.block.number
    senderReceipt.save()
  }
  if (!isBurn) {
    let receiverAccount = getOrCreateAccount(to.toHexString())
    let receiverReceipt = getOrCreateReceipt(vault, round, receiverAccount, event.block)
    receiverReceipt.balance = receiverReceipt.balance.plus(amount)
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

  if (!isMint && !isBurn && senderReceipt != null && senderAccount != null) {
    recordReceiptActivity(
      vault,
      round,
      senderReceipt as RVReceipt,
      senderAccount as Account,
      ReceiptActivityTypeStr.TRANSFER(),
      operator,
      to,
      amount,
      null,
      null,
      event,
      '-' + batchIndex.toString(),
    )
  }
}

/**
 * Append a queue-cancel redemption (OPENED-phase `redeem`) activity: underlying returned 1:1.
 * The 1:1 invariant comes from ERC4626MultiToken._redeem (burn(amount); safeTransfer(amount)).
 * The receipt balance itself is already booked by the paired ERC-1155 burn in applyReceiptTransfer.
 */
export function markUnderlyingRedemption(
  vaultAddr: Address,
  caller: Address,
  receiver: Address,
  owner: Address,
  roundId: BigInt,
  amount: BigInt,
  event: ethereum.Event,
  idSuffix: string,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return
  let round = getOrCreateRound(vault, roundId, event.block)
  let user = getOrCreateAccount(owner.toHexString())
  let receipt = getOrCreateReceipt(vault, round, user, event.block)
  recordReceiptActivity(
    vault,
    round,
    receipt,
    user,
    ReceiptActivityTypeStr.REDEEM_CURRENT(),
    caller,
    receiver,
    amount,
    amount,
    vault.underlyingToken,
    event,
    idSuffix,
  )
}

export function markUnderlyingRedemptionBatch(
  vaultAddr: Address,
  caller: Address,
  receiver: Address,
  owner: Address,
  ids: BigInt[],
  amounts: BigInt[],
  event: ethereum.Event,
): void {
  for (let i = 0; i < ids.length; i++) {
    markUnderlyingRedemption(
      vaultAddr,
      caller,
      receiver,
      owner,
      ids[i],
      amounts[i],
      event,
      '-' + i.toString(),
    )
  }
}

/**
 * Append a settled-round exchange redemption activity, carrying the realized exchange-asset
 * amount straight from the WithdrawExchangeAsset event. The receipt balance is already booked by
 * the paired ERC-1155 burn in applyReceiptTransfer.
 */
export function markExchangeAssetRedemption(
  vaultAddr: Address,
  caller: Address,
  receiver: Address,
  owner: Address,
  roundId: BigInt,
  receiptAmount: BigInt,
  exchangeAmount: BigInt,
  event: ethereum.Event,
  idSuffix: string,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return
  let round = getOrCreateRound(vault, roundId, event.block)
  let user = getOrCreateAccount(owner.toHexString())
  let receipt = getOrCreateReceipt(vault, round, user, event.block)
  recordReceiptActivity(
    vault,
    round,
    receipt,
    user,
    ReceiptActivityTypeStr.REDEEM_EXCHANGE(),
    caller,
    receiver,
    receiptAmount,
    exchangeAmount,
    vault.exchangeAssetToken,
    event,
    idSuffix,
  )
}

/**
 * Batch variant. The contract pays a single safeTransfer(sum), so per-id realized amounts are
 * the contract's own `mulDiv(receiptAmount, base, quote)` against each round's settled rate, with
 * the rounding dust folded onto the last row so the per-row amounts sum to the on-chain total.
 * This is a deterministic re-derivation from stored rates, not a maintained running counter.
 */
export function markExchangeAssetRedemptionBatch(
  vaultAddr: Address,
  caller: Address,
  receiver: Address,
  owner: Address,
  ids: BigInt[],
  amounts: BigInt[],
  totalExchangeAsset: BigInt,
  event: ethereum.Event,
): void {
  let vault = getRoundsVaultByAddress(vaultAddr)
  if (vault == null) return

  let computed = new Array<BigInt>(ids.length)
  let sumComputed = BigInt.fromI32(0)
  for (let i = 0; i < ids.length; i++) {
    let round = getOrCreateRound(vault, ids[i], event.block)
    let base = round.exchangeRateBase
    let quote = round.exchangeRateQuote
    let part: BigInt
    if (base === null || quote === null || quote.equals(BigInt.fromI32(0))) {
      log.warning('Exchange-asset batch redemption on unsettled round {} for vault {}', [
        ids[i].toString(),
        vaultAddr.toHexString(),
      ])
      part = BigInt.fromI32(0)
    } else {
      part = amounts[i].times(base).div(quote)
    }
    computed[i] = part
    sumComputed = sumComputed.plus(part)
  }

  let dust = totalExchangeAsset.minus(sumComputed)
  if (dust.notEqual(BigInt.fromI32(0)) && computed.length > 0) {
    let lastIdx = computed.length - 1
    computed[lastIdx] = computed[lastIdx].plus(dust)
  }

  for (let i = 0; i < ids.length; i++) {
    markExchangeAssetRedemption(
      vaultAddr,
      caller,
      receiver,
      owner,
      ids[i],
      amounts[i],
      computed[i],
      event,
      '-' + i.toString(),
    )
  }
}
