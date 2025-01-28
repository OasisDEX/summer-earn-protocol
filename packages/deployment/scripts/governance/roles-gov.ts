import hre from 'hardhat'
import kleur from 'kleur'
import { Address, keccak256, toBytes } from 'viem'
import { getConfigByNetwork } from '../helpers/config-handler'

const PROPOSER_ROLE = keccak256(toBytes('PROPOSER_ROLE'))
const EXECUTOR_ROLE = keccak256(toBytes('EXECUTOR_ROLE'))
const CANCELLER_ROLE = keccak256(toBytes('CANCELLER_ROLE'))
const DECAY_CONTROLLER_ROLE = keccak256(toBytes('DECAY_CONTROLLER_ROLE'))
const GOVERNOR_ROLE = keccak256(toBytes('GOVERNOR_ROLE'))

const ADDITIONAL_GOVERNORS = ['0x8888013451507E8DD7996509735E15F591886CD2']
/**
 * @dev Post-deployment governance setup
 *
 * Configuration sequence:
 * 1. Configure TimelockController roles
 *    - Grant PROPOSER_ROLE to SummerGovernor
 *    - Grant CANCELLER_ROLE to SummerGovernor
 *    - Grant EXECUTOR_ROLE to SummerGovernor
 *
 * 2. Configure ProtocolAccessManager roles
 *    - Grant DECAY_CONTROLLER_ROLE to rewards manager
 *    - Grant DECAY_CONTROLLER_ROLE to SummerGovernor
 *    - Grant GOVERNOR_ROLE to TimelockController
 */
export async function rolesGov(_additionalGovernors: string[] = []) {
  const multisigTokenReceiver = process.env.BVI_MULTISIG_ADDRESS
  if (!multisigTokenReceiver) {
    throw new Error('BVI_MULTISIG_ADDRESS is not set')
  }
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
  const config = getConfigByNetwork(hre.network.name, { common: true, gov: true, core: false })

  const publicClient = await hre.viem.getPublicClient()

  const deployer = (await hre.viem.getWalletClients())[0].account.address

  const timelock = await hre.viem.getContractAt(
    'TimelockController' as string,
    config.deployedContracts.gov.timelock.address as Address,
  )
  const summerToken = await hre.viem.getContractAt(
    'SummerToken' as string,
    config.deployedContracts.gov.summerToken.address as Address,
  )
  const deployerBalance = await summerToken.read.balanceOf([deployer])

  const isDeployerWhitelisted = await summerToken.read.whitelistedAddresses([deployer])
  if (!isDeployerWhitelisted) {
    console.log(`DEPLOYER - adding to whitelist...`)
    const addToWhitelistHash = await summerToken.write.addToWhitelist([deployer])
    await publicClient.waitForTransactionReceipt({ hash: addToWhitelistHash })
  }

  const isMultisigWhitelisted = await summerToken.read.whitelistedAddresses([multisigTokenReceiver])
  if (!isMultisigWhitelisted) {
    console.log(`MULTISIG - adding to whitelist...`)
    const addToWhitelistHash = await summerToken.write.addToWhitelist([multisigTokenReceiver])
    await publicClient.waitForTransactionReceipt({ hash: addToWhitelistHash })
  }

  console.log(`DEPLOYER - transferring ${deployerBalance} tokens to multisig...`)
  const transferHash = await summerToken.write.transfer([multisigTokenReceiver, deployerBalance])
  await publicClient.waitForTransactionReceipt({ hash: transferHash })

  const summerGovernor = await hre.viem.getContractAt(
    'SummerGovernor' as string,
    config.deployedContracts.gov.summerGovernor.address as Address,
  )
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )

  // Get governance rewards manager address from SummerToken
  const rewardsManagerAddress = await summerToken.read.rewardsManager()

  // Determine if we're on HUB chain (currently BASE chain)
  const isHubChain = (await summerGovernor.read.hubChainId()) === hre.network.config.chainId

  // Set timelock as governor in ProtocolAccessManager
  console.log('[PROTOCOL ACCESS MANAGER] - Setting up governance...')

  // Handle timelock governor role
  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    timelock.address,
  ])
  if (!hasGovernorRole) {
    console.log('[PROTOCOL ACCESS MANAGER] - Granting governor role to timelock...')
    const hash = await protocolAccessManager.write.grantGovernorRole([timelock.address])
    await publicClient.waitForTransactionReceipt({ hash })
  }

  const hasMultisigGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    multisigTokenReceiver,
  ])
  if (!hasMultisigGovernorRole) {
    console.log('[PROTOCOL ACCESS MANAGER] - Granting governor role to multisig...')
    const hash = await protocolAccessManager.write.grantGovernorRole([multisigTokenReceiver])
    await publicClient.waitForTransactionReceipt({ hash })
  }
  const additionalGovernors = [...ADDITIONAL_GOVERNORS, ..._additionalGovernors]
  // Handle additional governors
  if (additionalGovernors.length > 0) {
    console.log('[PROTOCOL ACCESS MANAGER] - Setting up additional governors...')
    for (const governor of additionalGovernors) {
      const hasRole = await protocolAccessManager.read.hasRole([GOVERNOR_ROLE, governor])
      if (!hasRole) {
        console.log(`[PROTOCOL ACCESS MANAGER] - Granting governor role to ${governor}...`)
        const hash = await protocolAccessManager.write.grantGovernorRole([governor])
        await publicClient.waitForTransactionReceipt({ hash })
      } else {
        console.log(`[PROTOCOL ACCESS MANAGER] - Address ${governor} already has governor role`)
      }
    }
  }

  // On satellite chains, grant CANCELLER_ROLE to timelock and PROPOSER_ROLE to governor
  if (!isHubChain) {
    const hasTimelockCancellerRole = await timelock.read.hasRole([CANCELLER_ROLE, timelock.address])
    if (!hasTimelockCancellerRole) {
      console.log('[TIMELOCK] - Granting CANCELLER_ROLE to timelock on satellite chain...')
      const hash = await timelock.write.grantRole([CANCELLER_ROLE, timelock.address])
      await publicClient.waitForTransactionReceipt({ hash })
    }

    const hasGovernorProposerRole = await timelock.read.hasRole([
      PROPOSER_ROLE,
      summerGovernor.address,
    ])
    if (!hasGovernorProposerRole) {
      console.log('[TIMELOCK] - Granting PROPOSER_ROLE to SummerGovernor on satellite chain...')
      const hash = await timelock.write.grantRole([PROPOSER_ROLE, summerGovernor.address])
      await publicClient.waitForTransactionReceipt({ hash })
    }
  }

  // Grant decay controller roles
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

  const hasDecayRole3 = await protocolAccessManager.read.hasRole([
    DECAY_CONTROLLER_ROLE,
    summerToken.address,
  ])
  if (!hasDecayRole3) {
    console.log('[PROTOCOL ACCESS MANAGER] - Granting decay controller role to SummerToken...')
    const hash = await protocolAccessManager.write.grantDecayControllerRole([summerToken.address])
    await publicClient.waitForTransactionReceipt({ hash })
  }

  // On HUB chain only: Set up timelock roles
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

if (require.main === module) {
  rolesGov().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
