import { ethers } from 'ethers'
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
    [key: string]: any
  }
  protocolSpecific: {
    [key: string]: any
  }
}

type Config = {
  [key in SupportedNetworks]: NetworkConfig
}

// Cast the imported config to our defined type
const typedConfig = config as unknown as Config

interface ValidationResult {
  isValid: boolean
  errors: string[]
  contractNames: string[]
}

interface DecodedFunction {
  functionName: string
  args: any[]
}

export interface CrossChainData {
  dstEid: string
  dstTargets: string[]
  dstTargetNames: string[]
  dstValues: string[]
  dstCalldatas: string[]
  dstDescriptionHash: string
  options: any
  decodedCalldatas?: DecodedFunction[]
}

// Map of known function ABIs
const KNOWN_ABIS = {
  // Cross-chain execution
  sendProposalToTargetChain:
    'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',

  // Harbor Command functions
  grantCuratorRole: 'function grantCuratorRole(address fleetAddress, address account) external',
  grantAdmiralsQuartersRole: 'function grantAdmiralsQuartersRole(address account) external',
  revokeAdmiralsQuartersRole: 'function revokeAdmiralsQuartersRole(address account) external',
  grantCommanderRole: 'function grantCommanderRole(address arkAddress, address account) external',
  addArk: 'function addArk(address ark) external',
  enlistFleetCommander: 'function enlistFleetCommander(address fleetCommander) external',

  // Rewards functions
  notifyRewardAmount:
    'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration) external',
  setRewardsDuration:
    'function setRewardsDuration(address rewardToken, uint256 _rewardsDuration) external',

  // ERC20 functions
  approve: 'function approve(address spender, uint256 amount) external returns (bool)',
}

// Create interfaces for each ABI
const interfaces = Object.entries(KNOWN_ABIS).reduce(
  (acc, [name, abi]) => {
    acc[name] = new ethers.Interface([abi])
    return acc
  },
  {} as Record<string, ethers.Interface>,
)

// Function to decode any calldata using known ABIs
export const decodeCalldata = (calldata: string): DecodedFunction | null => {
  for (const [name, iface] of Object.entries(interfaces)) {
    try {
      const decoded = iface.parseTransaction({ data: calldata })
      if (decoded) {
        return {
          functionName: name,
          args: decoded.args,
        }
      }
    } catch (error) {
      // Continue to next interface
    }
  }
  return null
}

// Function to decode cross-chain calldata
export const decodeCrossChainCalldata = (calldata: string): CrossChainData | null => {
  try {
    const decoded = interfaces.sendProposalToTargetChain.parseTransaction({ data: calldata })

    if (!decoded) {
      throw new Error('Failed to decode calldata')
    }

    const [dstEid, dstTargets, dstValues, dstCalldatas, dstDescriptionHash, options] = decoded.args

    // Get the network config for the destination chain
    const dstIdAsString = dstEid.toString() as DstId
    const network = dstEidToChainIdMap[dstIdAsString] as SupportedNetworks

    // Decode nested calldatas
    const decodedCalldatas = dstCalldatas.map((calldata: string) => decodeCalldata(calldata))
    const networkConfig = typedConfig[network]

    // Get contract names for the targets
    const targetContractNames = dstTargets.map((target: string) =>
      addresToContractName(target, network),
    )

    return {
      dstEid: network,
      dstTargets: dstTargets.map((addr: string) => addr.toLowerCase()),
      dstTargetNames: targetContractNames,
      dstValues: dstValues.map((val: bigint) => val.toString()),
      dstCalldatas: dstCalldatas,
      dstDescriptionHash: dstDescriptionHash,
      options,
      decodedCalldatas,
    }
  } catch (error) {
    console.error('Error decoding cross-chain calldata:', error)
    return null
  }
}

function addresToContractName(address: string, network: SupportedNetworks): string {
  const networkConfig = typedConfig[network]
  const normalizedAddress = address.toLowerCase()

  // Iterate through top-level contract categories (core, gov, buyAndBurn)
  for (const category in networkConfig.deployedContracts) {
    const contracts = networkConfig.deployedContracts[category]

    // Iterate through contracts in this category
    for (const contractName in contracts) {
      const contract = contracts[contractName]

      // Check if the address matches
      if (contract.address && contract.address.toLowerCase() === normalizedAddress) {
        return `${category}.${contractName}`
      }
    }
  }

  // Check if it's a token address
  for (const tokenName in networkConfig.tokens) {
    const tokenAddress = networkConfig.tokens[tokenName]
    if (tokenAddress && tokenAddress.toLowerCase() === normalizedAddress) {
      return `token.${tokenName}`
    }
  }

  return 'Unknown'
}

export const validateTargets = (targets: string[]): ValidationResult => {
  const errors: string[] = []
  const validAddresses = new Set<string>()
  const contractNames: string[] = []

  // Collect all valid addresses from the config
  const collectAddresses = (obj: any) => {
    if (typeof obj !== 'object' || obj === null) return
    if (
      typeof obj.address === 'string' &&
      obj.address !== '0x0000000000000000000000000000000000000000'
    ) {
      validAddresses.add(obj.address.toLowerCase())
    }
    Object.values(obj).forEach(collectAddresses)
  }

  // Collect addresses from all networks
  Object.values(typedConfig).forEach(collectAddresses)

  // Validate each target
  targets.forEach((target, index) => {
    if (!target) {
      errors.push(`Target at index ${index} is empty`)
      contractNames[index] = 'Unknown'
      return
    }

    const normalizedTarget = target.toLowerCase()
    if (!normalizedTarget.startsWith('0x') || normalizedTarget.length !== 42) {
      errors.push(`Target at index ${index} is not a valid Ethereum address`)
      contractNames[index] = 'Invalid'
      return
    }

    // Try to find the contract name in each network
    let found = false
    for (const network of Object.values(SupportedNetworks)) {
      const contractName = addresToContractName(normalizedTarget, network)
      if (contractName !== 'Unknown') {
        contractNames[index] = `${network}:${contractName}`
        found = true
        break
      }
    }

    if (!found) {
      contractNames[index] = 'Unknown'
      if (!validAddresses.has(normalizedTarget)) {
        errors.push(
          `Target at index ${index} (${normalizedTarget}) is not a known contract address`,
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
    contractNames: [], // Not applicable for values, but required by the interface
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

    // Basic hex validation
    if (!/^0x[0-9a-fA-F]*$/.test(calldata)) {
      errors.push(`Calldata at index ${index} contains invalid hex characters`)
      return
    }

    // Try to decode the calldata with known ABIs
    let decoded = false
    for (const [name, iface] of Object.entries(interfaces)) {
      try {
        const parsed = iface.parseTransaction({ data: calldata })
        if (parsed) {
          decoded = true
          break
        }
      } catch (error) {
        // Continue to next interface
      }
    }

    if (!decoded) {
      errors.push(`Calldata at index ${index} could not be decoded with any known ABI`)
    }
  })

  return {
    isValid: errors.length === 0,
    errors,
    contractNames: [], // Not applicable for calldatas, but required by the interface
  }
}

// Helper function to check if a calldata is a cross-chain execution
export const isCrossChainExecution = (target: string, calldata: string): boolean => {
  const governorAddress = '0xBE5A4DD68c3526F32B454fE28C9909cA0601e9Fa'

  try {
    const selector = interfaces.sendProposalToTargetChain.getFunction(
      'sendProposalToTargetChain',
    )?.selector
    if (!selector) return false

    return (
      target.toLowerCase() === governorAddress.toLowerCase() &&
      calldata.toLowerCase().startsWith(selector)
    )
  } catch (error) {
    return false
  }
}
