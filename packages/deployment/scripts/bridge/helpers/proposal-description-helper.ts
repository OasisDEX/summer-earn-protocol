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
- Send Library: ${item.sendLibraryAddress}
- Receive Library: ${item.receiveLibraryAddress}

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

    // Format fleet details in a more human-readable way
    let formattedFleetDeployments = ''
    if (fleetDeploymentsSection) {
      const fleetSection = fleetDeploymentsSection.replace(
        /Deposit Cap: (\d+)/g,
        (match, cap) => `Deposit Cap: ${formatValue(cap)}`,
      )
      const bufferSection = fleetSection.replace(
        /Minimum Buffer Balance: (\d+)/g,
        (match, buffer) => `Minimum Buffer Balance: ${formatValue(buffer, 6)}`,
      )
      const cooldownSection = bufferSection.replace(
        /Rebalance Cooldown: (\d+)/g,
        (match, cooldown) => `Rebalance Cooldown: ${formatValue(cooldown, 0, 'time')}`,
      )
      formattedFleetDeployments = cooldownSection.replace(/Tip Rate: (\d+)/g, (match, rate) => {
        const tipRateNumber = BigInt(rate)
        const tipRatePercentage = tipRateNumber / 100n
        return `Tip Rate: ${formatValue(tipRatePercentage.toString(), 18, 'percentage')}`
      })
    }

    return `# ${sipCategory}: Cross-Chain LayerZero Configuration Update for ${newChainName}

## Summary
This proposal configures LayerZero endpoints to enable secure cross-chain communication between ${newChainName} and existing chains in the Lazy Summer Protocol.

## Motivation
Setting up these LayerZero routes is necessary to enable protocol governance and operations across chains, allowing for seamless token transfers and cross-chain governance actions.
${formattedFleetDeployments}

## Specifications
### Technical Details
- Hub Chain: ${hubChainName}
- New Chain: ${newChainName}
- Deployer Address: ${deployer}
- Number of Configurations: ${configItems.length}

### Why These Configurations Matter
These LayerZero configurations establish the security parameters and message routing infrastructure that enable secure omnichain operations by:
1. Setting up trusted message libraries for cross-chain communication
2. Configuring Decentralized Verifier Networks (DVNs) for message integrity
3. Establishing appropriate gas parameters for message delivery

### DVN Configuration
Each OApp will use LayerZero Labs DVN and Stargate DVN for cross-chain message verification. [Learn more about LayerZero Security](https://docs.layerzero.network/v2/concepts/modular-security/security-stack-dvns).

### Configuration Summary
${formatConfigItems()}
${
  peeringInfo
    ? `
### Peering Configuration
${peeringInfo}`
    : ''
} 

### Security Considerations
- These configurations maintain the security of cross-chain communications
- All parameters have been carefully reviewed and tested
- Changes will execute through governance with the standard timelock period
`
  }
}

// Helper function to format values in a human-readable way
function formatValue(
  value: string,
  decimals: number = 18,
  type: 'token' | 'percentage' | 'time' = 'token',
): string {
  try {
    if (type === 'time') {
      // Handle time-based values (seconds)
      const seconds = parseInt(value)
      if (seconds < 60) {
        return `${seconds} seconds`
      } else if (seconds < 3600) {
        const minutes = Math.floor(seconds / 60)
        return `${minutes} minute${minutes > 1 ? 's' : ''} (${seconds} seconds)`
      } else {
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        return `${hours} hour${hours > 1 ? 's' : ''}${minutes > 0 ? ` ${minutes} minute${minutes > 1 ? 's' : ''}` : ''} (${seconds} seconds)`
      }
    }

    const amount = BigInt(value)

    if (type === 'percentage') {
      // Handle percentage values
      const percentage = (Number(amount) / 10 ** decimals) * 100
      return `${percentage}% (${value} raw)`
    }

    // Default: handle token amounts
    const divisor = BigInt(10 ** Math.min(decimals, 18))
    const readableAmount = Number(amount / divisor) / (decimals > 18 ? 10 ** (decimals - 18) : 1)
    return `${readableAmount.toLocaleString()} (${value} raw)`
  } catch (error) {
    return value // Return original if parsing fails
  }
}
