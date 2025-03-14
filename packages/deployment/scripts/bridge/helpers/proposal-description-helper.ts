import { Address } from 'viem'
import { formatFleetDeployments } from './fleet-deployment-helper'

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
 * following the SIP format from governance rules
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
  sipMinorNumber?: number,
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
  peeringInfo?: string,
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

  // Determine SIP category based on the proposal type, using provided minor number if available
  const sipCategory = sipMinorNumber !== undefined ? `SIP5.${sipMinorNumber}` : 'SIP5'

  // Add fleet deployments section if provided
  let fleetDeploymentsSection = ''
  if (fleetDeployments && fleetDeployments.length > 0) {
    fleetDeploymentsSection = `
## Fleet Deployments on ${newChainName}
This LayerZero configuration will enable cross-chain governance for the following deployed fleets:

${formatFleetDeployments(fleetDeployments)}
`
  }

  if (!isCrossChain) {
    return `# ${sipCategory}: Aggregated LayerZero Configuration Update

## Summary
This proposal updates the LayerZero endpoint configuration for multiple OApps across different chains.

## Motivation
The current delegate addresses for these OApps do not match the deployer's address, requiring governance to update the configurations. This update is essential for proper cross-chain communication in the Lazy Summer Protocol.

## Specifications
### Technical Details
- Deployer Address: ${deployer}
- Number of Configurations: ${configItems.length}

### Configurations
${formatConfigItems()}
${peeringInfo || ''} 

### Actions
This proposal will update the LayerZero endpoint configurations for the specified OApps according to the parameters listed above.

### Security Considerations
- This proposal only updates the LayerZero endpoint configurations for the specified OApps.
- All configurations have been carefully reviewed to ensure they maintain the security of cross-chain communications.
- The changes will be executed through the protocol's governance process with the standard 2-day timelock period.
${fleetDeploymentsSection}
`
  } else {
    // Cross-chain proposal description
    if (!newChainName || !hubChainName) {
      throw new Error('New chain and hub chain must be provided for cross-chain proposals')
    }

    return `# ${sipCategory}: Cross-Chain LayerZero Configuration Update for ${newChainName}

## Summary
This is a cross-chain governance proposal to update the LayerZero endpoint configurations for multiple routes between ${newChainName} and existing chains.

## Motivation
This proposal sets up all required LayerZero routes for the new ${newChainName} chain, enabling secure cross-chain communication for the Lazy Summer Protocol's operations. These configurations are necessary to ensure proper message passing between chains.
${fleetDeploymentsSection}

## Specifications
### Technical Details
- Hub Chain: ${hubChainName}
- New Chain: ${newChainName}
- Deployer Address: ${deployer}
- Number of Configurations: ${configItems.length}

### Configurations
${formatConfigItems()}
${peeringInfo || ''} 

### Cross-chain Mechanism
This proposal uses LayerZero to execute governance actions across chains, following the protocol's established cross-chain governance pattern.

### Implementation
The proposal will be executed from the hub chain, with cross-chain messages sent to configure endpoints on the target chains.

### Security Considerations
- This proposal only updates the LayerZero endpoint configurations for the specified OApps.
- All configurations have been carefully reviewed to ensure they maintain the security of cross-chain communications.
- The proposal includes appropriate gas parameters to ensure successful execution on all target chains.
- The changes will be executed through the protocol's governance process with the standard 2-day timelock period.
`
  }
}
