import { decodeFunctionData, formatUnits, Hex, keccak256, toFunctionSelector } from 'viem'

import { COMBINED_ABI } from '../config/abis/combined'
import deployedArbitrum from '../config/deployed/arbitrum.json'
import deployedBase from '../config/deployed/base.json'
import deployedMainnet from '../config/deployed/mainnet.json'
import deployedSonic from '../config/deployed/sonic.json'
import config from '../config/index.json'

export enum SupportedNetworks {
  MAINNET = 'mainnet',
  BASE = 'base',
  ARBITRUM = 'arbitrum',
  SONIC = 'sonic',
}

// Define the dstEidToChainIdMap manually since we can't import it
const dstEidToChainIdMap: Record<string, string> = {
  '30101': SupportedNetworks.MAINNET, // Ethereum Mainnet
  '30110': SupportedNetworks.ARBITRUM, // Arbitrum
  '30184': SupportedNetworks.BASE, // Base
  '30332': SupportedNetworks.SONIC, // Sonic
}

// Define DstId type
type DstId = '30101' | '30110' | '30184' | '30332'

// Role constants
export const PROPOSER_ROLE = keccak256(new TextEncoder().encode('PROPOSER_ROLE'))
export const EXECUTOR_ROLE = keccak256(new TextEncoder().encode('EXECUTOR_ROLE'))
export const CANCELLER_ROLE = keccak256(new TextEncoder().encode('CANCELLER_ROLE'))
export const DEFAULT_ADMIN_ROLE =
  '0x0000000000000000000000000000000000000000000000000000000000000000'

// Mapping of role hashes to role names for decoding (normalized to lowercase)
const ROLE_HASH_TO_NAME: Record<string, string> = {
  [PROPOSER_ROLE.toLowerCase()]: 'PROPOSER_ROLE',
  [EXECUTOR_ROLE.toLowerCase()]: 'EXECUTOR_ROLE',
  [CANCELLER_ROLE.toLowerCase()]: 'CANCELLER_ROLE',
  [DEFAULT_ADMIN_ROLE.toLowerCase()]: 'DEFAULT_ADMIN_ROLE',
}

export const WAD = 1000000000000000000n

const TOKEN_DECIMALS: Record<string, number> = {
  usdc: 6,
  usdt: 6,
  eurc: 6,
  weth: 18,
  eth: 18,
  sumr: 18,
}

// Type for role information
export type RoleInfo = {
  proposer?: boolean
  executor?: boolean
  canceller?: boolean
}

// Define config type
type NetworkConfig = {
  deployedContracts: {
    [key: string]: {
      [key: string]: {
        address: string
      }
    }
  }
  tokens: {
    [key: string]: string
  }
  common: {
    chainId: string
    [key: string]: unknown
  }
  protocolSpecific: {
    [key: string]: unknown
  }
}

type Config = {
  [key in SupportedNetworks]: NetworkConfig
}

// Cast the imported config to our defined type
const typedConfig = config as unknown as Config

const deployedAddressesByNetwork: Record<SupportedNetworks, Record<string, string>> = {
  [SupportedNetworks.MAINNET]: deployedMainnet,
  [SupportedNetworks.BASE]: deployedBase,
  [SupportedNetworks.ARBITRUM]: deployedArbitrum,
  [SupportedNetworks.SONIC]: deployedSonic,
}

interface ValidationResult {
  isValid: boolean
  errors: string[]
  contractNames: string[]
}

interface DecodedFunction {
  functionName: string
  args: (string | number | boolean | object)[]
  paramNames: string[]
  internalTypes?: string[]
  isFallbackDecimal?: boolean[]
}

export interface CrossChainData {
  dstEid: string
  dstTargets: string[]
  dstTargetNames: string[]
  dstValues: string[]
  dstCalldatas: string[]
  dstDescriptionHash: string
  options: Hex
  decodedCalldatas?: DecodedFunction[]
  formattedProposals?: Array<{
    target: string
    targetName: string
    value: string
    decodedCall?: DecodedFunction
  }>
}

/**
 * Gets role tags for an address based on role information
 */
export function getRoleTags(address: string, roleInfo?: RoleInfo): string[] {
  if (!roleInfo) return []
  const tags: string[] = []
  if (roleInfo.proposer) tags.push('PROPOSER')
  if (roleInfo.executor) tags.push('EXECUTOR')
  if (roleInfo.canceller) tags.push('CANCELLER')
  return tags
}

// Helper function to decode an address to its contract name
export function addresToContractName(address: string, network: SupportedNetworks): string {
  const networkConfig = typedConfig[network]
  const normalizedAddress = address.toLowerCase()

  for (const category in networkConfig.deployedContracts) {
    const contracts = networkConfig.deployedContracts[category]

    for (const contractName in contracts) {
      const contract = contracts[contractName]

      if (contract.address && contract.address.toLowerCase() === normalizedAddress) {
        return `${category}.${contractName}`.toLowerCase()
      }
    }
  }
  for (const contract in networkConfig.common) {
    const addressCandidate = networkConfig.common[contract]
    if (
      typeof addressCandidate == 'string' &&
      addressCandidate.toLowerCase() === normalizedAddress
    ) {
      return `${contract}`.toLowerCase()
    }
  }

  for (const tokenName in networkConfig.tokens) {
    const tokenAddress = networkConfig.tokens[tokenName]
    if (tokenAddress && tokenAddress.toLowerCase() === normalizedAddress) {
      return `token.${tokenName}`.toLowerCase()
    }
  }

  const deployedAddresses = deployedAddressesByNetwork[network]
  if (!deployedAddresses) {
    console.warn(`No deployed addresses found for network ${network}`)
    return 'unknown'
  }

  for (const [contractName, contractAddress] of Object.entries(deployedAddresses)) {
    if (contractAddress.toLowerCase() === normalizedAddress) {
      return contractName.toLowerCase()
    }
  }

  return 'unknown'
}

export interface DecodedAddress {
  address: string
  name: string
  explorerUrl: string
}

const EXPLORER_URLS: Record<string, string> = {
  mainnet: 'https://etherscan.io/address/',
  base: 'https://basescan.org/address/',
  arbitrum: 'https://arbiscan.io/address/',
  sonic: 'https://sonicscan.org/address/',
  hyperliquid: 'https://explorer.hyperliquid.xyz/address/',
}

export function decodeAddress(address: string, network?: SupportedNetworks): DecodedAddress {
  const targetNetwork = network ?? SupportedNetworks.BASE
  const name = addresToContractName(address, targetNetwork)
  const baseUrl = EXPLORER_URLS[targetNetwork] || EXPLORER_URLS.base

  return {
    address,
    name: name !== 'unknown' ? `${targetNetwork}:${name}` : 'unknown',
    explorerUrl: `${baseUrl}${address}`,
  }
}

interface ParamInfo {
  name: string
  internalType: string
  type: string
  components?: ParamInfo[]
}

// Function to decode any calldata using known ABIs
export const decodeCalldata = (
  calldata: string,
  targetAddress?: string,
  network?: SupportedNetworks,
): DecodedFunction | null => {
  const targetNetwork = network ?? SupportedNetworks.BASE

  try {
    const decoded = decodeFunctionData({
      abi: COMBINED_ABI,
      data: calldata as Hex,
    })

    if (decoded) {
      // Find the specific function ABI from COMBINED_ABI to extract rich internalTypes.
      // We filter by name and approximate parameter match to handle overloads like sweep()
      const abiItems = COMBINED_ABI.filter(
        (item) => item.type === 'function' && item.name === decoded.functionName,
      )
      const fragment = abiItems.find(
        (item) => item.type === 'function' && item.inputs?.length === (decoded.args?.length || 0),
      )

      if (!fragment || fragment.type !== 'function') return null

      // Recursively pull out param names and exact internal types mapped back from JSON fragments
      const getParamInfo = (inputs: readonly unknown[]): ParamInfo[] => {
        return (inputs as any[]).map((input) => {
          if (input.type === 'tuple' || input.type.startsWith('tuple[')) {
            return {
              name: input.name,
              internalType: input.internalType || input.type,
              type: input.type,
              components: getParamInfo(input.components || []),
            }
          }
          return {
            name: input.name,
            internalType: input.internalType || input.type,
            type: input.type,
          }
        })
      }

      const paramInfos = fragment.inputs ? getParamInfo(fragment.inputs) : []

      // Determine token-specific decimals for the function if relevant
      let currentDecimals: number = 18
      let currentUsedFallback = true
      let currentTokenSymbol = 'Tokens'

      const updateContextFromAddress = (address: string) => {
        const name = addresToContractName(address, targetNetwork)
        if (name === 'unknown') return

        const isFleetCommander = name.includes('fleetcommander')
        if (name.startsWith('token.')) {
          const tokenName = name.split(/[.#]/).pop()

          if (tokenName && TOKEN_DECIMALS[tokenName]) {
            currentDecimals = TOKEN_DECIMALS[tokenName]
            currentTokenSymbol = tokenName.toUpperCase()
            currentUsedFallback = false
          }
        } else if (name.startsWith('gov.summertoken')) {
          currentDecimals = 18
          currentTokenSymbol = 'SUMMER'
          currentUsedFallback = false
        } else if (isFleetCommander) {
          for (const tokenName in TOKEN_DECIMALS) {
            if (name.includes(tokenName)) {
              currentDecimals = TOKEN_DECIMALS[tokenName]
              currentTokenSymbol = name.replace(/[.#]fleetcommander/i, ' shares')
              currentUsedFallback = false
              break
            }
          }
        }
      }

      if (targetAddress) {
        updateContextFromAddress(targetAddress)
      }

      // Recursively process arguments to handle tuples and special types
      const processArg = (arg: any, paramInfo: ParamInfo): any => {
        // Viem maps tuples directly to Objects, and arrays correctly to arrays
        if (Array.isArray(arg)) {
          return arg.map((item) =>
            processArg(item, { ...paramInfo, type: paramInfo?.type?.replace('[]', '') }),
          )
        }

        if (paramInfo?.components && typeof arg === 'object' && arg !== null) {
          const result: Record<string, any> = {}
          paramInfo.components.forEach((compInfo) => {
            result[compInfo.name] = processArg(arg[compInfo.name as keyof typeof arg], compInfo)
          })
          return result
        }

        const internalType = paramInfo?.internalType || ''

        // Properly catch Percentage type derived from COMBINED_ABI metadata
        if (internalType === 'Percentage' || internalType.includes('Percentage')) {
          try {
            const bigVal = BigInt(arg.toString())
            const percent = Number(bigVal * 10000n) / Number(WAD) / 100
            return `${arg} (${percent.toFixed(2)}%)`
          } catch {
            return arg
          }
        }

        // Handle Token Amounts
        if (
          paramInfo?.type !== 'address' &&
          (paramInfo?.name.toLowerCase().includes('amount') ||
            paramInfo?.name.toLowerCase().includes('reward') ||
            paramInfo?.name.toLowerCase().includes('value'))
        ) {
          try {
            const formatted = formatUnits(BigInt(arg.toString()), currentDecimals)
            return `${arg} [formatted:${formatted} ${currentTokenSymbol}${
              currentUsedFallback ? ':fallback' : ''
            }]`
          } catch {
            return arg
          }
        }

        // Check if it's a bytes32 role hash
        if (typeof arg === 'string' && arg.startsWith('0x') && arg.length === 66) {
          const normalizedHash = arg.toLowerCase()
          if (ROLE_HASH_TO_NAME[normalizedHash]) {
            return `${ROLE_HASH_TO_NAME[normalizedHash]} (${arg})`
          }
        }

        // Check if it's an address
        if (typeof arg === 'string' && arg.startsWith('0x') && arg.length === 42) {
          const nameLower = paramInfo?.name?.toLowerCase() || ''
          if (
            nameLower.includes('token') ||
            nameLower.includes('asset') ||
            nameLower.includes('reward')
          ) {
            updateContextFromAddress(arg)
          }
          return decodeAddress(arg, network)
        }

        return typeof arg === 'bigint' ? arg.toString() : arg
      }

      const decodedArgs = (decoded.args || []).map((arg, index) =>
        processArg(arg, paramInfos[index]),
      )

      return {
        functionName: decoded.functionName,
        args: decodedArgs,
        paramNames: paramInfos.map((p) => p.name),
        internalTypes: paramInfos.map((p) => p.internalType),
      }
    }
  } catch {
    // Continue/Return null on fail to mirror old iteration behaviour
  }
  return null
}

// Function to decode cross-chain calldata
export const decodeCrossChainCalldata = (calldata: string): CrossChainData | null => {
  try {
    const decoded = decodeFunctionData({
      abi: COMBINED_ABI,
      data: calldata as Hex,
    })

    if (decoded.functionName !== 'sendProposalToTargetChain') {
      throw new Error('Calldata is not sendProposalToTargetChain')
    }

    const args = decoded.args as [number, string[], bigint[], string[], Hex, Hex]
    const dstEid = args[0]
    const dstTargets = args[1]
    const dstValues = args[2]
    const dstCalldatas = args[3]
    const dstDescriptionHash = args[4]
    const options = args[5]

    // Get the network config for the destination chain
    const dstIdAsString = dstEid.toString() as DstId
    const network = dstEidToChainIdMap[dstIdAsString] as SupportedNetworks

    // Decode nested calldatas
    const decodedCalldatas = dstCalldatas
      .map((nestedCalldata, index) => decodeCalldata(nestedCalldata, dstTargets[index], network))
      .filter((d): d is DecodedFunction => d !== null)

    // Get contract names for the targets
    const targetContractNames = dstTargets.map((target) => addresToContractName(target, network))

    // Format proposals for better readability
    const formattedProposals = dstTargets.map((target, index) => ({
      target: target.toLowerCase(),
      targetName: targetContractNames[index],
      value: dstValues[index].toString(),
      decodedCall: decodedCalldatas[index],
    }))

    return {
      dstEid: network,
      dstTargets: dstTargets.map((addr) => addr.toLowerCase()),
      dstTargetNames: targetContractNames,
      dstValues: dstValues.map((val) => val.toString()),
      dstCalldatas: dstCalldatas,
      dstDescriptionHash: dstDescriptionHash,
      options,
      decodedCalldatas,
      formattedProposals,
    }
  } catch {
    return null
  }
}

export const validateTargets = (
  targets: string[],
  network: SupportedNetworks = SupportedNetworks.BASE,
): ValidationResult => {
  const errors: string[] = []
  const validAddresses = new Set<string>()
  const contractNames: string[] = []

  const networkConfig = typedConfig[network]
  const collectAddresses = (obj: unknown) => {
    if (typeof obj !== 'object' || obj === null) return
    const record = obj as Record<string, unknown>
    if (
      typeof record.address === 'string' &&
      record.address !== '0x0000000000000000000000000000000000000000'
    ) {
      validAddresses.add((record.address as string).toLowerCase())
    }
    Object.values(record).forEach(collectAddresses)
  }

  collectAddresses(networkConfig)

  targets.forEach((target, index) => {
    if (!target) {
      errors.push(`Target at index ${index} is empty`)
      contractNames[index] = 'unknown'
      return
    }

    const normalizedTarget = target.toLowerCase()
    if (!normalizedTarget.startsWith('0x') || normalizedTarget.length !== 42) {
      errors.push(`Target at index ${index} is not a valid Ethereum address`)
      contractNames[index] = 'Invalid'
      return
    }

    const contractName = addresToContractName(normalizedTarget, network)
    if (contractName !== 'unknown') {
      contractNames[index] = `${network}:${contractName}(${normalizedTarget})`
    } else {
      contractNames[index] = `unknown(${normalizedTarget})`
      if (!validAddresses.has(normalizedTarget)) {
        errors.push(
          `Target at index ${index} (${normalizedTarget}) is not a known contract address on ${network}`,
        )
      }
    }
  })

  return {
    isValid: errors.length === 0,
    errors,
    contractNames,
  }
}

export const validateValues = (values: string[]): ValidationResult => {
  const errors: string[] = []

  values.forEach((value, index) => {
    if (!value) {
      errors.push(`Value at index ${index} is empty`)
      return
    }

    const numValue = Number(value)
    if (isNaN(numValue)) {
      errors.push(`Value at index ${index} is not a valid number`)
      return
    }

    if (numValue < 0) {
      errors.push(`Value at index ${index} cannot be negative`)
    }
  })

  return {
    isValid: errors.length === 0,
    errors,
    contractNames: [],
  }
}

export const validateCalldatas = (calldatas: string[]): ValidationResult => {
  const errors: string[] = []

  calldatas.forEach((calldata, index) => {
    if (!calldata) {
      errors.push(`Calldata at index ${index} is empty`)
      return
    }

    if (!calldata.startsWith('0x')) {
      errors.push(`Calldata at index ${index} must start with '0x'`)
      return
    }

    if (!/^0x[0-9a-fA-F]*$/.test(calldata)) {
      errors.push(`Calldata at index ${index} contains invalid hex characters`)
      return
    }

    try {
      decodeFunctionData({ abi: COMBINED_ABI, data: calldata as Hex })
    } catch {
      errors.push(`Calldata at index ${index} could not be decoded with any known ABI`)
    }
  })

  return {
    isValid: errors.length === 0,
    errors,
    contractNames: [],
  }
}

// Helper function to check if a calldata is a cross-chain execution
export const isCrossChainExecution = (target: string, calldata: string): boolean => {
  try {
    const selector = toFunctionSelector(
      'function sendProposalToTargetChain(uint32,address[],uint256[],bytes[],bytes32,bytes)',
    )

    if (!calldata.toLowerCase().startsWith(selector.toLowerCase())) {
      return false
    }

    const normalizedTarget = target.toLowerCase()
    for (const network of Object.values(SupportedNetworks)) {
      const networkConfig = typedConfig[network]
      const govGovernor = networkConfig.deployedContracts?.gov?.summerGovernor?.address
      if (govGovernor && govGovernor.toLowerCase() === normalizedTarget) {
        return true
      }
      const govV2Governor = networkConfig.deployedContracts?.govV2?.summerGovernor?.address
      if (govV2Governor && govV2Governor.toLowerCase() === normalizedTarget) {
        return true
      }
    }

    return false
  } catch {
    return false
  }
}
