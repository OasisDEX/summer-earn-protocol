import hre from 'hardhat'
import kleur from 'kleur'
import { createFleetModule, FleetContracts } from '../../ignition/modules/fleet'
import { BaseConfig, FleetConfig } from '../../types/config-types'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { ModuleLogger } from '../helpers/module-logger'

/**
 * Deploys the Fleet and BufferArk contracts using Hardhat Ignition.
 * @param {FleetConfig} fleetDefinition - The fleet definition object.
 * @param {BaseConfig} config - The configuration object.
 * @param {string} asset - The address of the asset.
 */
export async function deployFleetContracts(
  fleetDefinition: FleetConfig,
  config: BaseConfig,
  asset: string,
) {
  console.log(fleetDefinition)
  const chainId = getChainId()
  console.log(chainId)
  const deploymentId = await handleDeploymentId(chainId)
  console.log(deploymentId)

  const name = fleetDefinition.fleetName.replace(/\W/g, '')
  console.log(name)
  const fleetModule = createFleetModule(`FleetModule_${name}`)
  console.log(fleetModule)
  console.table({
    [`FleetModule_${name}`]: {
      configurationManager: config.deployedContracts.core.configurationManager.address,
      protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
      fleetName: fleetDefinition.fleetName,
      fleetSymbol: fleetDefinition.symbol,
      fleetDetails: fleetDefinition.details,
      asset,
      initialMinimumBufferBalance: fleetDefinition.initialMinimumBufferBalance,
      initialRebalanceCooldown: fleetDefinition.initialRebalanceCooldown,
      depositCap: fleetDefinition.depositCap,
      initialTipRate: fleetDefinition.initialTipRate,
      fleetCommanderRewardsManagerFactory: '0x0000000000000000000000000000000000000000',
    },
  })
  const deployedModule = await hre.ignition.deploy(fleetModule, {
    parameters: {
      [`FleetModule_${name}`]: {
        configurationManager: config.deployedContracts.core.configurationManager.address,
        protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
        fleetName: fleetDefinition.fleetName,
        fleetSymbol: fleetDefinition.symbol,
        fleetDetails: fleetDefinition.details,
        asset,
        initialMinimumBufferBalance: fleetDefinition.initialMinimumBufferBalance,
        initialRebalanceCooldown: fleetDefinition.initialRebalanceCooldown,
        depositCap: fleetDefinition.depositCap,
        initialTipRate: fleetDefinition.initialTipRate,
        fleetCommanderRewardsManagerFactory: '0x0000000000000000000000000000000000000000',
      },
    },
    deploymentId,
  })

  return deployedModule
}

/**
 * Logs the results of the deployment, including important addresses and next steps.
 * @param {FleetContracts} deployedFleet - The deployed fleet contracts.
 */
export function logDeploymentResults(deployedFleet: FleetContracts) {
  ModuleLogger.logFleet(deployedFleet)

  console.log(kleur.green('Fleet deployment completed successfully!'))
  console.log(
    kleur.yellow('Fleet Commander Address:'),
    kleur.cyan(deployedFleet.fleetCommander.address),
  )
}
