import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import { AdmiralsQuartersModule } from '../ignition/modules/admiralsQuarters'
import { BaseConfig } from '../types/config-types'
import { ADMIRALS_QUARTERS_ROLE, GOVERNOR_ROLE } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { updateIndexJson } from './helpers/update-json'

export async function redeployAdmiralsQuarters() {
  const config = getConfigByNetwork(hre.network.name, { common: true, gov: true, core: true })

  console.log(kleur.cyan().bold('Redeploying AdmiralsQuarters...'))

  const result = await hre.ignition.deploy(AdmiralsQuartersModule, {
    parameters: {
      AdmiralsQuartersModule: {
        swapProvider: config.common.swapProvider,
        configurationManager: config.deployedContracts.core.configurationManager.address,
        weth: config.tokens.weth,
      },
    },
  })

  console.log(kleur.green().bold('AdmiralsQuarters Redeployed Successfully!'))

  // Update just the admiralsQuarters address in the core config
  const coreContracts = {
    ...config.deployedContracts.core,
    admiralsQuarters: result.admiralsQuarters,
  }
  updateIndexJson('core', hre.network.name, coreContracts)

  // Set up governance roles for the new AdmiralsQuarters
  const updatedConfig = getConfigByNetwork(hre.network.name, {
    common: true,
    gov: true,
    core: true,
  })
  await setupGovernanceRoles(updatedConfig)

  return result
}

async function setupGovernanceRoles(config: BaseConfig) {
  console.log(kleur.cyan().bold('Setting up governance roles for new AdmiralsQuarters...'))
  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()
  console.log('Deployer: ', deployer.account.address)

  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )

  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    deployer.account.address,
  ])

  const hasAdmiralsQuartersRole = await protocolAccessManager.read.hasRole([
    ADMIRALS_QUARTERS_ROLE,
    config.deployedContracts.core.admiralsQuarters.address,
  ])

  if (hasGovernorRole) {
    // Deployer has governor role, can directly grant the admirals quarters role
    if (!hasAdmiralsQuartersRole) {
      console.log(
        '[PROTOCOL ACCESS MANAGER] - Granting admirals quarters role to new admirals quarters...',
      )
      const hash = await protocolAccessManager.write.grantAdmiralsQuartersRole([
        config.deployedContracts.core.admiralsQuarters.address,
      ])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green('AdmiralsQuarters role granted successfully!'))
    } else {
      console.log(kleur.yellow('AdmiralsQuarters already has the ADMIRALS_QUARTERS_ROLE'))
    }
  } else {
    // Deployer does not have governor role, need to create a proposal
    console.log(kleur.yellow('Deployer does not have GOVERNOR_ROLE in ProtocolAccessManager'))
    console.log(
      kleur.yellow(
        `A governance proposal will be needed to grant ADMIRALS_QUARTERS_ROLE to the new AdmiralsQuarters at ${config.deployedContracts.core.admiralsQuarters.address}`,
      ),
    )

    // Generate proposal details
    console.log(kleur.cyan().bold('Governance Proposal Details:'))
    console.log(
      kleur.yellow('Target: '),
      kleur.cyan(config.deployedContracts.gov.protocolAccessManager.address),
    )
    console.log(kleur.yellow('Function: '), kleur.cyan('grantAdmiralsQuartersRole'))
    console.log(
      kleur.yellow('Arguments: '),
      kleur.cyan(`[${config.deployedContracts.core.admiralsQuarters.address}]`),
    )
    console.log(
      kleur.yellow('Description: '),
      kleur.cyan('Grant ADMIRALS_QUARTERS_ROLE to newly deployed AdmiralsQuarters contract'),
    )

    // Note: Add code here to generate and submit a proposal if your system supports it
    // This would typically use your governance contract's propose() function
  }
}

redeployAdmiralsQuarters().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
