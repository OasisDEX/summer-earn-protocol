import { HardhatRuntimeEnvironment } from 'hardhat/types'
import kleur from 'kleur'
import fs from 'node:fs'
import path from 'node:path'
import prompts from 'prompts'
import { Address } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { getAvailableFleets } from './get-available-fleets'
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
) {
  const fleets = getAvailableFleets(hre.network.name)

  if (fleets.length === 0) {
    console.log(kleur.yellow('No compatible fleets found for the current network.'))
    return
  }

  const response = await prompts({
    type: 'select',
    name: 'selectedFleet',
    message: 'Select a fleet to add the Ark to:',
    choices: fleets.map((fleet) => ({ title: fleet.fleetName, value: fleet })),
  })

  if (response.selectedFleet) {
    console.log(kleur.blue('Selected fleet:'), kleur.cyan(response.selectedFleet.fleetName))
    console.log(kleur.blue('Fleet address:'), kleur.cyan(response.selectedFleet.fleetAddress))

    const deploymentPath = path.join(
      __dirname,
      '..',
      '..',
      'deployments',
      response.selectedFleet.fileName,
    )
    const deploymentData = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'))

    if (!deploymentData.arks) {
      deploymentData.arks = []
    }
    if (deploymentData.arks.includes(arkAddress)) {
      console.log(kleur.red('Ark already added to fleet. Skipping adding Ark to fleet.'))
      return
    }
    await grantCommanderRole(
      config.deployedContracts.core.protocolAccessManager.address as Address,
      arkAddress as Address,
      response.selectedFleet.fleetAddress as Address,
      hre,
    )
    const fleetContract = await hre.viem.getContractAt(
      'FleetCommander' as string,
      response.selectedFleet.fleetAddress,
    )
    await fleetContract.write.addArk([arkAddress])
    deploymentData.arks.push(arkAddress)

    fs.writeFileSync(deploymentPath, JSON.stringify(deploymentData, null, 2))
    console.log(kleur.green(`Updated fleet deployment JSON at ${deploymentPath} \n`))

    console.log(kleur.green('Ark added to fleet successfully!'))
  } else {
    console.log(kleur.yellow('No fleet selected. Skipping adding Ark to fleet.'))
  }
}
