import hre from 'hardhat'
import kleur from 'kleur'

import { Address, keccak256, toBytes } from 'viem'
import { GovContracts, GovModule } from '../ignition/modules/gov'
import { BaseConfig, SupportedNetworks } from '../types/config-types'
import { ADDRESS_ZERO } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'
import { updateIndexJson } from './helpers/update-json'

const PROPOSER_ROLE = keccak256(toBytes('PROPOSER_ROLE'))
const EXECUTOR_ROLE = keccak256(toBytes('EXECUTOR_ROLE'))
const CANCELLER_ROLE = keccak256(toBytes('CANCELLER_ROLE'))
const DECAY_CONTROLLER_ROLE = keccak256(toBytes('DECAY_CONTROLLER_ROLE'))
const GOVERNOR_ROLE = keccak256(toBytes('GOVERNOR_ROLE'))

interface PeerConfig {
  eid: number
  address: string
}

interface NetworkPeers {
  tokenPeers: PeerConfig[]
  governorPeers: PeerConfig[]
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

  if (config.common.layerZero.lzEndpoint === ADDRESS_ZERO) {
    throw new Error('LayerZero is not set up correctly')
  }
  // Add peer configuration prompt
  const peers = getPeersFromConfig(hre.network.name)
  console.log('Deploying Gov Module...')
  const gov = await hre.ignition.deploy(GovModule, {
    parameters: {
      GovModule: {
        lzEndpoint: config.common.layerZero.lzEndpoint,
        initialSupply,
        peerEndpointIds: peers.tokenPeers.map((p) => p.eid),
        peerAddresses: peers.tokenPeers.map((p) => p.address),
        governorPeerEndpointIds: peers.governorPeers.map((p) => p.eid),
        governorPeerAddresses: peers.governorPeers.map((p) => p.address),
      },
    },
  })

  console.log('Updating index.json...')
  updateIndexJson('gov', hre.network.name, gov)

  console.log('Setting up governance roles...')
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
 * Retrieves both token and governor peer configurations for the given network.
 * @param currentNetwork - The name of the current network to exclude from the peer list.
 */
function getPeersFromConfig(sourceNetwork: string): NetworkPeers {
  const peers = {
    tokenPeers: getTokenPeers(sourceNetwork),
    governorPeers: getGovernorPeers(sourceNetwork),
  }
  console.log('Gov Peers:', peers.governorPeers)
  console.log('Token Peers:', peers.tokenPeers)
  return peers
}

/**
 * Gets token peer configurations for all networks except current
 */
function getTokenPeers(sourceNetwork: string): PeerConfig[] {
  return getPeersForContract(sourceNetwork, (config) => ({
    address: config.deployedContracts?.gov?.summerToken?.address,
    skipSatelliteToSatellite: false,
    label: 'TOKEN',
  }))
}

/**
 * Gets governor peer configurations following hub-spoke model
 */
function getGovernorPeers(sourceNetwork: string): PeerConfig[] {
  return getPeersForContract(sourceNetwork, (config) => ({
    address: config.deployedContracts?.gov?.summerGovernor?.address,
    skipSatelliteToSatellite: true,
    label: 'GOVERNOR',
  }))
}

/**
 * Shared functionality for getting peer configurations
 */
function getPeersForContract(
  sourceNetwork: string,
  getContractInfo: (config: BaseConfig) => {
    address: string | undefined
    skipSatelliteToSatellite: boolean
    label: string
  },
): PeerConfig[] {
  const peers: PeerConfig[] = []
  const networks = Object.values(SupportedNetworks)
  const HUB_NETWORK = SupportedNetworks.BASE
  const isSourceHub = sourceNetwork === HUB_NETWORK

  for (const targetNetwork of networks) {
    if (targetNetwork === sourceNetwork) {
      console.log(
        kleur.blue().bold('Peering - skipping source network:'),
        kleur.cyan(targetNetwork),
      )
      continue
    }

    try {
      const networkConfig = getConfigByNetwork(targetNetwork)
      const { address, skipSatelliteToSatellite, label } = getContractInfo(networkConfig)
      const layerZeroEID = networkConfig.common?.layerZero?.eID

      const isTargetHub = targetNetwork === HUB_NETWORK

      if (!layerZeroEID) {
        console.log(
          kleur.yellow().bold('Peering - skipping network, missing LayerZero config:'),
          kleur.cyan(targetNetwork),
        )
        continue
      }

      // Skip satellite-to-satellite connections if specified
      if (skipSatelliteToSatellite && !isSourceHub && !isTargetHub) {
        console.log(
          kleur.blue().bold(`Peering - ${label} - skipping satellite-to-satellite peering:`),
          kleur.cyan(`${sourceNetwork} -> ${targetNetwork}`),
        )
        continue
      }

      // Only add peer if address exists and is not zero address
      if (address && address !== ADDRESS_ZERO) {
        peers.push({
          eid: parseInt(layerZeroEID),
          address,
        })
      } else {
        console.log(
          kleur.yellow().bold('Peering - skipping network, no valid contract address:'),
          kleur.cyan(targetNetwork),
        )
      }
    } catch (error) {
      console.log(kleur.red().bold('Error processing network config:'), kleur.cyan(targetNetwork))
      console.error(error)
      continue
    }
  }

  return peers
}

/**
 * @dev Post-deployment governance setup
 *
 * Configuration sequence:
 * 1. Configure SummerToken
 *    - Initialize token with peers if not initialized
 *    - Transfer ownership to TimelockController
 *    - Get rewards manager and vesting factory addresses
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
  const deployer = (await hre.viem.getWalletClients())[0]

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
    gov.protocolAccessManager.address as Address,
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
  const isHubChain =
    (await summerGovernor.read.hubChainId()) === BigInt(!hre.network.config.chainId)

  // Remove the chain-specific governor role assignment and always set timelock as governor
  console.log('[PROTOCOL ACCESS MANAGER] - Setting up governance...')
  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    timelock.address,
  ])
  if (!hasGovernorRole) {
    console.log('[PROTOCOL ACCESS MANAGER] - Granting governor role to timelock...')
    const hash = await protocolAccessManager.write.grantGovernorRole([timelock.address])
    await publicClient.waitForTransactionReceipt({ hash })
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
  console.log(kleur.green().bold('Governance roles setup completed!'))
}

deployGov().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
