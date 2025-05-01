import { HardhatRuntimeEnvironment } from 'hardhat/types'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address } from 'viem'
import { BaseConfig, FleetConfig, FleetDeployment } from '../../types/config-types'
import { GOVERNOR_ROLE } from './constants'
import {
  getAvailableFleets,
  getFleetDeploymentDir,
  getFleetDeploymentFileName,
  getFleetDeploymentPath,
  loadFleetDeployment,
} from './fleet-deployment-files-helpers'
import { grantCommanderRole } from './grant-commander-role'

/**
 * Adds the deployed Ark to a selected fleet.
 * @param  arkAddress - The address of the deployed Ark.
 * @param  networkName - The name of the current network.
 * @param  hre - The Hardhat runtime environment.
 */
export async function addArkToFleet(
  arkAddress: Address,
  config: BaseConfig,
  hre: HardhatRuntimeEnvironment,
  fleetDefinition?: FleetConfig,
) {
  let fleet: FleetDeployment | undefined
  console.log(kleur.blue('Adding Ark to fleet...'))
  if (!fleetDefinition) {
    const fleets = getAvailableFleets(hre.network.name)

    if (fleets.length === 0) {
      console.log(kleur.yellow('No compatible fleets found for the current network.'))
      return
    }

    const response = await prompts({
      type: 'select',
      name: 'selectedFleet',
      message: 'Select a fleet to add the Ark to:',
      choices: fleets.map((fleet) => ({
        title: `${fleet.fleetName} (${fleet.network})`,
        value: fleet,
      })),
    })
    fleet = response.selectedFleet
  } else {
    const deploymentsDir = getFleetDeploymentDir()
    const fleetFileName = getFleetDeploymentFileName(fleetDefinition)
    fleet = loadFleetDeployment(path.join(deploymentsDir, fleetFileName))
  }
  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()
  if (fleet) {
    console.log(kleur.blue('Selected fleet:'), kleur.cyan(fleet.fleetName))
    console.log(kleur.blue('Fleet address:'), kleur.cyan(fleet.fleetAddress))

    const deploymentData = fleet

    if (!deploymentData.arks) {
      deploymentData.arks = []
    }

    if (deploymentData.arks.includes(arkAddress)) {
      console.log(kleur.red('Ark already added to fleet. Skipping adding Ark to fleet.'))
      return
    }
    await grantCommanderRole(
      config.deployedContracts.gov.protocolAccessManager.address as Address,
      arkAddress as Address,
      fleet.fleetAddress as Address,
      hre,
    )
    const fleetContract = await hre.viem.getContractAt(
      'FleetCommander' as string,
      fleet.fleetAddress,
    )
    const protocolAccessManager = await hre.viem.getContractAt(
      'ProtocolAccessManager' as string,
      config.deployedContracts.gov.protocolAccessManager.address as Address,
    )
    const hasGovernorRole = await protocolAccessManager.read.hasRole([
      GOVERNOR_ROLE,
      deployer.account.address,
    ])
    if (hasGovernorRole) {
      const hash = await fleetContract.write.addArk([arkAddress])
      await publicClient.waitForTransactionReceipt({
        hash: hash,
      })
    } else {
      console.log(kleur.red('Deployer does not have GOVERNOR_ROLE in ProtocolAccessManager'))
      console.log(
        kleur.red(
          `Please add the ark (${arkAddress}) to fleet @ ${fleet.fleetAddress} via governance`,
        ),
      )
    }
    deploymentData.arks.push(arkAddress)
    const filePath = getFleetDeploymentPath(fleet)
    fs.writeFileSync(filePath, JSON.stringify(deploymentData, null, 2))

    console.log(kleur.green(`Updated fleet deployment JSON at ${filePath} \n`))
    console.log(kleur.green('Ark added to fleet successfully!'))
  } else {
    console.log(kleur.yellow('No fleet selected. Skipping adding Ark to fleet.'))
  }
}
