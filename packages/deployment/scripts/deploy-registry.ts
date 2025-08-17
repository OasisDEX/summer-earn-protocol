import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork } from './helpers/config-handler'
import { getChainId } from './helpers/get-chainid'
import { promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'

export async function deployCrossChainRegistry() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
  console.log(kleur.blue('Deploying CrossChainRegistry...'))

  const useBummerConfig = await promptForConfigType()
  const config = getConfigByNetwork(
    hre.network.name,
    { common: false, gov: true, core: false },
    useBummerConfig,
  ) as BaseConfig

  // Get access manager and chain ID from config
  const protocolAccessManager = config.deployedContracts.gov.protocolAccessManager
    .address as Address
  const currentChainId = getChainId()

  // Validate prerequisites
  if (
    !protocolAccessManager ||
    protocolAccessManager === '0x0000000000000000000000000000000000000000'
  ) {
    throw new Error('ProtocolAccessManager is not deployed')
  }

  console.log(kleur.cyan('Chain ID:'), kleur.green(currentChainId))
  console.log(kleur.cyan('Access Manager:'), kleur.green(protocolAccessManager))

  // Create a simple ignition module for CrossChainRegistry
  const CrossChainRegistryModule = buildModule('CrossChainRegistryModule', (m) => {
    const accessManager = m.getParameter('protocolAccessManager')
    const chainId = m.getParameter('currentChainId')

    const crossChainRegistry = m.contract('CrossChainRegistry', [accessManager, chainId])

    return { crossChainRegistry }
  })

  // Deploy CrossChainRegistry using ignition
  const result = await hre.ignition.deploy(CrossChainRegistryModule, {
    parameters: {
      CrossChainRegistryModule: {
        protocolAccessManager,
        currentChainId,
      },
    },
  })

  console.log(
    kleur.green('CrossChainRegistry deployed at:'),
    kleur.cyan(result.crossChainRegistry.address),
  )

  // Create the contracts object in the same format as core module
  const deployedContracts = {
    crossChainRegistry: {
      address: result.crossChainRegistry.address,
    },
  }

  // Update the main config file
  updateIndexJson('core', hre.network.name, deployedContracts, useBummerConfig)

  console.log(kleur.green('Deployment completed and config updated successfully!'))

  return deployedContracts
}

// When script is run directly
if (require.main === module) {
  deployCrossChainRegistry().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
