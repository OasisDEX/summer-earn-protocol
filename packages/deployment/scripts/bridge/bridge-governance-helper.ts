import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { Address, encodeFunctionData, Hex, parseAbi } from 'viem'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { getChainConfigByChainId } from '../helpers/chain-configs'
import { getChainPublicClient } from '../helpers/client-by-chain-helper'
import { getConfigByNetwork } from '../helpers/config-handler'
import { getHubChain } from '../helpers/get-hub-chain'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { createGovernanceProposal } from '../helpers/proposal-helpers'
import { LZ_ENDPOINT_ABI } from './lz-endpoint-abi'

/**
 * Check if the current deployer is authorized by the LZ endpoint
 * @param lzEndpointAddress The address of the LZ endpoint contract
 * @param oAppAddress The address of the OApp
 * @param publicClient The Viem public client to use for the call
 * @param deployerAddress The address of the deployer to check authorization for
 * @param chainName Optional chain name for logging purposes
 * @returns An object containing the delegate address and whether the deployer is authorized
 */
export async function checkLzAuthorization(
  lzEndpointAddress: Address,
  oAppAddress: Address,
  deployerAddress: Address,
  chainName: string,
): Promise<{ delegate: Address; isAuthorized: boolean }> {
  const publicClient = await getChainPublicClient(chainName)

  console.log(kleur.blue('Checking LZ authorization for OApp:'), kleur.cyan(oAppAddress))
  console.log(kleur.blue('Using deployer:'), kleur.cyan(deployerAddress))
  console.log(kleur.blue('On chain:'), kleur.cyan(chainName))

  // Call the endpoint contract to check the delegate
  const delegate = (await publicClient.readContract({
    address: lzEndpointAddress,
    abi: LZ_ENDPOINT_ABI,
    functionName: 'delegates',
    args: [oAppAddress],
  })) as Address

  // Check if the deployer is authorized (either as owner or delegate)
  const isAuthorized =
    delegate === deployerAddress || delegate === '0x0000000000000000000000000000000000000000'

  console.log(kleur.blue('Delegate for OApp:'), kleur.cyan(delegate))
  console.log(
    kleur.blue('Is deployer authorized:'),
    isAuthorized ? kleur.green('Yes') : kleur.red('No'),
  )

  return { delegate, isAuthorized }
}

/**
 * Generates a proposal description for updating OApp configurations
 */
export function generateLzConfigProposalDescription(
  oAppAddress: Address,
  oAppName: string,
  chainName: string,
  sendLibraryAddress: Address,
  receiveLibraryAddress: Address,
  sendParams: any[],
  receiveParams: any[],
  delegate: Address,
  deployer: Address,
  isCrossChain: boolean = false,
  targetChain?: string,
  hubChain?: string,
): string {
  // Format params for better readability
  const formatParams = (params: any[]) => {
    return params
      .map((param, index) => {
        return `   - Parameter ${index + 1}: EID ${param.eid}, ConfigType ${param.configType}, Config: ${param.config}`
      })
      .join('\n')
  }

  const formattedSendParams = formatParams(sendParams)
  const formattedReceiveParams = formatParams(receiveParams)

  if (!isCrossChain) {
    return `# LayerZero Configuration Update for ${oAppName} on ${chainName}

## Summary
This proposal updates the LayerZero endpoint configuration for the ${oAppName} application on ${chainName}.

## Motivation
The current delegate address for the OApp does not match the deployer's address, requiring governance to update the configuration.

## Technical Details
- OApp Address: ${oAppAddress}
- Current Delegate: ${delegate}
- Expected Delegate: ${deployer}
- Send Library: ${sendLibraryAddress}
- Receive Library: ${receiveLibraryAddress}

## Specifications
### Actions
1. Set Send Library Configuration (ULN & Executor)
   Parameters:
${formattedSendParams}

2. Set Receive Library Configuration (ULN only)
   Parameters:
${formattedReceiveParams}

### Security Considerations
This proposal only updates the LayerZero endpoint configuration for the specified OApp.
`
  } else {
    // Cross-chain proposal description
    if (!targetChain || !hubChain) {
      throw new Error('Target chain and hub chain must be provided for cross-chain proposals')
    }

    return `# Cross-Chain LayerZero Configuration Update for ${oAppName}

## Summary
This is a cross-chain governance proposal to update the LayerZero endpoint configuration for the ${oAppName} application on ${targetChain}.

## Motivation
The current delegate address for the OApp does not match the deployer's address, requiring governance to update the configuration.

## Technical Details
- Hub Chain: ${hubChain}
- Target Chain: ${targetChain}
- OApp Address: ${oAppAddress}
- Current Delegate: ${delegate}
- Expected Delegate: ${deployer}
- Send Library: ${sendLibraryAddress}
- Receive Library: ${receiveLibraryAddress}

## Specifications
### Actions
This proposal will execute the following actions on ${targetChain}:
1. Set Send Library Configuration (ULN & Executor)
   Parameters:
${formattedSendParams}

2. Set Receive Library Configuration (ULN only)
   Parameters:
${formattedReceiveParams}

### Cross-chain Mechanism
This proposal uses LayerZero to execute governance actions across chains.

### Security Considerations
This proposal only updates the LayerZero endpoint configuration for the specified OApp.
`
  }
}

/**
 * Generates an aggregated proposal description for multiple OApp configurations
 */
export function generateAggregatedLzConfigProposalDescription(
  configItems: Array<{
    oAppAddress: Address
    oAppName: string
    chainName: string
    sendLibraryAddress: Address
    receiveLibraryAddress: Address
    sendParams: any[]
    receiveParams: any[]
    delegate: Address
  }>,
  deployer: Address,
  isCrossChain: boolean = false,
  newChainName?: string,
  hubChainName?: string,
): string {
  // Format config items for better readability
  const formatConfigItems = () => {
    return configItems
      .map((item, index) => {
        const formatParams = (params: any[]) => {
          return params
            .map((param) => {
              return `      - EID ${param.eid}, ConfigType ${param.configType}, Config: ${param.config}`
            })
            .join('\n')
        }

        return `### Configuration ${index + 1}: ${item.oAppName} on ${item.chainName}
- OApp Address: ${item.oAppAddress}
- Current Delegate: ${item.delegate}
- Send Library: ${item.sendLibraryAddress}
- Receive Library: ${item.receiveLibraryAddress}

**Send Parameters:**
${formatParams(item.sendParams)}

**Receive Parameters:**
${formatParams(item.receiveParams)}
`
      })
      .join('\n\n')
  }

  if (!isCrossChain) {
    return `# Aggregated LayerZero Configuration Update

## Summary
This proposal updates the LayerZero endpoint configuration for multiple OApps across different chains.

## Motivation
The current delegate addresses for these OApps do not match the deployer's address, requiring governance to update the configurations.

## Technical Details
- Deployer Address: ${deployer}
- Number of Configurations: ${configItems.length}

## Configurations
${formatConfigItems()}

## Security Considerations
This proposal only updates the LayerZero endpoint configurations for the specified OApps.
`
  } else {
    // Cross-chain proposal description
    if (!newChainName || !hubChainName) {
      throw new Error('New chain and hub chain must be provided for cross-chain proposals')
    }

    return `# Aggregated Cross-Chain LayerZero Configuration Update for ${newChainName}

## Summary
This is a cross-chain governance proposal to update the LayerZero endpoint configurations for multiple routes between ${newChainName} and existing chains.

## Motivation
This proposal sets up all required LayerZero routes for the new ${newChainName} chain.

## Technical Details
- Hub Chain: ${hubChainName}
- New Chain: ${newChainName}
- Deployer Address: ${deployer}
- Number of Configurations: ${configItems.length}

## Configurations
${formatConfigItems()}

### Cross-chain Mechanism
This proposal uses LayerZero to execute governance actions across chains.

### Security Considerations
This proposal only updates the LayerZero endpoint configurations for the specified OApps.
`
  }
}

/**
 * Creates a governance proposal to update OApp configurations
 */
export async function createLzConfigProposal(
  oAppAddress: Address,
  oAppName: string,
  lzEndpointAddress: Address,
  sendLibraryAddress: Address,
  receiveLibraryAddress: Address,
  sendConfigParams: any[],
  receiveConfigParams: any[],
  useBummerConfig: boolean = false,
  discourseURL: string = '',
) {
  console.log(kleur.cyan('Creating LayerZero configuration proposal...'))

  const [deployer] = await hre.viem.getWalletClients()
  const chainName = hre.network.name
  const { delegate, isAuthorized } = await checkLzAuthorization(
    lzEndpointAddress,
    oAppAddress,
    deployer.account.address,
    chainName,
  )

  if (isAuthorized) {
    console.log(kleur.green('Deployer is authorized. No governance proposal needed.'))
    return
  }

  console.log(kleur.yellow('Not authorized... generating governance proposal'))
  console.log(kleur.blue('Expected delegate:'), kleur.cyan(deployer.account.address))
  console.log(kleur.blue('Actual delegate:'), kleur.cyan(delegate))

  // Get the current chain config

  const config = getConfigByNetwork(chainName, { gov: true }, useBummerConfig)
  const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address

  // Prepare proposal actions
  const targets: Address[] = []
  const values: bigint[] = []
  const calldatas: Hex[] = []

  // Add the send config action
  targets.push(lzEndpointAddress)
  values.push(0n)
  calldatas.push(
    encodeFunctionData({
      abi: LZ_ENDPOINT_ABI,
      functionName: 'setConfig',
      args: [oAppAddress, sendLibraryAddress, sendConfigParams],
    }) as Hex,
  )

  // Add the receive config action
  targets.push(lzEndpointAddress)
  values.push(0n)
  calldatas.push(
    encodeFunctionData({
      abi: LZ_ENDPOINT_ABI,
      functionName: 'setConfig',
      args: [oAppAddress, receiveLibraryAddress, receiveConfigParams],
    }) as Hex,
  )

  // Generate the proposal description
  const title = `LayerZero Configuration Update for ${oAppName} on ${chainName}`
  const description = generateLzConfigProposalDescription(
    oAppAddress,
    oAppName,
    chainName,
    sendLibraryAddress,
    receiveLibraryAddress,
    sendConfigParams,
    receiveConfigParams,
    delegate,
    deployer.account.address as Address,
  )

  // Generate a save path for the proposal JSON
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const savePath = path.join(
    process.cwd(),
    '/proposals',
    `${chainName}_lz_config_proposal_${timestamp}.json`,
  )

  // Create the proposal actions
  const actions = targets.map((target, index) => ({
    target,
    value: values[index],
    calldata: calldatas[index],
  }))

  // Submit the proposal
  await createGovernanceProposal(
    title,
    description,
    actions,
    governorAddress,
    hre.network.config.chainId as number,
    discourseURL,
    [],
    savePath,
  )

  console.log(kleur.green('Governance proposal created successfully.'))
}

/**
 * Creates a cross-chain governance proposal to update OApp configurations
 */
export async function createCrossChainLzConfigProposal(
  oAppAddress: Address,
  oAppName: string,
  lzEndpointAddress: Address,
  sendLibraryAddress: Address,
  receiveLibraryAddress: Address,
  sendConfigParams: any[],
  receiveConfigParams: any[],
  useBummerConfig: boolean = false,
  discourseURL: string = '',
) {
  console.log(kleur.cyan('Creating cross-chain LayerZero configuration proposal...'))

  const [deployer] = await hre.viem.getWalletClients()
  const chainName = hre.network.name
  const { delegate, isAuthorized } = await checkLzAuthorization(
    lzEndpointAddress,
    oAppAddress,
    deployer.account.address,
    chainName,
  )

  if (isAuthorized) {
    console.log(kleur.green('Deployer is authorized. No governance proposal needed.'))
    return
  }

  console.log(kleur.yellow('Not authorized... generating cross-chain governance proposal'))
  console.log(kleur.blue('Expected delegate:'), kleur.cyan(deployer.account.address))
  console.log(kleur.blue('Actual delegate:'), kleur.cyan(delegate))

  // Get the current chain config and hub chain config
  const targetChainName = hre.network.name
  const targetChainConfig = getConfigByNetwork(targetChainName, { gov: true }, useBummerConfig)
  const hubConfig = getConfigByNetwork(HUB_CHAIN_NAME, { gov: true }, useBummerConfig)

  // Set up clients for the hub chain
  console.log(kleur.blue('Connecting to hub chain:'), kleur.cyan(HUB_CHAIN_NAME))
  const result = await getChainConfigByChainId(HUB_CHAIN_ID)
  if (!result) throw new Error(`No chain config found for chain ID ${HUB_CHAIN_ID}`)

  // Get current chain's endpoint ID
  const currentChainEndpointId = targetChainConfig.common.layerZero.eID

  // Prepare the destination (target) proposal actions
  const dstTargets: Address[] = []
  const dstValues: bigint[] = []
  const dstCalldatas: Hex[] = []

  // LZ Endpoint ABI for setConfig
  const lzEndpointAbi = [
    {
      inputs: [
        { name: 'oapp', type: 'address' },
        { name: 'lib', type: 'address' },
        {
          name: 'params',
          type: 'tuple[]',
          components: [
            { name: 'eid', type: 'uint32' },
            { name: 'configType', type: 'uint32' },
            { name: 'config', type: 'bytes' },
          ],
        },
      ],
      name: 'setConfig',
      outputs: [],
      stateMutability: 'nonpayable',
      type: 'function',
    },
  ] as const

  // Add the send config action
  dstTargets.push(lzEndpointAddress)
  dstValues.push(0n)
  dstCalldatas.push(
    encodeFunctionData({
      abi: lzEndpointAbi,
      functionName: 'setConfig',
      args: [oAppAddress, sendLibraryAddress, sendConfigParams],
    }) as Hex,
  )

  // Add the receive config action
  dstTargets.push(lzEndpointAddress)
  dstValues.push(0n)
  dstCalldatas.push(
    encodeFunctionData({
      abi: lzEndpointAbi,
      functionName: 'setConfig',
      args: [oAppAddress, receiveLibraryAddress, receiveConfigParams],
    }) as Hex,
  )

  // Generate the destination proposal description
  const dstDescription = generateLzConfigProposalDescription(
    oAppAddress,
    oAppName,
    targetChainName,
    sendLibraryAddress,
    receiveLibraryAddress,
    sendConfigParams,
    receiveConfigParams,
    delegate,
    deployer.account.address as Address,
  )

  // Generate the source (hub) proposal description
  const srcDescription = generateLzConfigProposalDescription(
    oAppAddress,
    oAppName,
    targetChainName,
    sendLibraryAddress,
    receiveLibraryAddress,
    sendConfigParams,
    receiveConfigParams,
    delegate,
    deployer.account.address as Address,
    true, // isCrossChain
    targetChainName,
    HUB_CHAIN_NAME + (useBummerConfig ? ' (Bummer)' : ' (Production)'),
  )

  // Prepare the source (hub) proposal actions
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address
  console.log(kleur.blue('Using hub governor address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))

  const srcTargets: Address[] = [HUB_GOVERNOR_ADDRESS]
  const srcValues: bigint[] = [0n]

  // Configure LayerZero options
  const ESTIMATED_GAS = 400000n
  const lzOptions = constructLzOptions(ESTIMATED_GAS)

  // Add the cross-chain proposal action
  const srcCalldatas: Hex[] = [
    encodeFunctionData({
      abi: parseAbi([
        'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
      ]),
      args: [
        Number(currentChainEndpointId),
        dstTargets,
        dstValues,
        dstCalldatas,
        hashDescription(dstDescription),
        lzOptions,
      ],
    }) as Hex,
  ]

  // Generate a title for the proposal
  const title = `Cross-Chain LayerZero Configuration Update for ${oAppName} on ${targetChainName}`

  // Generate a save path for the proposal JSON
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const savePath = path.join(
    process.cwd(),
    '/proposals',
    `${targetChainName}_cross_chain_lz_config_proposal_${timestamp}.json`,
  )

  // Create the proposal actions
  const actions = srcTargets.map((target, index) => ({
    target,
    value: srcValues[index],
    calldata: srcCalldatas[index],
  }))

  // Add cross-chain execution details
  const crossChainExecution = {
    hubChain: {
      name: HUB_CHAIN_NAME,
      chainId: HUB_CHAIN_ID,
      governorAddress: HUB_GOVERNOR_ADDRESS,
    },
    targetChain: {
      name: targetChainName,
      chainId: hre.network.config.chainId || 0,
      targets: dstTargets.map((t) => t.toString()),
      values: dstValues.map((v) => v.toString()),
      datas: dstCalldatas.map((c) => c.toString()),
    },
  }

  // Submit the proposal
  await createGovernanceProposal(
    title,
    srcDescription,
    actions,
    HUB_GOVERNOR_ADDRESS,
    HUB_CHAIN_ID,
    discourseURL,
    [],
    savePath,
    crossChainExecution,
  )

  console.log(kleur.green('Cross-chain governance proposal created successfully.'))
}

/**
 * Creates a unified governance proposal containing both hub chain and cross-chain actions
 */
export async function createUnifiedLzConfigProposal(
  hubChainConfigs: Array<{
    sourceChain: string
    targetChain: string
    oAppType: 'summerToken' | 'summerGovernor'
    oAppAddress: Address
    lzEndpointAddress: Address
    sendLibraryAddress: Address
    receiveLibraryAddress: Address
    sendConfigParams: any[]
    receiveConfigParams: any[]
  }>,
  nonHubChainConfigs: Array<{
    sourceChain: string
    targetChain: string
    oAppType: 'summerToken' | 'summerGovernor'
    oAppAddress: Address
    lzEndpointAddress: Address
    sendLibraryAddress: Address
    receiveLibraryAddress: Address
    sendConfigParams: any[]
    receiveConfigParams: any[]
  }>,
  useBummerConfig: boolean = false,
  newChainName: string,
  discourseURL: string = '',
) {
  console.log(kleur.cyan(`Creating unified LayerZero configuration proposal...`))

  const hubChain = getHubChain()

  // Ensure we're on the hub chain
  if (hre.network.name !== hubChain) {
    throw new Error(
      `Must be on hub chain (${hubChain}) to create unified proposal, current network: ${hre.network.name}`,
    )
  }

  const [deployer] = await hre.viem.getWalletClients()
  const hubConfig = getConfigByNetwork(hubChain, { common: true, gov: true }, useBummerConfig)
  const governorAddress = hubConfig.deployedContracts.gov.summerGovernor.address as Address

  // 1. Process hub chain configs - direct actions on hub chain
  const hubTargets: Address[] = []
  const hubValues: bigint[] = []
  const hubCalldatas: Hex[] = []
  const hubConfigItems = []

  for (const config of hubChainConfigs) {
    try {
      // Get current delegate - pass the source chain name
      const { delegate } = await checkLzAuthorization(
        config.lzEndpointAddress,
        config.oAppAddress,
        deployer.account.address,
        config.sourceChain,
      )

      const oAppName = config.oAppType === 'summerToken' ? 'Summer Token' : 'Summer Governor'

      // Add to config items for description
      hubConfigItems.push({
        oAppAddress: config.oAppAddress,
        oAppName,
        chainName: config.targetChain,
        sendLibraryAddress: config.sendLibraryAddress,
        receiveLibraryAddress: config.receiveLibraryAddress,
        sendParams: config.sendConfigParams,
        receiveParams: config.receiveConfigParams,
        delegate,
      })

      // Add to proposal actions
      hubTargets.push(config.lzEndpointAddress)
      hubValues.push(0n)
      hubCalldatas.push(
        encodeFunctionData({
          abi: LZ_ENDPOINT_ABI,
          functionName: 'setConfig',
          args: [config.oAppAddress, config.sendLibraryAddress, config.sendConfigParams],
        }) as Hex,
      )

      hubTargets.push(config.lzEndpointAddress)
      hubValues.push(0n)
      hubCalldatas.push(
        encodeFunctionData({
          abi: LZ_ENDPOINT_ABI,
          functionName: 'setConfig',
          args: [config.oAppAddress, config.receiveLibraryAddress, config.receiveConfigParams],
        }) as Hex,
      )
    } catch (error) {
      console.error(
        kleur.red(
          `Error processing hub config for ${config.sourceChain} -> ${config.targetChain}:`,
        ),
      )
      console.error(error)
    }
  }

  // 2. Group non-hub configs by chain
  const groupedNonHubConfigs: Record<string, typeof nonHubChainConfigs> = {}
  for (const config of nonHubChainConfigs) {
    if (!groupedNonHubConfigs[config.sourceChain]) {
      groupedNonHubConfigs[config.sourceChain] = []
    }
    groupedNonHubConfigs[config.sourceChain].push(config)
  }
  console.log('All target chain configs', groupedNonHubConfigs)

  // 3. Process cross-chain configurations - grouped by target chain
  for (const [targetChain, targetChainConfigs] of Object.entries(groupedNonHubConfigs)) {
    // Create cross-chain configuration for this target chain
    console.log(kleur.blue('Processing target chain:'), kleur.cyan(targetChain))
    const dstTargets: Address[] = []
    const dstValues: bigint[] = []
    const dstCalldatas: Hex[] = []
    const targetConfigItems = []

    // Get target chain config
    const targetChainConfig = getConfigByNetwork(targetChain, { common: true }, useBummerConfig)
    const targetChainEndpointId = targetChainConfig.common.layerZero.eID

    for (const config of targetChainConfigs) {
      try {
        // Get current delegate - pass the source chain name
        const { delegate } = await checkLzAuthorization(
          config.lzEndpointAddress,
          config.oAppAddress,
          deployer.account.address,
          config.sourceChain,
        )

        const oAppName = config.oAppType === 'summerToken' ? 'Summer Token' : 'Summer Governor'

        // Add to config items for description
        targetConfigItems.push({
          oAppAddress: config.oAppAddress,
          oAppName,
          chainName: config.targetChain,
          sendLibraryAddress: config.sendLibraryAddress,
          receiveLibraryAddress: config.receiveLibraryAddress,
          sendParams: config.sendConfigParams,
          receiveParams: config.receiveConfigParams,
          delegate,
        })

        // Add to destination actions
        dstTargets.push(config.lzEndpointAddress)
        dstValues.push(0n)
        dstCalldatas.push(
          encodeFunctionData({
            abi: LZ_ENDPOINT_ABI,
            functionName: 'setConfig',
            args: [config.oAppAddress, config.sendLibraryAddress, config.sendConfigParams],
          }) as Hex,
        )

        dstTargets.push(config.lzEndpointAddress)
        dstValues.push(0n)
        dstCalldatas.push(
          encodeFunctionData({
            abi: LZ_ENDPOINT_ABI,
            functionName: 'setConfig',
            args: [config.oAppAddress, config.receiveLibraryAddress, config.receiveConfigParams],
          }) as Hex,
        )
      } catch (error) {
        console.error(kleur.red(`Error processing cross-chain config for ${targetChain}:`))
        console.error(error)
      }
    }

    console.log(kleur.blue('Destination targets:'))
    console.log(dstTargets)

    if (dstTargets.length > 0) {
      // Generate destination proposal description
      const dstDescription = generateAggregatedLzConfigProposalDescription(
        targetConfigItems,
        deployer.account.address as Address,
        true, // isCrossChain
        newChainName,
        hubChain,
      )

      // Configure LayerZero options
      const ESTIMATED_GAS = 400000n * BigInt(targetConfigItems.length)
      const lzOptions = constructLzOptions(ESTIMATED_GAS)

      console.log('Encoding cross-chain proposal action for ', targetChain)
      // Add the cross-chain proposal action
      hubTargets.push(governorAddress)
      hubValues.push(0n)
      hubCalldatas.push(
        encodeFunctionData({
          abi: parseAbi([
            'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
          ]),
          args: [
            Number(targetChainEndpointId),
            dstTargets,
            dstValues,
            dstCalldatas,
            hashDescription(dstDescription),
            lzOptions,
          ],
        }) as Hex,
      )
    }
  }

  // If no configurations could be processed, exit
  if (hubTargets.length === 0) {
    console.log(kleur.yellow('No valid configurations to include in the proposal.'))
    return
  }

  // Fix the flatMap operation to include all required fields
  const nonHubConfigItems = Object.values(groupedNonHubConfigs).flatMap(async (configs) => {
    const items = []

    for (const config of configs) {
      try {
        // Get current delegate - similar to what we do for hub configs
        const { delegate } = await checkLzAuthorization(
          config.lzEndpointAddress,
          config.oAppAddress,
          deployer.account.address,
          config.sourceChain,
        )

        items.push({
          oAppAddress: config.oAppAddress,
          oAppName: config.oAppType === 'summerToken' ? 'Summer Token' : 'Summer Governor',
          chainName: config.targetChain,
          sendLibraryAddress: config.sendLibraryAddress,
          receiveLibraryAddress: config.receiveLibraryAddress,
          sendParams: config.sendConfigParams,
          receiveParams: config.receiveConfigParams,
          delegate: delegate,
        })
      } catch (error) {
        console.error(kleur.red(`Error processing non-hub config for ${config.sourceChain}:`))
        console.error(error)
      }
    }

    return items
  })

  console.log(await nonHubConfigItems)

  // Combine all config items with proper data
  const allConfigItems = [...hubConfigItems, ...(await nonHubConfigItems)]

  // Determine if this is a cross-chain proposal based on whether we have any non-hub actions
  const containsCrossChainActions = Object.keys(groupedNonHubConfigs).length > 0

  const description = generateAggregatedLzConfigProposalDescription(
    allConfigItems,
    deployer.account.address as Address,
    containsCrossChainActions, // Mark as cross-chain if it contains any cross-chain actions
    newChainName,
    hubChain,
  )

  // Generate a title and save path
  const title = `Aggregated LayerZero Configuration Update for ${newChainName}`
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const savePath = path.join(
    process.cwd(),
    '/proposals',
    `${newChainName}_aggregated_lz_config_proposal_${timestamp}.json`,
  )

  // Create the proposal actions
  const actions = hubTargets.map((target, index) => ({
    target,
    value: hubValues[index],
    calldata: hubCalldatas[index],
  }))

  // Submit the proposal
  await createGovernanceProposal(
    title,
    description,
    actions,
    governorAddress,
    hre.network.config.chainId as number,
    discourseURL,
    [],
    savePath,
  )

  console.log(kleur.green(`Unified governance proposal created successfully on ${hubChain}.`))
}
