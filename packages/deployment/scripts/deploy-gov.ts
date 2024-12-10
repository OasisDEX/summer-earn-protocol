import hre from 'hardhat'
import kleur from 'kleur'

import { Address, keccak256, toBytes } from 'viem'
import { GovContracts, GovModule } from '../ignition/modules/gov'
import { BaseConfig } from '../types/config-types'
import { ADDRESS_ZERO } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'
import { updateIndexJson } from './helpers/update-json'

const PROPOSER_ROLE = keccak256(toBytes('PROPOSER_ROLE'))
const EXECUTOR_ROLE = keccak256(toBytes('EXECUTOR_ROLE'))
const CANCELLER_ROLE = keccak256(toBytes('CANCELLER_ROLE'))
const DECAY_CONTROLLER_ROLE = keccak256(toBytes('DECAY_CONTROLLER_ROLE'))
const GOVERNOR_ROLE = keccak256(toBytes('GOVERNOR_ROLE'))
const ADMIRALS_QUARTERS_ROLE = keccak256(toBytes('ADMIRALS_QUARTERS_ROLE'))

interface PeerConfig {
  eid: number
  address: string
}

export async function deployGov() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
  const config = getConfigByNetwork(hre.network.name)
  const deployedGov = await deployGovContracts(config)
  ModuleLogger.logGov(deployedGov)
  return deployedGov
}

/**
 * Deploys the gov contracts using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<GovContracts>} The deployed gov contracts.
 */
async function deployGovContracts(config: BaseConfig): Promise<GovContracts> {
  console.log(kleur.cyan().bold('Deploying Gov Contracts...'))

  const initialSupply = getInitialSupply(config)
  console.log(kleur.blue('Initial Supply:'), kleur.cyan(`${initialSupply} SUMMER`))

  // Add peer configuration prompt
  const peers = getPeersFromConfig(hre.network.name)
  const gov = await hre.ignition.deploy(GovModule, {
    parameters: {
      GovModule: {
        lzEndpoint: config.common.layerZero.lzEndpoint,
        protocolAccessManager: config.deployedContracts.core.protocolAccessManager.address,
        initialSupply,
        peerEndpointIds: peers.map((p) => p.eid),
        peerAddresses: peers.map((p) => p.address),
      },
    },
  })

  updateIndexJson('gov', hre.network.name, gov)
  await setupGovernanceRoles(gov, config)

  console.log(kleur.green().bold('All Gov Contracts Deployed Successfully!'))

  return gov
}

/**
 * Retrieves the initial supply of tokens from the configuration.
 *
 * @param config - The configuration object for the current network.
 * @returns The initial supply of tokens as a bigint, scaled to 18 decimal places.
 */
function getInitialSupply(config: BaseConfig): bigint {
  return BigInt(config.common.initialSupply) * 10n ** 18n
}

/**
 * Retrieves the peer configuration for the given network.
 *
 * This function iterates over all available networks, excluding the current one,
 * and collects the peer configurations for networks where the SummerGovernor contract
 * is deployed. The peer configuration includes the endpoint ID (eid) and the address
 * of the SummerGovernor contract.
 *
 * @param currentNetwork - The name of the current network to exclude from the peer list.
 * @returns An array of peer configurations.
 */
function getPeersFromConfig(currentNetwork: string): PeerConfig[] {
  const peers: PeerConfig[] = []
  const networks = Object.keys(hre.config.networks)

  for (const network of networks) {
    console.log(kleur.blue().bold('Checking network:'), kleur.cyan(network))
    // Skip current network
    if (network === currentNetwork || network === 'hardhat' || network === 'local') {
      console.log(kleur.blue().bold('Skipping current network:'), kleur.cyan(network))
      continue
    }

    // Get config for the network
    try {
      const networkConfig = getConfigByNetwork(network)
      // Skip if no gov contracts or SummerGovernor not deployed
      if (
        !networkConfig.deployedContracts?.gov?.summerGovernor?.address ||
        networkConfig.deployedContracts?.gov?.summerGovernor.address == ADDRESS_ZERO
      )
        continue
      peers.push({
        eid: parseInt(networkConfig.common.layerZero.eID),
        address: networkConfig.deployedContracts.gov.summerGovernor.address,
      })
    } catch (error) {
      console.log(kleur.red().bold('Skipping network, lack of config:'), kleur.cyan(network))
      continue
    }
  }

  // Log peer configuration
  if (peers.length > 0) {
    console.log('\nConfigured Peers:')
    peers.forEach((peer) => {
      console.log(kleur.blue(`EID: ${peer.eid}`), kleur.cyan(`Address: ${peer.address}`))
    })
  }

  return peers
}

/**
 * @dev Post-deployment governance setup
 *
 * Configuration sequence:
 * 1. Configure SummerToken
 *    - Transfer ownership to TimelockController
 *    - Get rewards manager address
 *
 * 2. Configure TimelockController roles
 *    - Grant PROPOSER_ROLE to SummerGovernor
 *    - Grant CANCELLER_ROLE to SummerGovernor
 *    - Grant EXECUTOR_ROLE to SummerGovernor
 *
 * 3. Configure ProtocolAccessManager roles
 *    - Grant DECAY_CONTROLLER_ROLE to rewards manager
 *    - Grant DECAY_CONTROLLER_ROLE to SummerGovernor
 *    - Grant GOVERNOR_ROLE to TimelockController
 *
 * 4. Cleanup deployer roles
 *    - Revoke GOVERNOR_ROLE from deployer in ProtocolAccessManager
 *    - Revoke PROPOSER_ROLE from deployer in TimelockController
 *    - Revoke DEFAULT_ADMIN_ROLE from deployer in TimelockController
 */
async function setupGovernanceRoles(gov: GovContracts, config: BaseConfig) {
  console.log(kleur.cyan().bold('Setting up governance roles...'))
  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()

  const timelock = await hre.viem.getContractAt(
    'TimelockController' as string,
    gov.timelock.address as Address,
  )
  const summerToken = await hre.viem.getContractAt(
    'SummerToken' as string,
    gov.summerToken.address as Address,
  )
  const summerGovernor = await hre.viem.getContractAt(
    'SummerGovernor' as string,
    gov.summerGovernor.address as Address,
  )
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    config.deployedContracts.core.protocolAccessManager.address as Address,
  )

  // Get governance rewards manager address from SummerToken
  const rewardsManagerAddress = await summerToken.read.rewardsManager()

  // Transfer SummerToken ownership to timelock
  const currentOwner = (await summerToken.read.owner()) as Address
  if (currentOwner.toLowerCase() === deployer.account.address.toLowerCase()) {
    console.log('[SUMMER TOKEN] - Transferring ownership from deployer to timelock...')
    const hash = await summerToken.write.transferOwnership([timelock.address])
    await publicClient.waitForTransactionReceipt({ hash })
  } else {
    console.log('[SUMMER TOKEN] - Current owner is not deployer:', currentOwner)
    console.log('[SUMMER TOKEN] - Skipping ownership transfer')
  }

  // Determine if we're on HUB chain (currently BASE chain)
  const isHubChain = (await summerGovernor.read.proposalChainId()) === hre.network.config.chainId

  // Set up the correct governor role based on chain
  if (isHubChain) {
    console.log('[PROTOCOL ACCESS MANAGER] - Setting up HUB chain governance...')
    // On HUB, the timelock should have governor role
    const hasGovernorRole = await protocolAccessManager.read.hasRole([
      GOVERNOR_ROLE,
      timelock.address,
    ])
    if (!hasGovernorRole) {
      console.log('[PROTOCOL ACCESS MANAGER] - Granting governor role to timelock...')
      const hash = await protocolAccessManager.write.grantGovernorRole([timelock.address])
      await publicClient.waitForTransactionReceipt({ hash })
    }
  } else {
    console.log('[PROTOCOL ACCESS MANAGER] - Setting up satellite chain governance...')
    // On satellite chains, the governor contract itself should have governor role
    const hasGovernorRole = await protocolAccessManager.read.hasRole([
      GOVERNOR_ROLE,
      summerGovernor.address,
    ])
    if (!hasGovernorRole) {
      console.log('[PROTOCOL ACCESS MANAGER] - Granting governor role to governor contract...')
      const hash = await protocolAccessManager.write.grantGovernorRole([summerGovernor.address])
      await publicClient.waitForTransactionReceipt({ hash })
    }
  }

  // On satellite chains, grant CANCELLER_ROLE to timelock
  if (!isHubChain) {
    const hasTimelockCancellerRole = await timelock.read.hasRole([CANCELLER_ROLE, timelock.address])
    if (!hasTimelockCancellerRole) {
      console.log('[TIMELOCK] - Granting CANCELLER_ROLE to timelock on satellite chain...')
      const hash = await timelock.write.grantRole([CANCELLER_ROLE, timelock.address])
      await publicClient.waitForTransactionReceipt({ hash })
    }
  }

  // Rest of the setup remains the same for both chains
  // Grant decay controller role to governance rewards manager
  const hasDecayRole = await protocolAccessManager.read.hasRole([
    DECAY_CONTROLLER_ROLE,
    rewardsManagerAddress,
  ])
  if (!hasDecayRole) {
    console.log(
      '[PROTOCOL ACCESS MANAGER] - Granting decay controller role to governance rewards manager...',
    )
    const hash = await protocolAccessManager.write.grantDecayControllerRole([rewardsManagerAddress])
    await publicClient.waitForTransactionReceipt({ hash })
  }

  const hasDecayRole2 = await protocolAccessManager.read.hasRole([
    DECAY_CONTROLLER_ROLE,
    summerGovernor.address,
  ])
  if (!hasDecayRole2) {
    console.log('[PROTOCOL ACCESS MANAGER] - Granting decay controller role to SummerGovernor...')
    const hash = await protocolAccessManager.write.grantDecayControllerRole([
      summerGovernor.address,
    ])
    await publicClient.waitForTransactionReceipt({ hash })
  }

  // On BASE chain only: Set up timelock roles
  if (isHubChain) {
    // Grant roles to SummerGovernor in Timelock
    const roles = [
      { name: 'PROPOSER_ROLE', value: PROPOSER_ROLE },
      { name: 'CANCELLER_ROLE', value: CANCELLER_ROLE },
      { name: 'EXECUTOR_ROLE', value: EXECUTOR_ROLE },
    ]

    for (const role of roles) {
      const hasRole = await timelock.read.hasRole([role.value, summerGovernor.address])
      if (!hasRole) {
        console.log(`[TIMELOCK] - Granting ${role.name} to SummerGovernor...`)
        const hash = await timelock.write.grantRole([role.value, summerGovernor.address])
        await publicClient.waitForTransactionReceipt({ hash })
      }
    }
  }
  const hasAdmiralsQuartersRole =
    config.deployedContracts.core.admiralsQuarters.address !== ADDRESS_ZERO &&
    (await protocolAccessManager.read.hasRole([
      ADMIRALS_QUARTERS_ROLE,
      config.deployedContracts.core.admiralsQuarters.address,
    ]))
  if (!hasAdmiralsQuartersRole) {
    console.log(
      '[PROTOCOL ACCESS MANAGER] - Granting admirals quarters role to admirals quarters...',
    )
    const hash = await protocolAccessManager.write.grantAdmiralsQuartersRole([
      config.deployedContracts.core.admiralsQuarters.address,
    ])
    await publicClient.waitForTransactionReceipt({ hash })
  }
  console.log(kleur.green().bold('Governance roles setup completed!'))
}

deployGov().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
