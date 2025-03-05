import kleur from 'kleur'
import { Address, encodeFunctionData, Hex, parseAbi } from 'viem'
import { FleetContracts } from '../../ignition/modules/fleet'
import { BaseConfig, FleetConfig } from '../../types/config-types'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import {
  CrossChainContent,
  generateFleetProposalDescription,
  SingleChainContent,
} from '../helpers/proposal-helpers'
import { createTallyProposal, formatTallyProposalUrl } from '../helpers/tally-helpers'

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
  const targets: Address[] = []
  const values: bigint[] = []
  const calldatas: Hex[] = []

  // 1. Add Fleet to Harbor Command
  targets.push(harborCommandAddress)
  values.push(0n)
  calldatas.push(
    encodeFunctionData({
      abi: parseAbi(['function enlistFleetCommander(address fleetCommander) external']),
      args: [deployedFleet.fleetCommander.address],
    }) as Hex,
  )

  // 2. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
  targets.push(protocolAccessManagerAddress)
  values.push(0n)
  calldatas.push(
    encodeFunctionData({
      abi: parseAbi(['function grantCommanderRole(address arkAddress, address account) external']),
      args: [bufferArkAddress, deployedFleet.fleetCommander.address],
    }) as Hex,
  )

  // 2.1 Grant COMMANDER_ROLE to Fleet Commander for each Ark
  for (const arkAddress of deployedArkAddresses) {
    targets.push(protocolAccessManagerAddress)
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function grantCommanderRole(address arkAddress, address account) external',
        ]),
        args: [arkAddress, deployedFleet.fleetCommander.address],
      }) as Hex,
    )
  }

  // 3. Add each Ark to the Fleet Commander
  for (const arkAddress of deployedArkAddresses) {
    targets.push(deployedFleet.fleetCommander.address)
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: parseAbi(['function addArk(address ark) external']),
        args: [arkAddress],
      }) as Hex,
    )
  }

  // 3.4 Grant COMMANDER_ROLE to Fleet Commander for each Ark
  for (const arkAddress of deployedArkAddresses) {
    targets.push(protocolAccessManagerAddress)
    values.push(0n)
    calldatas.push(
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
    targets.push(protocolAccessManagerAddress)
    values.push(0n)
    calldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function grantCuratorRole(address fleetAddress, address account) external',
        ]),
        args: [deployedFleet.fleetCommander.address, curatorAddress],
      }) as Hex,
    )
  }

  // Replace the try/catch block for proposal submission with Tally API usage
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
      'mainnet', // targetChain (will be overridden)
      'mainnet' + (useBummerConfig ? ' (Bummer)' : ' (Production)'), // hubChain
    ) as SingleChainContent

    // Generate proposal details - use the correct chain ID based on whether we're using bummer config
    const chainId = config.common.chainId
    const governorId = `eip155:${chainId}:${governorAddress}`
    const title = proposalContent.sourceTitle

    // Create executable calls array for Tally
    const executableCalls = targets.map((target, index) => ({
      target,
      calldata: calldatas[index],
      signature: '',
      value: values[index].toString(),
      type: 'custom',
    }))

    // Get the discourse URL from the fleet definition if available
    const discourseURL = fleetDefinition.discourseURL || ''
    if (discourseURL) {
      console.log(kleur.blue('Using Discourse URL:'), kleur.cyan(discourseURL))
    }

    // Submit to Tally API with discourse URL
    const response = await createTallyProposal(
      governorId,
      title,
      proposalContent.sourceDescription,
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

  const hubConfigForGovernance = await import('../helpers/config-handler').then((module) =>
    module.getConfigByNetwork('mainnet', { gov: true }, useBummerConfig),
  )

  const hubConfigForCore = await import('../helpers/config-handler').then((module) =>
    module.getConfigByNetwork('mainnet', { core: true }),
  )

  // Combine the two configs
  const hubConfig = {
    ...hubConfigForGovernance,
    ...hubConfigForCore,
  }

  // 2. Set up clients for the hub chain
  console.log(kleur.blue('Connecting to hub chain:'), kleur.cyan('mainnet'))
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
    config.common.name, // targetChain
    'mainnet' + (useBummerConfig ? ' (Bummer)' : ' (Production)'), // hubChain
  ) as CrossChainContent

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

    // Generate proposal details - use the correct chain ID based on whether we're using bummer config
    const HUB_CHAIN_ID = hubConfig.common.chainId
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
