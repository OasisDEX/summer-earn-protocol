import { BigDecimal, ByteArray, crypto, ethereum } from '@graphprotocol/graph-ts'
import { EMA, InterestRate } from '../../generated/schema'
import { BigDecimalConstants } from '../constants/common'
import { Product } from '../models/Product'

export function handleInterestRate(
  block: ethereum.Block,
  protocolName: string,
  product: Product,
): void {
  const rate = product.getRate(block.timestamp, block.number)
  updateEMA(block, protocolName, product, rate)
  const interestRate = new InterestRate(
    protocolName +
      product.token.id.toHexString() +
      block.number.toString() +
      crypto.keccak256(ByteArray.fromUTF8(product.name)).toHexString(),
  )
  interestRate.blockNumber = block.number
  interestRate.rate = rate
  interestRate.timestamp = block.timestamp
  interestRate.type = 'Supply'
  interestRate.protocol = protocolName
  interestRate.token = product.token.id
  interestRate.productId = product.name
  interestRate.save()
}

export function updateEMA(
  block: ethereum.Block,
  protocolName: string,
  product: Product,
  newRate: BigDecimal,
): void {
  const emaId =
    protocolName +
    product.token.id.toHexString() +
    crypto.keccak256(ByteArray.fromUTF8(product.name)).toHexString() +
    'EMA'

  let ema = EMA.load(emaId)
  if (ema === null) {
    ema = new EMA(emaId)
    ema.value = newRate
    ema.lastUpdateTimestamp = block.timestamp
    ema.protocol = protocolName
    ema.token = product.token.id
    ema.productId = product.name
  } else {
    if (newRate.equals(BigDecimalConstants.ZERO)) {
      ema.lastUpdateTimestamp = block.timestamp
      ema.save()
      return
    }
    const timeDiff = block.timestamp.minus(ema.lastUpdateTimestamp).toI32()
    const N = 21600 // 6 hours in seconds
    const alpha = BigDecimal.fromString('1').minus(
      BigDecimal.fromString('1').div(
        BigDecimal.fromString('1').plus(BigDecimal.fromString(N.toString())),
      ),
    )
    const weight = BigDecimal.fromString('1').minus(alpha)

    // Calculate the decay factor
    let decayFactor = BigDecimal.fromString('1')
    for (let i = 0; i < timeDiff; i++) {
      decayFactor = decayFactor.times(weight)
    }

    // Update EMA
    ema.value = ema.value
      .times(decayFactor)
      .plus(newRate.times(BigDecimal.fromString('1').minus(decayFactor)))
    ema.lastUpdateTimestamp = block.timestamp
  }
  ema.save()
}
