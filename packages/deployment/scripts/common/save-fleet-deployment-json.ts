import kleur from 'kleur'
import fs from 'node:fs'
import { FleetContracts } from '../../ignition/modules/fleet'
import { FleetConfig } from '../../types/config-types'
import { getFleetDeploymentDir, getFleetDeploymentPath } from './fleet-deployment-files-helpers'

/**
 * Creates and saves a deployment JSON file with fleet information.
 * @param {any} fleetDefinition - The fleet definition object.
 * @param {FleetContracts} deployedFleet - The deployed fleet contracts.
 */
export function saveFleetDeploymentJson(
  fleetDefinition: FleetConfig,
  deployedFleet: FleetContracts,
  bufferArkAddress: string,
) {
  const deploymentInfo = {
    fleetName: fleetDefinition.fleetName,
    fleetSymbol: fleetDefinition.symbol,
    assetSymbol: fleetDefinition.assetSymbol,
    fleetAddress: deployedFleet.fleetCommander.address,
    bufferArkAddress: bufferArkAddress,
    network: fleetDefinition.network,
    initialMinimumBufferBalance: fleetDefinition.initialMinimumBufferBalance,
    initialRebalanceCooldown: fleetDefinition.initialRebalanceCooldown,
    depositCap: fleetDefinition.depositCap,
    initialTipRate: fleetDefinition.initialTipRate,
  }

  const deploymentDir = getFleetDeploymentDir()
  if (!fs.existsSync(deploymentDir)) {
    fs.mkdirSync(deploymentDir, { recursive: true })
  }

  const filePath = getFleetDeploymentPath(fleetDefinition)

  if (fs.existsSync(filePath)) {
    console.log(
      kleur.red(`File ${filePath} already exists. Skipping overwriting fleet deployment JSON.`),
    )
  } else {
    fs.writeFileSync(filePath, JSON.stringify(deploymentInfo, null, 2))
  }

  console.log(kleur.green().bold(`Deployment information saved to: ${filePath}`))
}
