import { Address } from 'viem'

import { Token } from '../../types/config-types'
import type { CrossChainConfig } from '../lib/config/cross-chain'

export type BaseArkParams = {
  token: {
    address: Address
    symbol: Token
  }
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  fleetName: string
}

type CrossChainProtocolFields = Omit<
  CrossChainConfig['destinations'][number]['protocols'][number],
  'protocol' | 'fleetProxyAddress'
>

export type CrossChainArkDeploymentParams = BaseArkParams &
  Partial<CrossChainProtocolFields> & {
    targetChainId: number
    targetProtocol: string
    fleetProxyAddress: CrossChainConfig['destinations'][number]['protocols'][number]['fleetProxyAddress']
    bridgeRouter?: Address
    crossChainRegistry?: Address
    accessManager?: Address
    configName?: string
    sourceChainId?: number
    hubFleetName?: string
  }

/**
 * Type representing the user input structure used in cross-chain ark deployment functions.
 * This type covers both the return value of getUserInput() and CrossChainArkDeploymentParams.
 * Note: bridgeRouter, crossChainRegistry, and accessManager may be optional in input but
 * are always populated before being passed to deployment functions.
 */
export type CrossChainArkUserInput = {
  token: {
    address: Address
    symbol: Token | string
  }
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  bridgeRouter?: Address
  crossChainRegistry?: Address
  targetChainId: number
  targetProtocol: string
  fleetProxyAddress: CrossChainConfig['destinations'][number]['protocols'][number]['fleetProxyAddress']
  accessManager?: Address
  configName?: string
  fleetName?: string
  sourceChainId?: number
  hubFleetName?: string
}
