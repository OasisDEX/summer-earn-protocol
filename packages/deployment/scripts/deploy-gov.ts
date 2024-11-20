import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'

import { Address, keccak256, toBytes } from 'viem'
import { GovContracts, GovModule } from '../ignition/modules/gov'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'
import { updateIndexJson } from './helpers/update-json'

const PROPOSER_ROLE = keccak256(toBytes('PROPOSER_ROLE'))
const EXECUTOR_ROLE = keccak256(toBytes('EXECUTOR_ROLE'))
const CANCELLER_ROLE = keccak256(toBytes('CANCELLER_ROLE'))
const DECAY_CONTROLLER_ROLE = keccak256(toBytes('DECAY_CONTROLLER_ROLE'))
const GOVERNOR_ROLE = keccak256(toBytes('GOVERNOR_ROLE'))

// Add interface for peer configuration
interface PeerConfig {
  chainId: number
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

  const initialSupply = await promptForInitialSupply()
  console.log(kleur.blue('Initial Supply:'), kleur.cyan(`${initialSupply} SUMMER`))

  // Add peer configuration prompt
  const peers = await promptForPeers()

  const gov = await hre.ignition.deploy(GovModule, {
    parameters: {
      GovModule: {
        lzEndpoint: config.common.lzEndpoint,
        protocolAccessManager: config.deployedContracts.core.protocolAccessManager.address,
        initialSupply,
        // Add peer configuration
        peerChainIds: peers.map((p) => p.chainId),
        peerAddresses: peers.map((p) => p.address),
      },
    },
  })

  updateIndexJson('gov', hre.network.name, gov)
  await setupGovernanceRoles(gov, config)

  console.log(kleur.green().bold('All Gov Contracts Deployed Successfully!'))

  return gov
}

async function promptForInitialSupply(): Promise<bigint> {
  if (process.env.SUMMER_INITIAL_SUPPLY) {
    return BigInt(process.env.SUMMER_INITIAL_SUPPLY)
  }

  const { value } = await prompts({
    type: 'text',
    name: 'value',
    message: 'Enter the initial supply of SUMMER tokens (e.g., 10000000 for 10M tokens):',
    initial: '10000000',
    validate: (value: string) => {
      const num = Number(value)
      if (isNaN(num) || num < 0) {
        return 'Please enter a valid positive number'
      }
      if (!Number.isInteger(num)) {
        return 'Please enter a whole number'
      }
      return true
    },
  })

  return BigInt(value) * 10n ** 18n
}

// Add new function to prompt for peer configuration
async function promptForPeers(): Promise<PeerConfig[]> {
  if (process.env.SKIP_PEER_SETUP === 'true') {
    console.log(kleur.yellow('Skipping peer setup as SKIP_PEER_SETUP=true'))
    return []
  }

  const { setupPeers } = await prompts({
    type: 'confirm',
    name: 'setupPeers',
    message: 'Would you like to configure peer governors?',
    initial: true,
  })

  if (!setupPeers) return []

  const peers: PeerConfig[] = []
  let addMore = true

  while (addMore) {
    const { chainId } = await prompts({
      type: 'number',
      name: 'chainId',
      message: 'Enter the LayerZero chain ID for the peer:',
      validate: (value) => value > 0 || 'Please enter a valid chain ID',
    })

    const { address } = await prompts({
      type: 'text',
      name: 'address',
      message: 'Enter the governor contract address for this peer:',
      validate: (value) => /^0x[a-fA-F0-9]{40}$/.test(value) || 'Please enter a valid address',
    })

    peers.push({ chainId, address })

    const { continue: shouldContinue } = await prompts({
      type: 'confirm',
      name: 'continue',
      message: 'Would you like to add another peer?',
      initial: false,
    })

    addMore = shouldContinue
  }

  // Log peer configuration
  if (peers.length > 0) {
    console.log('\nConfigured Peers:')
    peers.forEach((peer) => {
      console.log(kleur.blue(`Chain ID: ${peer.chainId}`), kleur.cyan(`Address: ${peer.address}`))
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

  // Transfer SummerToken ownership to timelock if not already owned
  // const currentTokenOwner = await summerToken.read.owner()
  // if (currentTokenOwner !== timelock.address) {
  //   console.log('Transferring SummerToken ownership to timelock...')
  //   const hash = await summerToken.write.transferOwnership([timelock.address])
  //   await publicClient.waitForTransactionReceipt({
  //     hash: hash,
  //   })
  // }

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
      await publicClient.waitForTransactionReceipt({
        hash: hash,
      })
    }
  }

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
    await publicClient.waitForTransactionReceipt({
      hash: hash,
    })
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
    await publicClient.waitForTransactionReceipt({
      hash: hash,
    })
  }

  // Grant governor role to timelock
  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    timelock.address,
  ])
  if (!hasGovernorRole) {
    console.log('[PROTOCOL ACCESS MANAGER] - Granting governor role to timelock...')
    const hash = await protocolAccessManager.write.grantGovernorRole([timelock.address])
    await publicClient.waitForTransactionReceipt({
      hash: hash,
    })
  }
  // todo: uncomment on final deployment
  // // Revoke roles from deployer
  // const hasDeployerGovernorRole = await protocolAccessManager.read.hasRole([
  //   GOVERNOR_ROLE,
  //   deployer.account.address,
  // ])
  // if (hasDeployerGovernorRole) {
  //   console.log('[PROTOCOL ACCESS MANAGER] - Revoking governor role from deployer...')
  //   const hash = await protocolAccessManager.write.revokeGovernorRole([deployer.account.address])
  //   await publicClient.waitForTransactionReceipt({
  //     hash: hash,
  //   })
  // }

  // const hasProposerRole = await timelock.read.hasRole([PROPOSER_ROLE, deployer.account.address])
  // if (hasProposerRole) {
  //   console.log('[TIMELOCK] - Revoking proposer role from deployer...')
  //   const hash = await timelock.write.revokeRole([PROPOSER_ROLE, deployer.account.address])
  //   await publicClient.waitForTransactionReceipt({
  //     hash: hash,
  //   })
  // }

  // // todo: why is this not showing that deployer has admin role
  // const hasDefaultAdminRole = await timelock.read.hasRole([
  //   DEFAULT_ADMIN_ROLE,
  //   deployer.account.address,
  // ])
  // if (hasDefaultAdminRole) {
  //   console.log('[TIMELOCK] - Revoking default admin role from deployer...')
  //   const hash = await timelock.write.revokeRole([DEFAULT_ADMIN_ROLE, deployer.account.address])
  //   await publicClient.waitForTransactionReceipt({
  //     hash: hash,
  //   })
  // }

  console.log(kleur.green().bold('Governance roles setup completed!'))
}

deployGov().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
