import hre from 'hardhat'
import kleur from 'kleur'
import { Address, encodeFunctionData, Hex, parseAbi } from 'viem'
import { FleetContracts } from '../../ignition/modules/fleet'
import { BaseConfig, FleetConfig } from '../../types/config-types'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { createGovernanceProposal, ProposalContent } from '../helpers/proposal-helpers'
import { createTallyProposal, formatTallyProposalUrl } from '../helpers/tally-helpers'

export interface FleetSingleChainContent extends ProposalContent {
  sourceDescription: string
  sourceTitle: string
}

export interface FleetCrossChainContent extends FleetSingleChainContent {
  destinationDescription: string
}

/**
 * Generates a formatted description for a fleet deployment proposal
 */
export function generateFleetProposalDescription(
  deployedFleet: FleetContracts,
  fleetDefinition: FleetConfig,
  deployedArkAddresses: Address[],
  bufferArkAddress: Address,
  isCrossChain: boolean = false,
  targetChain?: string,
  hubChain?: string,
  curatorAddress?: Address,
  rewardInfo?: { tokens?: string[]; amounts?: string[]; duration?: string },
): FleetSingleChainContent | FleetCrossChainContent {
  const sourceTitle = `SIP2.${fleetDefinition.sipNumber || 'X'}: ${isCrossChain ? 'Cross-chain ' : ''}Fleet Deployment: ${fleetDefinition.fleetName} on ${targetChain}`

  // Create curator section if curator is provided
  const curatorSection = curatorAddress ? `- Curator: ${curatorAddress}` : ''

  // Create rewards section if rewards info is provided
  const rewardsSection =
    rewardInfo && rewardInfo.tokens && rewardInfo.amounts && rewardInfo.duration
      ? `
### Rewards Configuration
- Reward Tokens: ${rewardInfo.tokens.join(', ')}
- Reward Amounts: ${rewardInfo.amounts.join(', ')}
- Rewards Duration: ${rewardInfo.duration}`
      : ''

  // Standard description for the destination chain (or single-chain proposal)
  const standardDescription = `# SIP2.${fleetDefinition.sipNumber || 'X'}: Fleet Deployment: ${fleetDefinition.fleetName}

## Summary
This proposal activates the ${fleetDefinition.fleetName} Fleet (${fleetDefinition.symbol}).

## Motivation
This fleet deployment will expand the protocol's capabilities by adding ${deployedArkAddresses.length} new Arks to the ecosystem.

## Technical Details
- Fleet Commander: ${deployedFleet.fleetCommander.address}
- Buffer Ark: ${bufferArkAddress}
- Number of Arks: ${deployedArkAddresses.length}
${curatorSection}

## Specifications
### Actions
1. Add Fleet to Harbor Command
2. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
3. Add ${deployedArkAddresses.length} Arks to the Fleet
4. Grant COMMANDER_ROLE to Fleet Commander for each Ark
${curatorAddress ? '5. Grant CURATOR_ROLE to Curator for the Fleet' : ''}

### Fleet Configuration
- Deposit Cap: ${fleetDefinition.depositCap}
- Initial Minimum Buffer Balance: ${fleetDefinition.initialMinimumBufferBalance}
- Initial Rebalance Cooldown: ${fleetDefinition.initialRebalanceCooldown}
- Initial Tip Rate: ${fleetDefinition.initialTipRate}
${rewardsSection}
`

  if (!isCrossChain) {
    return {
      title: sourceTitle,
      description: standardDescription,
      sourceTitle,
      sourceDescription: standardDescription,
    }
  }

  if (!targetChain || !hubChain) {
    throw new Error('Target chain and hub chain must be provided for cross-chain proposals')
  }

  // Destination chain description (what will be executed on the target chain)
  const destinationDescription = standardDescription

  // Source chain description (what will be shown on the hub chain)
  const sourceDescription = `# SIP2.${fleetDefinition.sipNumber || 'X'}: Cross-chain Fleet Deployment Proposal

## Summary
This is a cross-chain governance proposal to activate the ${fleetDefinition.fleetName} Fleet on ${targetChain}.

## Motivation
This cross-chain fleet deployment will expand the protocol's capabilities across multiple networks.

## Technical Details
- Hub Chain: ${hubChain}
- Target Chain: ${targetChain}
- Fleet Commander: ${deployedFleet.fleetCommander.address}
- Buffer Ark: ${bufferArkAddress}
- Number of Arks: ${deployedArkAddresses.length}
${curatorSection}

## Specifications
### Actions
This proposal will execute the following actions on ${targetChain}:
1. Add Fleet to Harbor Command
2. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
3. Add ${deployedArkAddresses.length} Arks to the Fleet
4. Grant COMMANDER_ROLE to Fleet Commander for each Ark
${curatorAddress ? '5. Grant CURATOR_ROLE to Curator for the Fleet' : ''}

### Cross-chain Mechanism
This proposal uses LayerZero to execute governance actions across chains.

### Fleet Configuration
- Deposit Cap: ${fleetDefinition.depositCap}
- Initial Minimum Buffer Balance: ${fleetDefinition.initialMinimumBufferBalance}
- Initial Rebalance Cooldown: ${fleetDefinition.initialRebalanceCooldown}
- Initial Tip Rate: ${fleetDefinition.initialTipRate}
${rewardsSection}
`

  return {
    title: sourceTitle,
    description: sourceDescription,
    sourceTitle,
    sourceDescription,
    destinationDescription,
  }
}

/**
 * Prepares proposal actions for adding arks to a fleet
 * This is a common function used by multiple proposal types
 */
export function prepareArkAdditionActions(
  fleetCommanderAddress: Address,
  arkAddresses: Address[],
  protocolAccessManagerAddress: Address,
): { targets: Address[]; values: bigint[]; calldatas: Hex[] } {
  const targets: Address[] = []
  const values: bigint[] = []
  const calldatas: Hex[] = []

  // Grant COMMANDER_ROLE to Fleet Commander for each Ark
  for (const arkAddress of arkAddresses) {
    targets.push(protocolAccessManagerAddress)
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function grantCommanderRole(address arkAddress, address account) external',
        ]),
        args: [arkAddress, fleetCommanderAddress],
      }) as Hex,
    )
  }

  // Add each Ark to the Fleet Commander
  for (const arkAddress of arkAddresses) {
    targets.push(fleetCommanderAddress)
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: parseAbi(['function addArk(address ark) external']),
        args: [arkAddress],
      }) as Hex,
    )
  }

  return { targets, values, calldatas }
}

/**
 * Prepares proposal actions for adding a fleet to Harbor Command
 */
export function prepareHarborAdditionActions(
  fleetCommanderAddress: Address,
  harborCommandAddress: Address,
): { targets: Address[]; values: bigint[]; calldatas: Hex[] } {
  const targets: Address[] = [harborCommandAddress]
  const values: bigint[] = [0n]
  const calldatas: Hex[] = [
    encodeFunctionData({
      abi: parseAbi(['function enlistFleetCommander(address fleetCommander) external']),
      args: [fleetCommanderAddress],
    }) as Hex,
  ]

  return { targets, values, calldatas }
}

/**
 * Prepares proposal actions for granting commander role for BufferArk
 */
export function prepareBufferArkActions(
  bufferArkAddress: Address,
  fleetCommanderAddress: Address,
  protocolAccessManagerAddress: Address,
): { targets: Address[]; values: bigint[]; calldatas: Hex[] } {
  const targets: Address[] = [protocolAccessManagerAddress]
  const values: bigint[] = [0n]
  const calldatas: Hex[] = [
    encodeFunctionData({
      abi: parseAbi(['function grantCommanderRole(address arkAddress, address account) external']),
      args: [bufferArkAddress, fleetCommanderAddress],
    }) as Hex,
  ]

  return { targets, values, calldatas }
}

/**
 * Prepares proposal actions for granting curator role
 */
export function prepareCuratorActions(
  fleetCommanderAddress: Address,
  curatorAddress: Address,
  protocolAccessManagerAddress: Address,
): { targets: Address[]; values: bigint[]; calldatas: Hex[] } {
  const targets: Address[] = [protocolAccessManagerAddress]
  const values: bigint[] = [0n]
  const calldatas: Hex[] = [
    encodeFunctionData({
      abi: parseAbi(['function grantCuratorRole(address fleetAddress, address account) external']),
      args: [fleetCommanderAddress, curatorAddress],
    }) as Hex,
  ]

  return { targets, values, calldatas }
}

/**
 * Submits a proposal to Tally or logs manual submission details on failure
 */
export async function submitProposal(
  governorId: string,
  title: string,
  description: string,
  targets: Address[],
  values: bigint[],
  calldatas: Hex[],
  discourseURL: string = '',
  actionSummary: string[] = [],
): Promise<void> {
  // Extract chainId and governorAddress from governorId
  // Format is "eip155:${chainId}:${governorAddress}"
  const parts = governorId.split(':')
  if (parts.length !== 3) {
    throw new Error(`Invalid governorId format: ${governorId}`)
  }

  const chainId = parseInt(parts[1])
  const governorAddress = parts[2] as Address

  // Convert targets, values, and calldatas into ProposalAction array
  const actions = targets.map((target, index) => ({
    target,
    value: values[index],
    calldata: calldatas[index],
  }))

  try {
    // Use the generic createGovernanceProposal function
    await createGovernanceProposal(
      title,
      description,
      actions,
      governorAddress,
      chainId,
      discourseURL,
      actionSummary,
    )
  } catch (error) {
    // The createGovernanceProposal function already handles error logging
    // and manual submission details, so we can just re-throw
    throw error
  }
}

/**
 * Creates a governance proposal that only adds arks to an existing fleet
 */
export async function createArkAdditionProposal(
  fleetCommanderAddress: Address,
  arkAddresses: Address[],
  config: BaseConfig,
  fleetDefinition: FleetConfig,
  useBummerConfig: boolean,
): Promise<void> {
  console.log(kleur.cyan('Creating governance proposal to add arks to existing fleet'))

  // Use the correct governor address from the config
  const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address
  const protocolAccessManagerAddress = config.deployedContracts.gov.protocolAccessManager
    .address as Address

  // Get the actions for adding arks
  const { targets, values, calldatas } = prepareArkAdditionActions(
    fleetCommanderAddress,
    arkAddresses,
    protocolAccessManagerAddress,
  )

  // Create simplified proposal title and description
  const title = `Add ${arkAddresses.length} Ark(s) to ${fleetDefinition.fleetName} Fleet`
  const description = `# Add Arks to ${fleetDefinition.fleetName} Fleet

## Summary
This proposal adds ${arkAddresses.length} new Ark(s) to the existing ${fleetDefinition.fleetName} Fleet.

## Actions
1. Grant COMMANDER_ROLE to Fleet Commander for each Ark
2. Add each Ark to the Fleet Commander

## References
${fleetDefinition.discourseURL ? `Discourse: ${fleetDefinition.discourseURL}` : ''}
`

  // Generate proposal details
  const governorId = `eip155:${HUB_CHAIN_ID}:${governorAddress}`

  // Get the discourse URL from the fleet definition if available
  const discourseURL = fleetDefinition.discourseURL || ''
  if (discourseURL) {
    console.log(kleur.blue('Using Discourse URL:'), kleur.cyan(discourseURL))
  }

  // Submit proposal
  await submitProposal(governorId, title, description, targets, values, calldatas, discourseURL)
}

/**
 * Creates a governance proposal on the hub chain and optionally submits a draft to Tally
 */
export async function createHubGovernanceProposal(
  deployedFleet: FleetContracts,
  bufferArkAddress: Address,
  deployedArkAddresses: Address[],
  config: BaseConfig,
  fleetDefinition: FleetConfig,
  useBummerConfig: boolean,
  curatorAddress?: Address,
) {
  // Use the correct governor address from the config
  const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address
  const harborCommandAddress = config.deployedContracts.core.harborCommand.address as Address
  const protocolAccessManagerAddress = config.deployedContracts.gov.protocolAccessManager
    .address as Address

  // Prepare the proposal targets, values, and calldatas
  let targets: Address[] = []
  let values: bigint[] = []
  let calldatas: Hex[] = []

  // 1. Add Fleet to Harbor Command
  const harborActions = prepareHarborAdditionActions(
    deployedFleet.fleetCommander.address,
    harborCommandAddress,
  )
  targets = [...targets, ...harborActions.targets]
  values = [...values, ...harborActions.values]
  calldatas = [...calldatas, ...harborActions.calldatas]

  // 2. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
  const bufferArkActions = prepareBufferArkActions(
    bufferArkAddress,
    deployedFleet.fleetCommander.address,
    protocolAccessManagerAddress,
  )
  targets = [...targets, ...bufferArkActions.targets]
  values = [...values, ...bufferArkActions.values]
  calldatas = [...calldatas, ...bufferArkActions.calldatas]

  // 3. Add Arks and grant COMMANDER_ROLE
  const arkActions = prepareArkAdditionActions(
    deployedFleet.fleetCommander.address,
    deployedArkAddresses,
    protocolAccessManagerAddress,
  )
  targets = [...targets, ...arkActions.targets]
  values = [...values, ...arkActions.values]
  calldatas = [...calldatas, ...arkActions.calldatas]

  // 4. Grant CURATOR_ROLE if provided
  if (curatorAddress) {
    const curatorActions = prepareCuratorActions(
      deployedFleet.fleetCommander.address,
      curatorAddress,
      protocolAccessManagerAddress,
    )
    targets = [...targets, ...curatorActions.targets]
    values = [...values, ...curatorActions.values]
    calldatas = [...calldatas, ...curatorActions.calldatas]
  }

  // Replace the try/catch block with common submission logic
  try {
    console.log(kleur.cyan('Creating Tally draft proposal with the following actions:'))
    console.log(kleur.yellow('- Add Fleet to Harbor Command'))
    console.log(kleur.yellow('- Grant COMMANDER_ROLE to Fleet Commander for BufferArk'))
    console.log(kleur.yellow(`- Add ${deployedArkAddresses.length} Arks to the Fleet`))
    if (curatorAddress) {
      console.log(kleur.yellow(`- Grant CURATOR_ROLE to ${curatorAddress} for the fleet`))
    }

    const proposalContent = generateFleetProposalDescription(
      deployedFleet,
      fleetDefinition,
      deployedArkAddresses,
      bufferArkAddress,
      false, // isCrossChain
      HUB_CHAIN_NAME, // targetChain (will be overridden)
      HUB_CHAIN_NAME + (useBummerConfig ? ' (Bummer)' : ' (Production)'), // hubChain
      curatorAddress, // Add curator address
      fleetDefinition.rewardTokens
        ? {
            // Add reward info if available
            tokens: fleetDefinition.rewardTokens,
            amounts: fleetDefinition.rewardAmounts,
            duration: fleetDefinition.rewardsDuration?.toString(),
          }
        : undefined,
    )

    // Generate proposal details
    const governorId = `eip155:${HUB_CHAIN_ID}:${governorAddress}`
    const title = proposalContent.sourceTitle
    const description = proposalContent.sourceDescription

    // Get the discourse URL from the fleet definition if available
    const discourseURL = fleetDefinition.discourseURL || ''

    // Submit the proposal
    await submitProposal(governorId, title, description, targets, values, calldatas, discourseURL)

    console.log(kleur.yellow('The fleet will be activated once this proposal is executed.'))
  } catch (error: any) {
    console.error(kleur.red('Error creating proposal:'), error)
  }
}

/**
 * Creates a cross-chain governance proposal from the hub chain to a satellite chain
 */
export async function createSatelliteGovernanceProposal(
  deployedFleet: FleetContracts,
  bufferArkAddress: Address,
  deployedArkAddresses: Address[],
  config: BaseConfig,
  fleetDefinition: FleetConfig,
  useBummerConfig: boolean,
  isTenderlyVirtualTestnet: boolean,
  curatorAddress?: Address,
) {
  console.log(kleur.yellow('Creating cross-chain governance proposal...'))

  if (!isTenderlyVirtualTestnet && useBummerConfig) {
    throw new Error('Bummer config is only available on Tenderly virtual testnets.')
  }

  const hubConfigForGovernance = getConfigByNetwork(HUB_CHAIN_NAME, { gov: true }, useBummerConfig)
  const hubConfigForCore = getConfigByNetwork(HUB_CHAIN_NAME, { core: true })

  // Combine the two configs
  const hubConfig = {
    ...hubConfigForGovernance,
    ...hubConfigForCore,
  }

  // 2. Set up clients for the hub chain
  console.log(kleur.blue('Connecting to hub chain:'), kleur.cyan(HUB_CHAIN_NAME))
  console.log(
    kleur.blue('Using config:'),
    useBummerConfig ? kleur.cyan('Bummer/Test') : kleur.cyan('Production'),
  )

  // Get current chain's endpoint ID
  const currentChainEndpointId = config.common.layerZero.eID

  // 3. Prepare the destination (satellite) proposal
  const dstTargets: Address[] = []
  const dstValues: bigint[] = []
  const dstCalldatas: Hex[] = []

  // 3.1 Add Fleet to Harbor Command
  const harborCommandAddress = config.deployedContracts.core.harborCommand.address as Address
  dstTargets.push(harborCommandAddress)
  dstValues.push(0n)
  dstCalldatas.push(
    encodeFunctionData({
      abi: parseAbi(['function enlistFleetCommander(address fleetCommander) external']),
      args: [deployedFleet.fleetCommander.address],
    }) as Hex,
  )

  // 3.2 Grant COMMANDER_ROLE to Fleet Commander for BufferArk
  const protocolAccessManagerAddress = config.deployedContracts.gov.protocolAccessManager
    .address as Address

  dstTargets.push(protocolAccessManagerAddress)
  dstValues.push(0n)
  dstCalldatas.push(
    encodeFunctionData({
      abi: parseAbi(['function grantCommanderRole(address arkAddress, address account) external']),
      args: [bufferArkAddress, deployedFleet.fleetCommander.address],
    }) as Hex,
  )

  // 3.3 Add each Ark to the Fleet Commander
  for (const arkAddress of deployedArkAddresses) {
    dstTargets.push(deployedFleet.fleetCommander.address)
    dstValues.push(0n)
    dstCalldatas.push(
      encodeFunctionData({
        abi: parseAbi(['function addArk(address ark) external']),
        args: [arkAddress],
      }) as Hex,
    )
  }

  // 3.4 Grant COMMANDER_ROLE to Fleet Commander for each Ark
  for (const arkAddress of deployedArkAddresses) {
    dstTargets.push(protocolAccessManagerAddress)
    dstValues.push(0n)
    dstCalldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function grantCommanderRole(address arkAddress, address account) external',
        ]),
        args: [arkAddress, deployedFleet.fleetCommander.address],
      }) as Hex,
    )
  }

  // 3.5 Grant CURATOR_ROLE to the curator for the fleet if provided
  if (curatorAddress) {
    dstTargets.push(protocolAccessManagerAddress)
    dstValues.push(0n)
    dstCalldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function grantCuratorRole(address fleetAddress, address account) external',
        ]),
        args: [deployedFleet.fleetCommander.address, curatorAddress],
      }) as Hex,
    )
  }

  const proposalDescriptions = generateFleetProposalDescription(
    deployedFleet,
    fleetDefinition,
    deployedArkAddresses,
    bufferArkAddress,
    true, // isCrossChain
    hre.network.name, // targetChain
    HUB_CHAIN_NAME + (useBummerConfig ? ' (Bummer)' : ' (Production)'), // hubChain
    curatorAddress, // Add curator address
    fleetDefinition.rewardTokens
      ? {
          // Add reward info if available
          tokens: fleetDefinition.rewardTokens,
          amounts: fleetDefinition.rewardAmounts,
          duration: fleetDefinition.rewardsDuration?.toString(),
        }
      : undefined,
  ) as FleetCrossChainContent

  const dstDescription = proposalDescriptions.destinationDescription
  const srcDescription = proposalDescriptions.sourceDescription
  const title = proposalDescriptions.sourceTitle

  // 4. Prepare the source (hub) proposal
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.gov.summerGovernor.address as Address
  console.log(kleur.blue('Using hub governor address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))

  const srcTargets = [HUB_GOVERNOR_ADDRESS]
  const srcValues = [0n]
  const ESTIMATED_GAS = 400000n
  const lzOptions = constructLzOptions(ESTIMATED_GAS)

  const srcCalldatas = [
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

  // 5. Create Tally draft proposal
  try {
    console.log(kleur.cyan('Creating cross-chain governance proposal with the following actions:'))
    console.log(kleur.yellow('- Add Fleet to Harbor Command'))
    console.log(kleur.yellow('- Grant COMMANDER_ROLE to Fleet Commander for BufferArk'))
    console.log(kleur.yellow(`- Add ${deployedArkAddresses.length} Arks to the Fleet`))
    if (curatorAddress) {
      console.log(kleur.yellow(`- Grant CURATOR_ROLE to ${curatorAddress} for the fleet`))
    }

    console.log(kleur.blue('Hub governor address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))

    // Generate proposal details
    const governorId = `eip155:${HUB_CHAIN_ID}:${HUB_GOVERNOR_ADDRESS}`

    // Create executable calls array for Tally
    const executableCalls = srcTargets.map((target, index) => ({
      target,
      calldata: srcCalldatas[index],
      signature: '',
      value: srcValues[index].toString(),
      type: 'custom',
    }))

    // Get the discourse URL from the fleet definition if available
    const discourseURL = fleetDefinition.discourseURL || ''
    if (discourseURL) {
      console.log(kleur.blue('Using Discourse URL:'), kleur.cyan(discourseURL))
    }

    // Submit to Tally API with discourse URL
    try {
      const response = await createTallyProposal(
        governorId,
        title,
        srcDescription,
        executableCalls,
        discourseURL,
      )

      // Get proposal ID and display URL
      const proposalId = response.data.createProposal.id
      console.log(kleur.green(`Tally proposal created successfully! ID: ${proposalId}`))
      const proposalUrl = formatTallyProposalUrl(governorId, proposalId)
      console.log(kleur.blue(`View your proposal at: ${proposalUrl}`))
      console.log(kleur.yellow('The fleet will be activated once this proposal is executed.'))
    } catch (error: any) {
      console.error(kleur.red('Error creating Tally draft proposal:'), error)
      if (error.response) {
        console.error(kleur.red('Error response:'), error.response.data)
      }

      // Fall back to showing manual submission details
      console.log(kleur.yellow('\nProposal details for manual submission:'))
      console.log(kleur.blue('Governor Address:'), kleur.cyan(HUB_GOVERNOR_ADDRESS))
      console.log(kleur.blue('Targets:'), kleur.cyan(JSON.stringify(srcTargets)))
      console.log(kleur.blue('Values:'), kleur.cyan(srcValues.toString()))
      console.log(kleur.blue('Calldatas:'))
      srcCalldatas.forEach((data) => {
        console.log(kleur.cyan(data))
      })
      console.log(kleur.blue('Description:'), kleur.cyan(srcDescription))
      console.log(kleur.yellow('The cross-chain proposal needs to be submitted on the hub chain.'))
    }
  } catch (error: any) {
    console.error(kleur.red('Error preparing cross-chain proposal:'), error)
  }
}
