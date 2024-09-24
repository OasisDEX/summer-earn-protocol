import { Address, dataSource } from '@graphprotocol/graph-ts'
import { arbitrumTokenByAddress, arbitrumTokens } from '../constants/arbitrum'
import { baseTokenByAddress, baseTokens } from '../constants/base'
import { Token } from '../constants/common'
import { mainnetTokenByAddress, mainnetTokens } from '../constants/mainnet'
import { optimismTokenByAddress, optimismTokens } from '../constants/optimism'

export function getTokensProvider(): Token[] {
  const network = dataSource.network()

  if (network == 'mainnet') {
    return mainnetTokens
  } else if (network == 'arbitrum-one') {
    return arbitrumTokens
  } else if (network == 'base') {
    return baseTokens
  } else if (network == 'optimism') {
    return optimismTokens
  }

  throw new Error(`Unsupported network: ${network}`)
}

export const tokens = getTokensProvider()

export function getTokenByAddressProvider(): Map<Address, Token> {
  const network = dataSource.network()

  if (network == 'mainnet') {
    return mainnetTokenByAddress
  } else if (network == 'arbitrum-one') {
    return arbitrumTokenByAddress
  } else if (network == 'base') {
    return baseTokenByAddress
  } else if (network == 'optimism') {
    return optimismTokenByAddress
  }

  throw new Error(`Unsupported network: ${network}`)
}

export const tokenByAddress = getTokenByAddressProvider()
