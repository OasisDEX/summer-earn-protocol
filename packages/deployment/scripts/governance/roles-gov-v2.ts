import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { CANCELLER_ROLE, EXECUTOR_ROLE, GOVERNOR_ROLE, PROPOSER_ROLE } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'

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
 *    - Grant GOVERNOR_ROLE to TimelockController
 */
export async function rolesGovV2(useBummerConfig = false) {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
  const config = getConfigByNetwork(
    hre.network.name,
    { common: false, gov: true, core: false },
    useBummerConfig,
  ) as BaseConfig

  const publicClient = await hre.viem.getPublicClient()

  const timelock = await hre.viem.getContractAt(
    'TimelockController' as string,
    config.deployedContracts.gov.timelock.address as Address,
  )

  const summerGovernor = await hre.viem.getContractAt(
    'SummerGovernorV2' as string,
    config.deployedContracts.gov.summerGovernorV2.address as Address,
  )
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )

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
  rolesGovV2().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
