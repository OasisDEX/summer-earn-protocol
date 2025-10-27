import * as fs from 'fs'
import kleur from 'kleur'
import * as path from 'path'
import { Address, Hex, encodeFunctionData, parseAbi } from 'viem'
import { ChainSetup } from '../utils/prompts'
import { constructLzOptions } from './options'
import { hashDescription } from './proposal'

export interface CrossChainProtocolConfig {
  protocol: string
  fleetProxyAddress: string | null
  crossChainArkAddress: string | null
}

export interface CrossChainDestination {
  chainId: number
  name: string
  protocols: CrossChainProtocolConfig[]
}

export interface CrossChainConfig {
  fleetName: string
  sourceChainId: number
  destinations: CrossChainDestination[]
}

export interface CrossChainAction {
  target: Address
  value: bigint
  calldata: Hex
}

const CONFIG_DIR = path.join(process.cwd(), 'config', 'cross-chain')

/**
 * Loads cross-chain configuration for a fleet
 * @param fleetName The fleet name
 * @returns Cross-chain configuration or null if not found
 */
export function loadCrossChainConfig(fleetName: string): CrossChainConfig | null {
  const configPath = path.join(CONFIG_DIR, `${fleetName}.json`)
  if (!fs.existsSync(configPath)) {
    console.log(kleur.yellow(`No cross-chain config found for ${fleetName}`))
    return null
  }

  try {
    const configContent = fs.readFileSync(configPath, 'utf-8')
    return JSON.parse(configContent) as CrossChainConfig
  } catch (error) {
    console.error(kleur.red(`Error loading cross-chain config for ${fleetName}: ${error}`))
    return null
  }
}

/**
 * Saves cross-chain configuration for a fleet
 * @param fleetName The fleet name
 * @param updateData The data to update
 */
export function saveCrossChainConfig(
  fleetName: string,
  updateData: {
    chainId?: number
    protocol?: string
    fleetProxyAddress?: string
    crossChainArkAddress?: string
    sourceChainId?: number
  },
): void {
  const configPath = path.join(CONFIG_DIR, `${fleetName}.json`)

  // Create directories if they don't exist
  if (!fs.existsSync(CONFIG_DIR)) {
    fs.mkdirSync(CONFIG_DIR, { recursive: true })
  }

  let config: CrossChainConfig

  // Load existing config or create a new one
  if (fs.existsSync(configPath)) {
    config = JSON.parse(fs.readFileSync(configPath, 'utf-8')) as CrossChainConfig
  } else {
    config = {
      fleetName,
      sourceChainId: 0, // Will need to be set manually or by parameter
      destinations: [],
    }
  }

  // Update sourceChainId if provided
  if (updateData.sourceChainId) {
    config.sourceChainId = updateData.sourceChainId
  }

  // If chainId and protocol are provided, we need to update a specific protocol in a destination
  if (updateData.chainId && updateData.protocol) {
    // Find destination by chainId
    let destination = config.destinations.find((d) => d.chainId === updateData.chainId)

    // If destination doesn't exist, create it
    if (!destination) {
      destination = {
        chainId: updateData.chainId,
        name: `chain-${updateData.chainId}`, // Default name
        protocols: [],
      }
      config.destinations.push(destination)
    }

    // Find protocol in the destination
    let protocolConfig = destination.protocols.find((p) => p.protocol === updateData.protocol)

    // If protocol doesn't exist, create it
    if (!protocolConfig) {
      protocolConfig = {
        protocol: updateData.protocol,
        fleetProxyAddress: null,
        crossChainArkAddress: null,
      }
      destination.protocols.push(protocolConfig)
    }

    // Update the protocol configuration
    if (updateData.fleetProxyAddress) {
      protocolConfig.fleetProxyAddress = updateData.fleetProxyAddress
    }

    if (updateData.crossChainArkAddress) {
      protocolConfig.crossChainArkAddress = updateData.crossChainArkAddress
    }
  }

  // Write the updated config back to the file
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2))
  console.log(kleur.green(`Updated cross-chain config for ${fleetName}`))
}

/**
 * Helper function to find a specific protocol configuration
 * @param config The cross-chain configuration
 * @param chainId The chain ID
 * @param protocol The protocol name
 * @returns The protocol configuration or null if not found
 */
export function findProtocolConfig(
  config: CrossChainConfig,
  chainId: number,
  protocol: string,
): CrossChainProtocolConfig | null {
  const destination = config.destinations.find((d) => d.chainId === chainId)
  if (!destination) return null

  const protocolConfig = destination.protocols.find((p) => p.protocol === protocol)
  return protocolConfig || null
}

/**
 * Builds a cross-chain proposal action that can be executed on the source chain
 * to create a proposal on a target chain.
 *
 * @param params Configuration parameters for the cross-chain proposal
 * @returns A proposal action that can be included in a source chain proposal
 */
export async function buildCrossChainProposalAction(params: {
  targetChain: ChainSetup
  targets: Address[]
  values: bigint[]
  calldatas: Hex[]
  description: string
  governorAddress: Address
  gasLimit?: bigint
}): Promise<CrossChainAction> {
  const {
    targetChain,
    targets,
    values,
    calldatas,
    description,
    governorAddress,
    gasLimit = 350000n,
  } = params

  const targetEndpointId = targetChain.config.common.layerZero.eID
  const lzOptions = constructLzOptions(gasLimit)

  const crossChainCalldata = encodeFunctionData({
    abi: parseAbi([
      'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
    ]),
    args: [
      Number(targetEndpointId),
      targets,
      values,
      calldatas,
      hashDescription(description),
      lzOptions,
    ],
  }) as Hex

  console.log(`Prepared cross-chain proposal action for chain ${targetChain.name}`)

  return {
    target: governorAddress,
    value: 0n,
    calldata: crossChainCalldata,
  }
}
