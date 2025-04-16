import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import { Address } from 'viem'

/**
 * Gets fleet deployment information from the deployments directory
 * @param chainName The name of the chain to get fleet information for
 * @returns Information about deployed fleets on the chain
 */
export async function getFleetDeploymentInfo(chainName: string): Promise<
  Array<{
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
  }>
> {
  console.log(kleur.blue('Looking for fleet deployments on'), kleur.cyan(chainName))

  // The deployments directory should be in the project root
  const deploymentsDir = path.join(process.cwd(), 'deployments', chainName)

  if (!fs.existsSync(deploymentsDir)) {
    console.log(kleur.yellow(`No deployments directory found for ${chainName}`))
    return []
  }

  try {
    // Look for fleet commander deployments in the directory
    const deploymentFiles = fs.readdirSync(deploymentsDir)

    // Find files that might be fleet commanders
    const fleetCommanderFiles = deploymentFiles.filter(
      (file) => file.includes('FleetCommander') && file.endsWith('.json'),
    )

    if (fleetCommanderFiles.length === 0) {
      console.log(kleur.yellow(`No fleet deployments found for ${chainName}`))
      return []
    }

    const fleets = []

    for (const fcFile of fleetCommanderFiles) {
      try {
        // Read the fleet commander deployment
        const fcPath = path.join(deploymentsDir, fcFile)
        const fcDeployment = JSON.parse(fs.readFileSync(fcPath, 'utf8'))

        // Get the fleet name from the contract (parsing the name from the file)
        const fleetName = fcFile.replace('FleetCommander_', '').replace('.json', '')

        // Find the buffer ark by checking for a buffer ark deployment with the same fleet name
        const bufferArkFile = deploymentFiles.find(
          (file) =>
            file.includes('BufferArk') && file.includes(fleetName) && file.endsWith('.json'),
        )

        let bufferArkAddress: Address = '0x0000000000000000000000000000000000000000'
        if (bufferArkFile) {
          const bufferArkPath = path.join(deploymentsDir, bufferArkFile)
          const bufferArkDeployment = JSON.parse(fs.readFileSync(bufferArkPath, 'utf8'))
          bufferArkAddress = bufferArkDeployment.address
        }

        // Find ark deployments associated with this fleet
        const arkFiles = deploymentFiles.filter(
          (file) =>
            file.includes('Ark') &&
            !file.includes('BufferArk') &&
            file.includes(fleetName) &&
            file.endsWith('.json'),
        )

        const arkAddresses: Address[] = []
        for (const arkFile of arkFiles) {
          const arkPath = path.join(deploymentsDir, arkFile)
          const arkDeployment = JSON.parse(fs.readFileSync(arkPath, 'utf8'))
          arkAddresses.push(arkDeployment.address)
        }

        // Extract config from the fleet commander construction args if available
        let config = {}
        if (fcDeployment.args) {
          const args = fcDeployment.args
          config = {
            depositCap: args.find((arg: any) => arg.name === 'depositCap')?.value,
            minimumBufferBalance: args.find(
              (arg: any) => arg.name === 'initialMinimumBufferBalance',
            )?.value,
            rebalanceCooldown: args.find((arg: any) => arg.name === 'initialRebalanceCooldown')
              ?.value,
            tipRate: args.find((arg: any) => arg.name === 'initialTipRate')?.value,
          }
        }

        fleets.push({
          name: fleetName,
          fleetCommander: fcDeployment.address,
          bufferArk: bufferArkAddress,
          arks: arkAddresses,
          config,
        })
      } catch (error) {
        console.log(kleur.yellow(`Error processing fleet commander file ${fcFile}:`), error)
      }
    }

    return fleets
  } catch (error) {
    console.log(kleur.red(`Error reading deployments directory for ${chainName}:`), error)
    return []
  }
}

/**
 * Format a fleet deployment into a readable description
 */
export function formatFleetDeployments(
  fleets: Array<{
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
): string {
  if (fleets.length === 0) {
    return 'No fleet deployments found.'
  }

  return fleets
    .map((fleet) => {
      // Format configuration values if available
      const configDetails = fleet.config
        ? `
    - Deposit Cap: ${fleet.config.depositCap || 'N/A'}
    - Minimum Buffer Balance: ${fleet.config.minimumBufferBalance || 'N/A'}
    - Rebalance Cooldown: ${fleet.config.rebalanceCooldown || 'N/A'}
    - Tip Rate: ${fleet.config.tipRate || 'N/A'}`
        : ''

      return `
### Fleet: ${fleet.name}
- Fleet Commander: ${fleet.fleetCommander}
- Buffer Ark: ${fleet.bufferArk}
- Number of Arks: ${fleet.arks.length}${configDetails}
- Ark Addresses:
  ${fleet.arks.map((ark) => `  - ${ark}`).join('\n')}`
    })
    .join('\n\n')
}
