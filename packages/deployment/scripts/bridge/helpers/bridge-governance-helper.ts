import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { Address, encodeFunctionData, Hex, parseAbi } from 'viem'
import { getConfigByNetwork } from '../../helpers/config-handler'
import { getHubChain } from '../../helpers/get-hub-chain'
import { getSipMinorNumber } from '../../helpers/get-sip-minor-number'
import { hashDescription } from '../../helpers/hash-description'
import { constructLzOptions } from '../../helpers/layerzero-options'
import { createGovernanceProposal } from '../../helpers/proposal-helpers'
import { LZ_ENDPOINT_ABI } from '../lz-endpoint-abi'
import { checkLzAuthorization } from './lz-authorization-helper'
import { generateAggregatedLzConfigProposalDescription } from './proposal-description-helper'

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
  existingProposal?: {
    title: string
    description: string
    path: string
  },
  fleetDeployments?: Array<{
    name: string
    fleetCommander: Address
    bufferArk: Address
    arks: Address[]
    config?: {
      depositCap?: string
      minimumBufferBalance?: string
      rebalanceCooldown?: string
      tipRate?: string
    }
  }>,
  peerConfigurations?: {
    tokenPeers: Array<{ sourceChain: string; eid: number; address: string }>
    governorPeers: Array<{ sourceChain: string; eid: number; address: string }>
  },
) {
  console.log(kleur.cyan(`Creating unified LayerZero configuration proposal...`))

  // Prompt for SIP minor number
  const sipMinorNumber = await getSipMinorNumber()

  const hubChain = getHubChain()

  const [deployer] = await hre.viem.getWalletClients()
  const hubConfig = getConfigByNetwork(hubChain, { common: true, gov: true }, useBummerConfig)
  const governorAddress = hubConfig.deployedContracts.gov.summerGovernor.address as Address

  // 1. Process hub chain configs - direct actions on hub chain
  const hubTargets: Address[] = []
  const hubValues: bigint[] = []
  const hubCalldatas: Hex[] = []
  const hubConfigItems = []

  // 2. Group non-hub configs by chain
  const groupedNonHubConfigs: Record<string, typeof nonHubChainConfigs> = {}
  for (const config of nonHubChainConfigs) {
    if (!groupedNonHubConfigs[config.sourceChain]) {
      groupedNonHubConfigs[config.sourceChain] = []
    }
    groupedNonHubConfigs[config.sourceChain].push(config)
  }

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

  // Group peer configurations by source chain
  const peersByChain: Record<
    string,
    Array<{
      type: 'token' | 'governor'
      eid: number
      address: string
      contractAddress: Address
    }>
  > = {}

  // Process peer configurations if provided
  if (peerConfigurations) {
    console.log(kleur.cyan(`Processing peer configurations...`))
    console.log(
      kleur.yellow(
        `Adding ${peerConfigurations.tokenPeers.length} token peers and ${peerConfigurations.governorPeers.length} governor peers`,
      ),
    )

    // Create a collection to track which chains and contracts have been processed for the proposal description
    const peeringSummary: Array<{
      sourceChain: string
      sourceContract: string
      targetChain: string
      eid: number
    }> = []

    // Process token peers and group by source chain
    for (const peer of peerConfigurations.tokenPeers) {
      try {
        // Get the source chain config
        const sourceConfig = getConfigByNetwork(peer.sourceChain, { gov: true }, useBummerConfig)
        const tokenAddress = sourceConfig.deployedContracts.gov.summerToken.address as Address

        // Add to chain-specific collection
        if (!peersByChain[peer.sourceChain]) {
          peersByChain[peer.sourceChain] = []
        }

        peersByChain[peer.sourceChain].push({
          type: 'token',
          eid: peer.eid,
          address: peer.address,
          contractAddress: tokenAddress,
        })

        // Track for description
        peeringSummary.push({
          sourceChain: peer.sourceChain,
          sourceContract: 'SummerToken',
          targetChain: newChainName,
          eid: peer.eid,
        })

        console.log(kleur.green(`Added token peer action: ${peer.sourceChain} -> ${newChainName}`))
      } catch (error) {
        console.error(kleur.red(`Error processing token peer for ${peer.sourceChain}:`))
        console.error(error)
      }
    }

    // Process governor peers and group by source chain
    for (const peer of peerConfigurations.governorPeers) {
      try {
        // Get the source chain config
        const sourceConfig = getConfigByNetwork(peer.sourceChain, { gov: true }, useBummerConfig)
        const governorAddress = sourceConfig.deployedContracts.gov.summerGovernor.address as Address

        // Add to chain-specific collection
        if (!peersByChain[peer.sourceChain]) {
          peersByChain[peer.sourceChain] = []
        }

        peersByChain[peer.sourceChain].push({
          type: 'governor',
          eid: peer.eid,
          address: peer.address,
          contractAddress: governorAddress,
        })

        // Track for description
        peeringSummary.push({
          sourceChain: peer.sourceChain,
          sourceContract: 'SummerGovernor',
          targetChain: newChainName,
          eid: peer.eid,
        })

        console.log(
          kleur.green(`Added governor peer action: ${peer.sourceChain} -> ${newChainName}`),
        )
      } catch (error) {
        console.error(kleur.red(`Error processing governor peer for ${peer.sourceChain}:`))
        console.error(error)
      }
    }

    // Now add peering actions to the appropriate chains
    for (const [sourceChain, peers] of Object.entries(peersByChain)) {
      // If this is the hub chain, add directly to hub actions
      if (sourceChain === hubChain) {
        for (const peer of peers) {
          // Format the peer address as bytes32 (padded with zeros)
          const peerAddressAsBytes32 = `0x000000000000000000000000${peer.address.slice(2)}` as Hex

          // Add to hub proposal actions
          hubTargets.push(peer.contractAddress)
          hubValues.push(0n)
          hubCalldatas.push(
            encodeFunctionData({
              abi: parseAbi(['function setPeer(uint32 _eid, bytes32 _peer) external']),
              functionName: 'setPeer',
              args: [peer.eid, peerAddressAsBytes32],
            }) as Hex,
          )
        }
      } else {
        // For non-hub chains, ensure they're in the groupedNonHubConfigs
        // but don't add actions here - we'll handle them in the cross-chain processing section
        if (!groupedNonHubConfigs[sourceChain]) {
          groupedNonHubConfigs[sourceChain] = []
        }
      }
    }

    // Add peering info to description
    if (peeringSummary.length > 0) {
      console.log(kleur.green(`Added ${peeringSummary.length} peering actions to the proposal`))
    }
  }

  // Store cross-chain execution details for the proposal data
  const crossChainExecutions: Array<{
    name: string
    chainId: number
    targets: string[]
    values: string[]
    datas: string[]
  }> = []

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

    // Add peering actions for this chain if they exist
    if (peerConfigurations && peersByChain && peersByChain[targetChain]) {
      console.log(
        kleur.blue(`Adding ${peersByChain[targetChain].length} peering actions for ${targetChain}`),
      )

      for (const peer of peersByChain[targetChain]) {
        // Format the peer address as bytes32 (padded with zeros)
        const peerAddressAsBytes32 = `0x000000000000000000000000${peer.address.slice(2)}` as Hex

        // Add to destination actions for cross-chain execution
        dstTargets.push(peer.contractAddress)
        dstValues.push(0n)
        dstCalldatas.push(
          encodeFunctionData({
            abi: parseAbi(['function setPeer(uint32 _eid, bytes32 _peer) external']),
            functionName: 'setPeer',
            args: [peer.eid, peerAddressAsBytes32],
          }) as Hex,
        )
      }
    }

    console.log(kleur.blue('Destination targets:'))
    console.log(dstTargets)

    if (dstTargets.length > 0) {
      // Add to the cross-chain executions array
      crossChainExecutions.push({
        name: targetChain,
        chainId: Number(targetChainConfig.common.chainId),
        targets: dstTargets.map((t) => t.toString()),
        values: dstValues.map((v) => v.toString()),
        datas: dstCalldatas.map((c) => c.toString()),
      })

      // Generate destination proposal description
      const dstDescription = generateAggregatedLzConfigProposalDescription(
        targetConfigItems,
        deployer.account.address as Address,
        true, // isCrossChain
        newChainName,
        hubChain,
        sipMinorNumber,
        existingProposal,
        fleetDeployments,
        `
### Peering Configuration
This proposal also configures the existing chains to peer with the new ${newChainName} chain:
- Token Peers: ${peerConfigurations?.tokenPeers.length || 0}
- Governor Peers: ${peerConfigurations?.governorPeers.length || 0}

The peering is necessary to enable cross-chain message passing between existing chains and the newly deployed chain.
`,
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
  // This needs to be an async operation that properly awaits all promises
  const nonHubConfigItemsPromises = await Promise.all(
    Object.values(groupedNonHubConfigs).map(async (configs) => {
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
    }),
  )

  // Flatten the array of arrays
  const nonHubConfigItems = nonHubConfigItemsPromises.flat()

  // Combine all config items
  const allConfigItems = [...hubConfigItems, ...nonHubConfigItems]

  // Determine if this is a cross-chain proposal based on whether we have any non-hub actions
  const containsCrossChainActions = Object.keys(groupedNonHubConfigs).length > 0

  const description = generateAggregatedLzConfigProposalDescription(
    allConfigItems,
    deployer.account.address as Address,
    containsCrossChainActions,
    newChainName,
    hubChain,
    sipMinorNumber,
    existingProposal,
    fleetDeployments,
    `
### Peering Configuration
This proposal also configures the existing chains to peer with the new ${newChainName} chain:
- Token Peers: ${peerConfigurations?.tokenPeers.length || 0}
- Governor Peers: ${peerConfigurations?.governorPeers.length || 0}

The peering is necessary to enable cross-chain message passing between existing chains and the newly deployed chain.
`,
  )

  // Generate a title and save path
  const title = `SIP5.${sipMinorNumber}: Aggregated LayerZero Configuration Update for ${newChainName}`
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
    crossChainExecutions,
  )

  console.log(kleur.green(`Unified governance proposal created successfully on ${hubChain}.`))
}
