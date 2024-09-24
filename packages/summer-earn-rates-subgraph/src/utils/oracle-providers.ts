import { dataSource } from '@graphprotocol/graph-ts'
import {
  ARBITRUM_CHAINLINK_ORACLES,
  ARBITRUM_DERIVED_CHAINLINK_ORACLES,
  arbitrumDerivedOraclesMap,
} from '../constants/arbitrum'
import {
  BASE_CHAINLINK_ORACLES,
  BASE_DERIVED_CHAINLINK_ORACLES,
  baseDerivedOraclesMap,
} from '../constants/base'
import { DerivedOracleDetails, OracleDetails } from '../constants/common'
import {
  MAINNET_CHAINLINK_ORACLES,
  MAINNET_DERIVED_CHAINLINK_ORACLES,
  mainnetDerivedOraclesMap,
} from '../constants/mainnet'
import {
  OPTIMISM_CHAINLINK_ORACLES,
  OPTIMISM_DERIVED_CHAINLINK_ORACLES,
  optimismDerivedOraclesMap,
} from '../constants/optimism'

export function getOraclesProvider(): OracleDetails[] {
  const network = dataSource.network()

  if (network == 'mainnet') {
    const oracles: OracleDetails[] = MAINNET_CHAINLINK_ORACLES
    return oracles
  } else if (network == 'arbitrum-one') {
    const oracles: OracleDetails[] = ARBITRUM_CHAINLINK_ORACLES
    return oracles
  } else if (network == 'base') {
    const oracles: OracleDetails[] = BASE_CHAINLINK_ORACLES
    return oracles
  } else if (network == 'optimism') {
    const oracles: OracleDetails[] = OPTIMISM_CHAINLINK_ORACLES
    return oracles
  }

  throw new Error(`Unsupported network: ${network}`)
}
export const oracles = getOraclesProvider()

export function getDerivedOraclesProvider(): DerivedOracleDetails[] {
  const network = dataSource.network()

  if (network == 'mainnet') {
    const derivedOracles: DerivedOracleDetails[] = MAINNET_DERIVED_CHAINLINK_ORACLES
    return derivedOracles
  } else if (network == 'arbitrum-one') {
    const derivedOracles: DerivedOracleDetails[] = ARBITRUM_DERIVED_CHAINLINK_ORACLES
    return derivedOracles
  } else if (network == 'base') {
    const derivedOracles: DerivedOracleDetails[] = BASE_DERIVED_CHAINLINK_ORACLES
    return derivedOracles
  } else if (network == 'optimism') {
    const derivedOracles: DerivedOracleDetails[] = OPTIMISM_DERIVED_CHAINLINK_ORACLES
    return derivedOracles
  }

  throw new Error(`Unsupported network: ${network}`)
}
export const derivedOracles = getDerivedOraclesProvider()

export function getDerivedOraclesMapProvider(): Map<string, DerivedOracleDetails[]> {
  const network = dataSource.network()

  if (network == 'mainnet') {
    return mainnetDerivedOraclesMap
  } else if (network == 'arbitrum-one') {
    return arbitrumDerivedOraclesMap
  } else if (network == 'base') {
    return baseDerivedOraclesMap
  } else if (network == 'optimism') {
    return optimismDerivedOraclesMap
  }

  throw new Error(`Unsupported network: ${network}`)
}

export const derivedOraclesMap = getDerivedOraclesMapProvider()
