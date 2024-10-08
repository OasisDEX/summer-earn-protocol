import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import { FleetContracts } from '../../ignition/modules/fleet'

/**
 * Creates and saves a deployment JSON file with fleet information.
 * @param {any} fleetDefinition - The fleet definition object.
 * @param {FleetContracts} deployedFleet - The deployed fleet contracts.
 */
export function saveFleetDeploymentJson(
  fleetDefinition: any,
  deployedFleet: FleetContracts,
  bufferArkAddress: string,
) {
  const deploymentInfo = {
    fleetName: fleetDefinition.fleetName,
    fleetSymbol: fleetDefinition.symbol,
    assetSymbol: fleetDefinition.assetSymbol,
    fleetAddress: deployedFleet.fleetCommander.address,
    bufferArkAddress: bufferArkAddress,
    configFile: fleetDefinition.configFile,
    network: fleetDefinition.network,
  }

  const deploymentDir = path.resolve(__dirname, '..','..', 'deployments')
  if (!fs.existsSync(deploymentDir)) {
    fs.mkdirSync(deploymentDir, { recursive: true })
  }

  const fileName = `${fleetDefinition.fleetName.replace(/\W/g, '')}_deployment.json`
  const filePath = path.join(deploymentDir, fileName)

  fs.writeFileSync(filePath, JSON.stringify(deploymentInfo, null, 2))

  console.log(kleur.green().bold(`Deployment information saved to: ${filePath}`))
}
