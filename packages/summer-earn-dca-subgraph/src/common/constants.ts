import { BigInt } from '@graphprotocol/graph-ts'

export namespace StrategyStatus {
  export const ACTIVE = 'ACTIVE'
  export const PAUSED = 'PAUSED'
  export const CANCELLED = 'CANCELLED'
  export const COMPLETED = 'COMPLETED'
}

export namespace BigIntConstants {
  export const ZERO = BigInt.zero()
  export const ONE = BigInt.fromI32(1)
  export const HOUR = BigInt.fromI32(3600)
  export const HOUR_MINUS_ONE = BigInt.fromI32(3599)
}
