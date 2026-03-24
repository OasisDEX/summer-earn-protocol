import {
  Abi,
  decodeFunctionData,
  formatUnits,
  Hex,
  keccak256,
  parseAbiItem,
  toBytes,
  toFunctionSelector,
} from 'viem'

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
export const PROPOSER_ROLE = keccak256(toBytes('PROPOSER_ROLE'))
export const EXECUTOR_ROLE = keccak256(toBytes('EXECUTOR_ROLE'))
export const CANCELLER_ROLE = keccak256(toBytes('CANCELLER_ROLE'))
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
  options: any
  decodedCalldatas?: DecodedFunction[]
  formattedProposals?: Array<{
    target: string
    targetName: string
    value: string
    decodedCall?: DecodedFunction
  }>
}

// Separate string ABIs from Object ABIs to properly maintain internalTypes for Percentage
const KNOWN_STRING_ABIS = [
  'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
  'function grantCuratorRole(address fleetAddress, address account) external',
  'function grantAdmiralsQuartersRole(address account) external',
  'function revokeAdmiralsQuartersRole(address account) external',
  'function grantCommanderRole(address arkAddress, address account) external',
  'function addArk(address ark) external',
  'function enlistFleetCommander(address fleetCommander) external',
  'function grantRole(bytes32 role, address account) external',
  'function revokeRole(bytes32 role, address account) external',
  'function grantGovernorRole(address account) external',
  'function revokeGovernorRole(address account) external',
  'function grantSuperKeeperRole(address account) external',
  'function revokeSuperKeeperRole(address account) external',
  'function grantGuardianRole(address account) external',
  'function revokeGuardianRole(address account) external',
  'function setGuardianExpiration(address account, uint256 expiration) external',
  'function grantDecayControllerRole(address account) external',
  'function revokeDecayControllerRole(address account) external',
  'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration) external',
  'function setRewardsDuration(address rewardToken, uint256 _rewardsDuration) external',
  'function setRaft(address raft) external',
  'function sweep(address ark,address[] tokens) external',
  'function sweep(address[] tokens) external',
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function transfer(address to, uint256 amount) external returns (bool)',
  'function transferFrom(address from, address to, uint256 amount) external returns (bool)',
  'function setVotingDelay(uint48 newVotingDelay) external',
  'function setVotingPeriod(uint32 newVotingPeriod) external',
  'function setQuorumNumerator(uint256 newQuorumNumerator) external',
  'function setProposalThreshold(uint256 newProposalThreshold) external',
  'function setProposalMaxOperations(uint256 newProposalMaxOperations) external',
  'function setProposalMaxDuration(uint256 newProposalMaxDuration) external',
  'function updateDelay(uint256 newDelay) external',
  'function addToWhitelist(address account) external',
  'function setFleetTokenTransferability() external',
  'function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt, uint256 delay) public',
  'function scheduleBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads, bytes32 predecessor, bytes32 salt, uint256 delay) public',
  'function execute(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt) public payable',
  'function executeBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads, bytes32 predecessor, bytes32 salt) public payable',
  'function cancel(bytes32 id) public',
  'function hashOperation(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt) public pure returns (bytes32)',
  'function hashOperationBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads, bytes32 predecessor, bytes32 salt) public pure returns (bytes32)',
  'function hasRole(bytes32 role, address account) public view returns (bool)',
  'function castVote(uint256 proposalId, uint8 support) public returns (uint256)',
  'function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public returns (uint256)',
  'function cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public returns (uint256)',
  'function createCampaign((bytes32 campaignId, address creator, address rewardToken, uint256 amount, uint32 campaignType, uint32 startTimestamp, uint32 duration, bytes campaignData)) external returns (uint256)',
  'function setNonSweepableToken(address ark, address token, bool isNonSweepable) external',
  'function validateTimestamp() external',
  'function removeRoot(uint256 index) external',
]

const KNOWN_OBJECT_ABIS = [
  {
    type: 'function',
    name: 'send',
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
    outputs: [],
    stateMutability: 'external',
  },
  {
    type: 'function',
    name: 'setTipRate',
    inputs: [
      {
        name: 'newTipRate',
        type: 'uint256',
        internalType: 'Percentage',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
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
]

// Unified ABI containing both formatted objects and parsed strings
export const COMBINED_ABI: Abi = [
  ...KNOWN_STRING_ABIS.map((sig) => parseAbiItem(sig)),
  ...KNOWN_OBJECT_ABIS,
] as Abi

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
function decodeAddress(address: string, network?: SupportedNetworks): string {
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
        (item: any) => item.inputs?.length === (decoded.args?.length || 0),
      ) as any

      if (!fragment) return null

      // Recursively pull out param names and exact internal types mapped back from JSON fragments
      const getParamInfo = (inputs: readonly any[]): any[] => {
        return inputs.map((input) => {
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
      let fixedDecimals: number | null = null
      let usedFallback = false

      if (targetAddress) {
        const contractName = addresToContractName(targetAddress, targetNetwork)
        if (contractName.startsWith('token.')) {
          const tokenName = contractName.split('.').pop()?.toLowerCase()
          if (tokenName && TOKEN_DECIMALS[tokenName]) {
            fixedDecimals = TOKEN_DECIMALS[tokenName]
          }
        } else if (contractName.startsWith('gov.summerToken')) {
          fixedDecimals = 18
        }
      }

      if (fixedDecimals === null) {
        fixedDecimals = 18
        usedFallback = true
      }

      // Recursively process arguments to handle tuples and special types
      const processArg = (arg: any, paramInfo: any): any => {
        // Viem maps tuples directly to Objects, and arrays correctly to arrays
        if (Array.isArray(arg)) {
          return arg.map((item) =>
            processArg(item, { ...paramInfo, type: paramInfo?.type?.replace('[]', '') }),
          )
        }

        if (paramInfo?.components && typeof arg === 'object' && arg !== null) {
          const result: any = {}
          paramInfo.components.forEach((compInfo: any) => {
            result[compInfo.name] = processArg(arg[compInfo.name], compInfo)
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
          } catch (e) {
            return arg
          }
        }

        // Handle Token Amounts
        if (
          fixedDecimals !== null &&
          (paramInfo?.name === 'amount' ||
            paramInfo?.name === 'reward' ||
            paramInfo?.name === 'amountLD' ||
            paramInfo?.name === 'minAmountLD')
        ) {
          try {
            const formatted = formatUnits(BigInt(arg.toString()), fixedDecimals)
            return `${arg} [formatted:${formatted}${usedFallback ? ':fallback' : ''}]`
          } catch (e) {
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
  } catch (error) {
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

    const args = decoded.args as any[]
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
    const decodedCalldatas = dstCalldatas.map((nestedCalldata: string, index: number) =>
      decodeCalldata(nestedCalldata, dstTargets[index], network),
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
  } catch {
    return null
  }
}

export function addresToContractName(address: string, network: SupportedNetworks): string {
  const networkConfig = typedConfig[network]
  const normalizedAddress = address.toLowerCase()

  for (const category in networkConfig.deployedContracts) {
    const contracts = networkConfig.deployedContracts[category]

    for (const contractName in contracts) {
      const contract = contracts[contractName]

      if (contract.address && contract.address.toLowerCase() === normalizedAddress) {
        return `${category}.${contractName}`
      }
    }
  }

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

  collectAddresses(networkConfig)

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
