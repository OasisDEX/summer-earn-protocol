import hre from 'hardhat'
import kleur from 'kleur'
import { BridgeConfig } from '../types/bridge-types'
import { deployBridgeContracts } from './bridge/bridge-contracts'
import { saveBridgeDeploymentJson } from './bridge/bridge-deployment-helpers'
import {
  createBridgeGovernanceProposal,
  setupBridgeGovernance,
} from './bridge/bridge-governance-helpers'
import { GOVERNOR_ROLE, HUB_CHAIN_NAME } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'

async function deployBridge() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const isHubChain = network === HUB_CHAIN_NAME
  console.log(kleur.blue('Chain Type:'), isHubChain ? kleur.cyan('Hub') : kleur.cyan('Satellite'))

  // Load network configuration
  const config = getConfigByNetwork(network, { gov: true, core: true })

  // Load bridge configuration
  const bridgeConfig: BridgeConfig = config.bridge

  console.log(kleur.green().bold('Starting bridge deployment...'))

  // Deploy core bridge contracts
  const deployedBridge = await deployBridgeContracts(bridgeConfig, config)

  // Save deployment data
  await saveBridgeDeploymentJson(deployedBridge, network)

  // Check if deployer has governor role
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager',
    config.deployedContracts.gov.protocolAccessManager.address,
  )
  const [deployer] = await hre.viem.getWalletClients()
  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    deployer.account.address,
  ])

  if (hasGovernorRole) {
    // Direct setup
    console.log(kleur.green('Deployer has governor role. Setting up governance directly...'))
    await setupBridgeGovernance(deployedBridge, config)
  } else {
    // Create governance proposal
    console.log(
      kleur.yellow('Deployer does not have governor role. Creating governance proposal...'),
    )
    await createBridgeGovernanceProposal(deployedBridge, config)
  }

  console.log(kleur.green().bold('Bridge deployment completed successfully!'))
}

// Execute the deployBridge function and handle any errors
deployBridge().catch((error) => {
  console.error(kleur.red('Error during bridge deployment:'))
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
})
