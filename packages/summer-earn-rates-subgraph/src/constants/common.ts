import { Address, BigDecimal, BigInt } from '@graphprotocol/graph-ts'

export const SUPPORTED_NETWORKS = ['mainnet', 'arbitrum-one', 'optimism', 'base']

/** Numeric Constants */
export class BigDecimalConstants {
  static ZERO: BigDecimal = BigDecimal.fromString('0')
  static ONE: BigDecimal = BigDecimal.fromString('1')
  static HUNDRED: BigDecimal = BigDecimal.fromString('100')
  static SECONDS_PER_DAY: BigDecimal = BigDecimal.fromString('86400')
  static SECONDS_PER_WEEK: BigDecimal = BigDecimal.fromString('604800')
  static SECONDS_PER_MONTH: BigDecimal = BigDecimal.fromString('2628000')
  static SECONDS_PER_YEAR: BigDecimal = BigDecimal.fromString('31536000')
  static WAD: BigDecimal = BigDecimal.fromString(BigInt.fromI32(10).pow(18).toString())
  static RAY: BigDecimal = BigDecimal.fromString(BigInt.fromI32(10).pow(27).toString())
  static RAD: BigDecimal = BigDecimal.fromString(BigInt.fromI32(10).pow(45).toString())
  static CHAIN_LINK_PRECISION: BigDecimal = BigDecimal.fromString(`${10 ** 8}`)
}

export class BigIntConstants {
  static MINUS_ONE: BigInt = BigInt.fromI32(-1)
  static ZERO: BigInt = BigInt.fromI32(0)
  static ONE: BigInt = BigInt.fromI32(1)
  static TEN: BigInt = BigInt.fromI32(10)
  static WAD: BigInt = BigInt.fromI32(10).pow(18)
  static RAY: BigInt = BigInt.fromI32(10).pow(27)
  static RAD: BigInt = BigInt.fromI32(10).pow(45)
  static FIVE_MINUTES_IN_SECONDS: BigInt = BigInt.fromI32(300)
  static TEN_MINUTES_IN_SECONDS: BigInt = BigInt.fromI32(600)
  static TWENTY_MINUTES_IN_SECONDS: BigInt = BigInt.fromI32(1200)
  static THIRTY_MINUTES_IN_SECONDS: BigInt = BigInt.fromI32(1800)
  static WEEK_IN_SECONDS: BigInt = BigInt.fromI32(604800)
  static EPOCH_WEEK_OFFSET: BigInt = BigInt.fromI32(345600)
  static HOUR_IN_SECONDS: BigInt = BigInt.fromI32(3600)
  static DAY_IN_SECONDS: BigInt = BigInt.fromI32(86400)
  static YEAR_IN_SECONDS: BigInt = BigInt.fromI32(31536000)
  static CHAIN_LINK_PRECISION: BigInt = BigInt.fromString(`${10 ** 8}`)
}

/** Address Constants */
export class CHAINLINK_DENOMINATIONS {
  static USD: Address = Address.fromString('0x0000000000000000000000000000000000000348')
  static ETH: Address = Address.fromString('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE')
  static BTC: Address = Address.fromString('0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB')
  static GBP: Address = Address.fromString('0x000000000000000000000000000000000000033a')
  static EUR: Address = Address.fromString('0x00000000000000000000000000000000000003d2')
  static JPY: Address = Address.fromString('0x0000000000000000000000000000000000000188')
  static KRW: Address = Address.fromString('0x000000000000000000000000000000000000019a')
  static CNY: Address = Address.fromString('0x000000000000000000000000000000000000009c')
  static AUD: Address = Address.fromString('0x0000000000000000000000000000000000000024')
  static CAD: Address = Address.fromString('0x000000000000000000000000000000000000007c')
  static CHF: Address = Address.fromString('0x00000000000000000000000000000000000002f4')
  static ARS: Address = Address.fromString('0x0000000000000000000000000000000000000020')
  static PHP: Address = Address.fromString('0x0000000000000000000000000000000000000260')
  static NZD: Address = Address.fromString('0x000000000000000000000000000000000000022a')
  static SGD: Address = Address.fromString('0x00000000000000000000000000000000000002be')
  static NGN: Address = Address.fromString('0x0000000000000000000000000000000000000236')
  static ZAR: Address = Address.fromString('0x00000000000000000000000000000000000002c6')
  static RUB: Address = Address.fromString('0x0000000000000000000000000000000000000283')
  static INR: Address = Address.fromString('0x0000000000000000000000000000000000000164')
  static BRL: Address = Address.fromString('0x00000000000000000000000000000000000003da')
}

export class i64Constants {
  static DAY_IN_SECONDS: i64 = 86400
  static WEEK_IN_SECONDS: i64 = 86400 * 7
}
