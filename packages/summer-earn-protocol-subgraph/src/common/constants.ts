import { Address, BigDecimal, BigInt, Bytes, dataSource } from '@graphprotocol/graph-ts'

// The network names corresponding to the Network enum in the schema.
// They also correspond to the ones in `dataSource.network()` after converting to lower case.
// See below for a complete list:
// https://thegraph.com/docs/en/hosted-service/what-is-hosted-service/#supported-networks-on-the-hosted-service
export namespace Network {
  export const ARBITRUM_ONE = 'ARBITRUM-ONE'
  export const ARWEAVE_MAINNET = 'ARWEAVE-MAINNET'
  export const AVALANCHE = 'AVALANCHE'
  export const BOBA = 'BOBA'
  export const BASE = 'BASE'
  export const AURORA = 'AURORA'
  export const BSC = 'BSC' // aka BNB Chain
  export const CELO = 'CELO'
  export const COSMOS = 'COSMOS'
  export const CRONOS = 'CRONOS'
  export const MAINNET = 'MAINNET' // Ethereum mainnet
  export const FANTOM = 'FANTOM'
  export const FUSE = 'FUSE'
  export const HARMONY = 'HARMONY'
  export const JUNO = 'JUNO'
  export const MOONBEAM = 'MOONBEAM'
  export const MOONRIVER = 'MOONRIVER'
  export const NEAR_MAINNET = 'NEAR-MAINNET'
  export const OPTIMISM = 'OPTIMISM'
  export const OSMOSIS = 'OSMOSIS'
  export const MATIC = 'MATIC' // aka Polygon
  export const XDAI = 'XDAI' // aka Gnosis Chain
  export const SONIC_MAINNET = 'SONIC-MAINNET'
}

export namespace ProtocolType {
  export const EXCHANGE = 'EXCHANGE'
  export const LENDING = 'LENDING'
  export const YIELD = 'YIELD'
  export const BRIDGE = 'BRIDGE'
  export const GENERIC = 'GENERIC'
}

export namespace VaultFeeType {
  export const MANAGEMENT_FEE = 'MANAGEMENT_FEE'
  export const PERFORMANCE_FEE = 'PERFORMANCE_FEE'
  export const DEPOSIT_FEE = 'DEPOSIT_FEE'
  export const WITHDRAWAL_FEE = 'WITHDRAWAL_FEE'
}

export namespace RewardTokenType {
  export const DEPOSIT = 'DEPOSIT'
  export const BORROW = 'BORROW'
}

export namespace NULL {
  export const TYPE_STRING = '0x0000000000000000000000000000000000000000'
  export const TYPE_ADDRESS = Address.fromString(TYPE_STRING)
}

export namespace Protocol {
  export const NAME = 'Summer Earn Protocol'
  export const SLUG = 'summer-earn-protocol'
  export const NETWORK = dataSource.network().replace('-', '_').toUpperCase()
}

export namespace ArkVersions {
  export const V_1_0_0 = '1.0.0'
}
export const ADDRESS_ZERO = Address.fromString('0x0000000000000000000000000000000000000000')
export const DEFAULT_MANAGEMENT_FEE = BigInt.fromI32(200)
export const DEFAULT_PERFORMANCE_FEE = BigInt.fromI32(2000)
export const DEFAULT_WITHDRAWAL_FEE = BigInt.fromI32(50)

export const BIGINT_ZERO = BigInt.fromI32(0)
export const BIGINT_ONE = BigInt.fromI32(1)
export const BIGINT_TEN = BigInt.fromI32(10)
export const BIGINT_HUNDRED = BigInt.fromI32(100)

export const BIGDECIMAL_ZERO = new BigDecimal(BIGINT_ZERO)
export const BIGDECIMAL_HUNDRED = BigDecimal.fromString('100')
export const BIGDECIMAL_NEGATIVE_ONE = BigDecimal.fromString('-1')

export const USDC_DECIMALS = 6
export const SECONDS_PER_HOUR = 60 * 60
export const SECONDS_PER_DAY = 60 * 60 * 24
export const SECONDS_PER_WEEK = 60 * 60 * 24 * 7
export const DEFAULT_DECIMALS = BigInt.fromI32(18)
export const DEGRADATION_COEFFICIENT = BIGINT_TEN.pow(18)
export const USDC_DENOMINATOR = BigDecimal.fromString('1000000')
export const LOCKED_PROFIT_DEGRADATION = BigInt.fromString('46000000000000')

export const PROTOCOL_ID = dataSource.address().toHexString()
export const SUMMER_TREASURY_VAULT = Address.fromString(
  '0x0000000000000000000000000000000000000000',
)

export const MAX_UINT256 = BigInt.fromI32(
  // eslint-disable-next-line @typescript-eslint/no-loss-of-precision
  115792089237316195423570985008687907853269984665640564039457584007913129639935,
)

export const MAX_UINT256_STR =
  '115792089237316195423570985008687907853269984665640564039457584007913129639935'

export const BLACKLISTED_TRANSACTION: Bytes[] = []

/** Numeric Constants */
export class BigDecimalConstants {
  static ZERO: BigDecimal = BigDecimal.fromString('0')
  static FIVE_BPS: BigDecimal = BigDecimal.fromString('0.0005')
  static ONE_BPS: BigDecimal = BigDecimal.fromString('0.0001')
  static TEN_BPS: BigDecimal = BigDecimal.fromString('0.001')
  static ONE_PERCENT: BigDecimal = BigDecimal.fromString('0.01')
  static TEN_PERCENT: BigDecimal = BigDecimal.fromString('0.1')
  static ONE: BigDecimal = BigDecimal.fromString('1')
  static TWO: BigDecimal = BigDecimal.fromString('2')
  static SEVEN: BigDecimal = BigDecimal.fromString('7')
  static THIRTY: BigDecimal = BigDecimal.fromString('30')
  static NINETY: BigDecimal = BigDecimal.fromString('90')
  static ONE_EIGHTY: BigDecimal = BigDecimal.fromString('180')
  static THREE_SIXTY_FIVE: BigDecimal = BigDecimal.fromString('365')
  static TEN: BigDecimal = BigDecimal.fromString('10')
  static FIFTY_TWO: BigDecimal = BigDecimal.fromString('52')
  static HUNDRED: BigDecimal = BigDecimal.fromString('100')
  static WAD: BigDecimal = BigDecimal.fromString(BigInt.fromI32(10).pow(18).toString())
  static RAY: BigDecimal = BigDecimal.fromString(BigInt.fromI32(10).pow(27).toString())
  static RAD: BigDecimal = BigDecimal.fromString(BigInt.fromI32(10).pow(45).toString())
  static LEFTOVER: BigDecimal = BigDecimal.fromString('0.00000000000000001')
  static CHAIN_LINK_PRECISION: BigDecimal = BigDecimal.fromString(`${10 ** 8}`)
  static MORPHO_PRECISION: BigDecimal = BigDecimal.fromString(BigInt.fromI32(10).pow(36).toString())
  static VIRTUAL_SHARES: BigDecimal = BigDecimal.fromString(`${10 ** 6}`)
  static USDC_PRECISION: BigDecimal = BigDecimal.fromString(`${10 ** 6}`)
  static YEAR_IN_DAYS: BigDecimal = BigDecimal.fromString('365')
  static YEAR_IN_HOURS: BigDecimal = BigDecimal.fromString('8760')
  static YEAR_IN_SECONDS: BigDecimal = BigDecimal.fromString('31536000')
  static HOUR_IN_SECONDS: BigDecimal = BigDecimal.fromString('3600')
  static DAY_IN_SECONDS: BigDecimal = BigDecimal.fromString('86400')
  static WEEK_IN_SECONDS: BigDecimal = BigDecimal.fromString('604800')
}
export class BigIntConstants {
  static MINUS_ONE: BigInt = BigInt.fromI32(-1)
  static ZERO: BigInt = BigInt.fromI32(0)
  static ONE: BigInt = BigInt.fromI32(1)
  static FIVE: BigInt = BigInt.fromI32(5)
  static TEN: BigInt = BigInt.fromI32(10)
  static EIGHTEEEN: BigInt = BigInt.fromI32(18)
  static WAD: BigInt = BigInt.fromI32(10).pow(18)
  static RAY: BigInt = BigInt.fromI32(10).pow(27)
  static RAD: BigInt = BigInt.fromI32(10).pow(45)
  static HOUR_IN_SECONDS: BigInt = BigInt.fromI32(3600)
  static DAY_IN_SECONDS: BigInt = BigInt.fromI32(86400)
  static WEEK_IN_SECONDS: BigInt = BigInt.fromI32(86400).times(BigInt.fromI32(7))
  static YEAR_IN_SECONDS: BigInt = BigInt.fromI32(31536000)
  static CHAIN_LINK_PRECISION: BigInt = BigInt.fromString(`${10 ** 8}`)
  static USDC_PRECISION: BigInt = BigInt.fromString(`${10 ** 6}`)
  static USDT_PRECISION: BigInt = BigInt.fromString(`${10 ** 6}`)
  static VIRTUAL_SHARES: BigInt = BigInt.fromI32(10).pow(6)
  static SECONDS_PER_DAY: BigInt = BigInt.fromI32(86400)
  static SECONDS_PER_HOUR: BigInt = BigInt.fromI32(3600)
  static SECONDS_PER_MINUTE: BigInt = BigInt.fromI32(60)
  static SECONDS_PER_WEEK: BigInt = BigInt.fromI32(604800)
  static EPOCH_WEEK_OFFSET: BigInt = BigInt.fromI32(345600)
}
