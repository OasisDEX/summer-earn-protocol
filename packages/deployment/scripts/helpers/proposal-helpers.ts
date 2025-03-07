import kleur from 'kleur'
import { Address, Hex } from 'viem'
import { FleetContracts } from '../../ignition/modules/fleet'
import { FleetConfig } from '../../types/config-types'
import { createTallyProposal, formatTallyProposalUrl } from './tally-helpers'

interface ProposalAction {
  target: Address
  value: bigint
  calldata: Hex
}

export interface SingleChainContent {
  sourceDescription: string
  sourceTitle: string
}

export interface CrossChainContent extends SingleChainContent {
  destinationDescription: string
}

/**
 * Generates a formatted description for a fleet deployment proposal
 * @returns Either a single description string or an object with source and destination descriptions for cross-chain proposals
 */
export function generateFleetProposalDescription(
  deployedFleet: FleetContracts,
  fleetDefinition: FleetConfig,
  deployedArkAddresses: Address[],
  bufferArkAddress: Address,
  isCrossChain: boolean = false,
  targetChain?: string,
  hubChain?: string,
): SingleChainContent | CrossChainContent {
  const sourceTitle = `SIP2.${fleetDefinition.sipNumber || 'X'}: ${isCrossChain ? 'Cross-chain ' : ''}Fleet Deployment: ${fleetDefinition.fleetName} on ${targetChain}`

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

## Specifications
### Actions
1. Add Fleet to Harbor Command
2. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
3. Add ${deployedArkAddresses.length} Arks to the Fleet
4. Grant COMMANDER_ROLE to Fleet Commander for each Ark

### Fleet Configuration
- Deposit Cap: ${fleetDefinition.depositCap}
- Initial Minimum Buffer Balance: ${fleetDefinition.initialMinimumBufferBalance}
- Initial Rebalance Cooldown: ${fleetDefinition.initialRebalanceCooldown}
- Initial Tip Rate: ${fleetDefinition.initialTipRate}
`

  if (!isCrossChain) {
    return {
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
This cross-chain fleet deployment will expand the protocol's capabilities across multiple networks, enhancing interoperability and user access.

## Technical Details
- Hub Chain: ${hubChain}
- Target Chain: ${targetChain}
- Fleet Commander: ${deployedFleet.fleetCommander.address}
- Buffer Ark: ${bufferArkAddress}
- Number of Arks: ${deployedArkAddresses.length}

## Specifications
### Actions
This proposal will execute the following actions on ${targetChain}:
1. Add Fleet to Harbor Command
2. Grant COMMANDER_ROLE to Fleet Commander for BufferArk
3. Add ${deployedArkAddresses.length} Arks to the Fleet
4. Grant COMMANDER_ROLE to Fleet Commander for each Ark

### Cross-chain Mechanism
This proposal uses LayerZero to execute governance actions across chains.

### Fleet Configuration
- Deposit Cap: ${fleetDefinition.depositCap}
- Initial Minimum Buffer Balance: ${fleetDefinition.initialMinimumBufferBalance}
- Initial Rebalance Cooldown: ${fleetDefinition.initialRebalanceCooldown}
- Initial Tip Rate: ${fleetDefinition.initialTipRate}
`

  return {
    sourceTitle,
    sourceDescription,
    destinationDescription,
  }
}

/**
 * Creates a governance proposal using Tally API
 */
export async function createGovernanceProposal(
  title: string,
  description: string,
  actions: ProposalAction[],
  governorAddress: Address,
  chainId: number,
  actionSummary: string[] = [],
): Promise<string | undefined> {
  try {
    // Log proposal actions
    console.log(kleur.cyan('Creating Tally draft proposal with the following actions:'))
    if (actionSummary.length > 0) {
      actionSummary.forEach((action) => console.log(kleur.yellow(action)))
    }

    // Format governor ID for Tally
    const governorId = `eip155:${chainId}:${governorAddress}`

    // Create executable calls array for Tally
    const executableCalls = actions.map((action) => ({
      target: action.target,
      calldata: action.calldata,
      signature: '',
      value: action.value.toString(),
      type: 'custom',
    }))

    // Submit to Tally API
    const response = await createTallyProposal(governorId, title, description, executableCalls)

    // Get proposal ID and display URL
    const proposalId = response.data.createProposal.id
    console.log(kleur.green(`Tally proposal created successfully! ID: ${proposalId}`))
    const proposalUrl = formatTallyProposalUrl(governorId, proposalId)
    console.log(kleur.blue(`View your proposal at: ${proposalUrl}`))

    return proposalId
  } catch (error: any) {
    console.error(kleur.red('Error creating Tally draft proposal:'), error)
    if (error.response) {
      console.error(kleur.red('Error response:'), error.response.data)
    }
    throw error
  }
}
