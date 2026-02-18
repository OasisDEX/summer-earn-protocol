import { ethers } from 'ethers'

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

// Role constants (matching OpenZeppelin TimelockController)
export const PROPOSER_ROLE = ethers.keccak256(ethers.toUtf8Bytes('PROPOSER_ROLE'))
export const EXECUTOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes('EXECUTOR_ROLE'))
export const CANCELLER_ROLE = ethers.keccak256(ethers.toUtf8Bytes('CANCELLER_ROLE'))
export const DEFAULT_ADMIN_ROLE =
  '0x0000000000000000000000000000000000000000000000000000000000000000'

// Mapping of role hashes to role names for decoding (normalized to lowercase)
const ROLE_HASH_TO_NAME: Record<string, string> = {
  [PROPOSER_ROLE.toLowerCase()]: 'PROPOSER_ROLE',
  [EXECUTOR_ROLE.toLowerCase()]: 'EXECUTOR_ROLE',
  [CANCELLER_ROLE.toLowerCase()]: 'CANCELLER_ROLE',
  [DEFAULT_ADMIN_ROLE.toLowerCase()]: 'DEFAULT_ADMIN_ROLE',
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
  args: any[]
  paramNames: string[]
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
  formattedProposals?: Array<{
    target: string
    targetName: string
    value: string
    decodedCall?: DecodedFunction
  }>
}

// Map of known function ABIs
const KNOWN_ABIS = {
  // Cross-chain execution
  sendProposalToTargetChain:
    'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
  send: {
    inputs: [
      {
        components: [
          { name: 'dstEid', type: 'uint32' },
          { name: 'to', type: 'bytes32' },
          { name: 'amountLD', type: 'uint256' },
          { name: 'minAmountLD', type: 'uint256' },
          { name: 'extraOptions', type: 'bytes' },
          { name: 'composeMsg', type: 'bytes' },
          { name: 'oftCmd', type: 'bytes' },
        ],
        name: 'sendParams',
        type: 'tuple',
      },
      {
        components: [
          { name: 'nativeFee', type: 'uint256' },
          { name: 'lzTokenFee', type: 'uint256' },
        ],
        name: 'feeParams',
        type: 'tuple',
      },
      { name: '_refundAddress', type: 'address' },
    ],
    name: 'send',
    outputs: [],
    stateMutability: 'external',
    type: 'function',
  },
  // Harbor Command functions
  grantCuratorRole: 'function grantCuratorRole(address fleetAddress, address account) external',
  grantAdmiralsQuartersRole: 'function grantAdmiralsQuartersRole(address account) external',
  revokeAdmiralsQuartersRole: 'function revokeAdmiralsQuartersRole(address account) external',
  grantCommanderRole: 'function grantCommanderRole(address arkAddress, address account) external',
  addArk: 'function addArk(address ark) external',
  enlistFleetCommander: 'function enlistFleetCommander(address fleetCommander) external',
  grantRole: 'function grantRole(bytes32 role, address account) external',
  revokeRole: 'function revokeRole(bytes32 role, address account) external',
  grantGovernorRole: 'function grantGovernorRole(address account) external',
  revokeGovernorRole: 'function revokeGovernorRole(address account) external',
  grantSuperKeeperRole: 'function grantSuperKeeperRole(address account) external',
  revokeSuperKeeperRole: 'function revokeSuperKeeperRole(address account) external',
  grantGuardianRole: 'function grantGuardianRole(address account) external',
  revokeGuardianRole: 'function revokeGuardianRole(address account) external',
  setGuardianExpiration:
    'function setGuardianExpiration(address account, uint256 expiration) external',
  grantDecayControllerRole: 'function grantDecayControllerRole(address account) external',
  revokeDecayControllerRole: 'function revokeDecayControllerRole(address account) external',
  // Rewards functions
  notifyRewardAmount:
    'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration) external',
  setRewardsDuration:
    'function setRewardsDuration(address rewardToken, uint256 _rewardsDuration) external',
  // configuration manager functions
  setRaft: 'function setRaft(address raft) external',
  // raft functions
  sweep: 'function sweep(address ark,address[] tokens) external',
  // ark sweep functions
  sweepArk: 'function sweep(address[] tokens) external',

  // ERC20 functions
  approve: 'function approve(address spender, uint256 amount) external returns (bool)',
  transfer: 'function transfer(address to, uint256 amount) external returns (bool)',
  transferFrom:
    'function transferFrom(address from, address to, uint256 amount) external returns (bool)',

  // gov
  setVotingDelay: 'function setVotingDelay(uint48 newVotingDelay) external',
  setVotingPeriod: 'function setVotingPeriod(uint32 newVotingPeriod) external',
  setQuorumNumerator: 'function setQuorumNumerator(uint256 newQuorumNumerator) external',
  setProposalThreshold: 'function setProposalThreshold(uint256 newProposalThreshold) external',
  setProposalMaxOperations:
    'function setProposalMaxOperations(uint256 newProposalMaxOperations) external',
  setProposalMaxDuration:
    'function setProposalMaxDuration(uint256 newProposalMaxDuration) external',
  updateDelay: 'function updateDelay(uint256 newDelay) external',
  addToWhitelist: 'function addToWhitelist(address account) external',

  // fleet commander functions
  setFleetTokenTransferability: 'function setFleetTokenTransferability() external',

  // TimelockController functions
  timelockSchedule:
    'function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt, uint256 delay) public',
  timelockScheduleBatch:
    'function scheduleBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads, bytes32 predecessor, bytes32 salt, uint256 delay) public',
  timelockExecute:
    'function execute(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt) public payable',
  timelockExecuteBatch:
    'function executeBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads, bytes32 predecessor, bytes32 salt) public payable',
  timelockCancel: 'function cancel(bytes32 id) public',
  hashOperation:
    'function hashOperation(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt) public pure returns (bytes32)',
  hashOperationBatch:
    'function hashOperationBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads, bytes32 predecessor, bytes32 salt) public pure returns (bytes32)',
  hasRole: 'function hasRole(bytes32 role, address account) public view returns (bool)',

  // Governor functions (for completeness)
  castVote: 'function castVote(uint256 proposalId, uint8 support) public returns (uint256)',
  governorPropose:
    'function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public returns (uint256)',
  governorExecute:
    'function execute(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public payable returns (uint256)',
  governorCancel:
    'function cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public returns (uint256)',
  createCampaign:
    'function createCampaign((bytes32 campaignId, address creator, address rewardToken, uint256 amount, uint32 campaignType, uint32 startTimestamp, uint32 duration, bytes campaignData)) external returns (uint256)',
  setNonSweepableToken:
    'function setNonSweepableToken(address ark, address token, bool isNonSweepable) external',
  validateTimestamp: 'function validateTimestamp() external',
  removeRoot: 'function removeRoot(uint256 index) external',
  // TipJar functions
  addTipStream: {
    type: 'function',
    name: 'addTipStream',
    inputs: [
      {
        name: 'tipStream',
        type: 'tuple',
        internalType: 'struct ITipJar.TipStream',
        components: [
          { name: 'recipient', type: 'address', internalType: 'address' },
          { name: 'allocation', type: 'uint256', internalType: 'Percentage' },
          { name: 'lockedUntilEpoch', type: 'uint256', internalType: 'uint256' },
        ],
      },
    ],
    outputs: [{ name: 'lockedUntilEpoch', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'nonpayable',
  },
}

// Create interfaces for each ABI
const interfaces = Object.entries(KNOWN_ABIS).reduce(
  (acc, [name, abi]) => {
    acc[name] = new ethers.Interface([abi])
    return acc
  },
  {} as Record<string, ethers.Interface>,
)

/**
 * Gets role tags for an address based on role information
 * @param address The address to get role tags for
 * @param roleInfo Optional role information object
 * @returns Array of role tags (e.g., ['PROPOSER', 'EXECUTOR'])
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
function decodeAddress(address: string, network?: SupportedNetworks): string {
  // Default to BASE (hub chain) when network is not provided
  const targetNetwork = network ?? SupportedNetworks.BASE
  const name = addresToContractName(address, targetNetwork)
  if (name !== 'Unknown') {
    return `${targetNetwork}:${name}(${address})`
  }
  return address
}

// Function to decode any calldata using known ABIs
export const decodeCalldata = (
  calldata: string,
  network?: SupportedNetworks,
): DecodedFunction | null => {
  for (const [name, iface] of Object.entries(interfaces)) {
    try {
      const decoded = iface.parseTransaction({ data: calldata })
      if (decoded) {
        // Recursively get parameter names from the ABI
        const getParamNames = (
          inputs: readonly ethers.ParamType[],
        ): (string | { name: string; components: any[] })[] => {
          return inputs.map((input) => {
            if (input.type === 'tuple') {
              // For tuples, create an object with nested parameter names
              const nestedNames = getParamNames(input.components || [])
              return {
                name: input.name,
                components: nestedNames,
              }
            }
            return input.name
          })
        }

        // Get parameter names from the ABI
        const fragment = iface.fragments[0]
        const paramNames = fragment.inputs ? getParamNames(fragment.inputs) : []

        // Recursively process arguments to handle tuples
        const processArg = (arg: any, paramName: any): any => {
          if (Array.isArray(arg)) {
            // If we have component names, use them as keys
            if (paramName?.components) {
              const result: any = {}
              arg.forEach((value, index) => {
                const componentName = paramName.components[index]
                if (typeof componentName === 'string') {
                  result[componentName] = processArg(value, paramName.components[index])
                } else {
                  result[componentName.name] = processArg(value, componentName)
                }
              })
              return result
            }
            // Otherwise, just process each array element
            return arg.map((item, index) => processArg(item, paramName?.[index]))
          }
          if (typeof arg === 'object' && arg !== null) {
            // Handle tuple types
            const processedObj: any = {}
            for (const [key, value] of Object.entries(arg)) {
              const nestedParamName = paramName?.components?.[key] || key
              processedObj[nestedParamName] = processArg(value, paramName?.components?.[key])
            }
            return processedObj
          }
          // Check if it's a bytes32 role hash
          if (typeof arg === 'string' && arg.startsWith('0x') && arg.length === 66) {
            const normalizedHash = arg.toLowerCase()
            if (ROLE_HASH_TO_NAME[normalizedHash]) {
              return `${ROLE_HASH_TO_NAME[normalizedHash]} (${arg})`
            }
          }
          // Check if it's an address (42 chars: 0x + 40 hex)
          if (typeof arg === 'string' && arg.startsWith('0x') && arg.length === 42) {
            return decodeAddress(arg, network)
          }
          return arg
        }

        const decodedArgs = decoded.args.map((arg, index) => processArg(arg, paramNames[index]))

        return {
          functionName: name,
          args: decodedArgs,
          paramNames: paramNames.map((p) => (typeof p === 'string' ? p : p.name)),
        }
      }
    } catch (error) {
      console.error('Error decoding calldata:', error)
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
    const decodedCalldatas = dstCalldatas.map((calldata: string) =>
      decodeCalldata(calldata, network),
    )

    // Get contract names for the targets
    const targetContractNames = dstTargets.map((target: string) =>
      addresToContractName(target, network),
    )

    // Format proposals for better readability
    const formattedProposals = dstTargets.map((target: string, index: number) => ({
      target: target.toLowerCase(),
      targetName: targetContractNames[index],
      value: dstValues[index].toString(),
      decodedCall: decodedCalldatas[index],
    }))

    return {
      dstEid: network,
      dstTargets: dstTargets.map((addr: string) => addr.toLowerCase()),
      dstTargetNames: targetContractNames,
      dstValues: dstValues.map((val: bigint) => val.toString()),
      dstCalldatas: dstCalldatas,
      dstDescriptionHash: dstDescriptionHash,
      options,
      decodedCalldatas,
      formattedProposals,
    }
  } catch (error) {
    console.error('Error decoding cross-chain calldata:', error)
    return null
  }
}

export function addresToContractName(address: string, network: SupportedNetworks): string {
  const networkConfig = typedConfig[network]
  const normalizedAddress = address.toLowerCase()

  // First check the main config
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

  const deployedAddresses = deployedAddressesByNetwork[network]
  if (!deployedAddresses) {
    console.warn(`No deployed addresses found for network ${network}`)
    return 'Unknown'
  }

  for (const [contractName, contractAddress] of Object.entries(deployedAddresses)) {
    if (contractAddress.toLowerCase() === normalizedAddress) {
      return contractName
    }
  }

  return 'Unknown'
}

export const validateTargets = (
  targets: string[],
  network: SupportedNetworks = SupportedNetworks.BASE,
): ValidationResult => {
  const errors: string[] = []
  const validAddresses = new Set<string>()
  const contractNames: string[] = []

  // Collect valid addresses from the specified network only
  const networkConfig = typedConfig[network]
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

  // Collect addresses from the specified network
  collectAddresses(networkConfig)

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

    // Find the contract name in the specified network
    const contractName = addresToContractName(normalizedTarget, network)
    if (contractName !== 'Unknown') {
      contractNames[index] = `${network}:${contractName}(${normalizedTarget})`
    } else {
      contractNames[index] = `Unknown(${normalizedTarget})`
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
    for (const iface of Object.values(interfaces)) {
      try {
        const parsed = iface.parseTransaction({ data: calldata })
        if (parsed) {
          decoded = true
          break
        }
      } catch {
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
  try {
    const selector = interfaces.sendProposalToTargetChain.getFunction(
      'sendProposalToTargetChain',
    )?.selector
    if (!selector) return false

    // Check if calldata starts with the sendProposalToTargetChain selector
    if (!calldata.toLowerCase().startsWith(selector.toLowerCase())) {
      return false
    }

    // Verify target is a known governor address from any network
    const normalizedTarget = target.toLowerCase()
    for (const network of Object.values(SupportedNetworks)) {
      const networkConfig = typedConfig[network]
      // Check gov.summerGovernor
      const govGovernor = networkConfig.deployedContracts?.gov?.summerGovernor?.address
      if (govGovernor && govGovernor.toLowerCase() === normalizedTarget) {
        return true
      }
      // Check govV2.summerGovernor
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
