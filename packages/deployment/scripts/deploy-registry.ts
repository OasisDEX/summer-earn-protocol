import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { Address } from 'viem'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork } from './helpers/config-handler'
import { getChainId } from './helpers/get-chainid'
import { promptForConfigType } from './helpers/prompt-helpers'

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

  // Deploy CrossChainRegistry
  const crossChainRegistry = await hre.viem.deployContract('CrossChainRegistry', [
    protocolAccessManager,
    currentChainId,
  ])

  console.log(
    kleur.green('CrossChainRegistry deployed at:'),
    kleur.cyan(crossChainRegistry.address),
  )

  // Save deployment info in simplified format
  const deploymentInfo = {
    contractName: 'CrossChainRegistry',
    registryAddress: crossChainRegistry.address,
    network: hre.network.name,
  }

  // Save to deployments directory
  const deploymentPath = path.join(
    __dirname,
    '../deployments/registries',
    `CrossChainRegistry_${hre.network.name}_deployment.json`,
  )

  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2))
  console.log(kleur.green('Deployment info saved to:'), kleur.cyan(deploymentPath))

  return {
    crossChainRegistry: {
      address: crossChainRegistry.address,
    },
  }
}

// When script is run directly
if (require.main === module) {
  deployCrossChainRegistry().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
