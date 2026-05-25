import hre from 'hardhat'
import kleur from 'kleur'

import { Address as ViemAddress } from 'viem'
import { createInstitutionWhitelistModule } from '../ignition/modules/institution-whitelist'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork, getInstitutionConfigByNetwork } from './helpers/config-handler'
import {
  promptForInstitutionId,
  readInstitutionGovernance,
  updateInstitutionDeployedContracts,
} from './helpers/institution-config'
import { promptForConfigType } from './helpers/prompt-helpers'
import { validateAddress, validateToken } from './helpers/validation'

async function main() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  const useBummerConfig = await promptForConfigType()
  const publicClient = await hre.viem.getPublicClient()
  // Choose institution from existing folders or manual entry (shared helper)
  const institutionId = await promptForInstitutionId()

  if (!institutionId) {
    console.log(kleur.red('No institution id provided. Exiting.'))
    return
  }

  const config = getConfigByNetwork(
    hre.network.name,
    { common: true, gov: false, core: false },
    useBummerConfig,
  ) as BaseConfig
  const institutionConfig = getInstitutionConfigByNetwork(
    hre.network.name,
    institutionId,
    { gov: true, core: true },
    useBummerConfig,
  ) as BaseConfig
  // Ensure InstitutionalVaultRegistry V2 is configured in the base (regular) config
  const registryAddress = validateAddress(
    config.deployedContracts.core.institutionalVaultRegistryV2?.address,
    'InstitutionalVaultRegistry V2 address',
  )
  const swapProvider = validateAddress(config.common.swapProvider, 'Swap provider address')
  const weth = validateToken(config, 'weth')
  const wethAddress = config.tokens[weth]

  const registry = await hre.viem.getContractAt('InstitutionalVaultRegistry', registryAddress)

  // check if institution is already registered
  const institutionBytes32 = await registry.read.getBytes32InstitutionId([institutionId])
  const exists = await registry.read.exists([institutionBytes32])

  // check if the addresses match
  const registeredInstitution = await registry.read.institutions([institutionBytes32])
  const addressessMatch =
    registeredInstitution[0] ===
      institutionConfig.deployedContracts.core.configurationManager?.address &&
    registeredInstitution[1] ===
      institutionConfig.deployedContracts.gov.protocolAccessManager?.address &&
    registeredInstitution[2] === institutionConfig.deployedContracts.core.admiralsQuarters?.address

  if (exists && addressessMatch) {
    console.log(kleur.yellow('Institution already registered in registry V2. Skipping deployment.'))
    return
  }

  if (exists && !addressessMatch) {
    // remove institution from registry
    const hash = await registry.write.removeInstitution([institutionBytes32])
    await publicClient.waitForTransactionReceipt({ hash })
    console.log(kleur.green().bold('Institution successfully removed from registry V2.'))
  }

  // Read institution governance for current network and validate
  const governance = readInstitutionGovernance(institutionId, useBummerConfig, hre.network.name)

  const treasury = governance.treasury

  const envLabel = useBummerConfig ? 'staging_' : ''
  const moduleName = `${envLabel}InstitutionWhitelist_${institutionId}`

  const InstitutionModule = createInstitutionWhitelistModule(moduleName)
  const deployed = await hre.ignition.deploy(InstitutionModule, {
    parameters: {
      [moduleName]: {
        swapProvider: swapProvider,
        weth: wethAddress,
        treasury: treasury as ViemAddress,
      },
    },
  })
  console.log(kleur.green().bold('Institution contracts deployed. Writing institution index...'))

  // gov: only protocolAccessManagerV2 for whitelist flow
  updateInstitutionDeployedContracts(institutionId, useBummerConfig, hre.network.name, 'gov', {
    protocolAccessManager: { address: deployed.protocolAccessManager.address },
  })

  // core subset
  updateInstitutionDeployedContracts(institutionId, useBummerConfig, hre.network.name, 'core', {
    tipJar: { address: deployed.tipJar.address },
    configurationManager: { address: deployed.configurationManager.address },
    harborCommand: { address: deployed.harborCommand.address },
    admiralsQuarters: { address: deployed.admiralsQuarters.address },
    raft: { address: deployed.raft.address },
  })

  console.log(kleur.green().bold('Institution index updated successfully.'))

  // Attempt to register institution in the registry if caller is owner
  try {
    // Compute id via contract helper to avoid encoding inconsistencies
    const institutionBytes32 = (await registry.read.getBytes32InstitutionId([
      institutionId,
    ])) as ViemAddress

    const alreadyExists = (await registry.read.exists([institutionBytes32])) as boolean
    if (alreadyExists) {
      console.log(
        kleur.yellow('Institution already registered in registry V2. Skipping registration.'),
      )
      return
    }

    const [deployer] = await hre.viem.getWalletClients()
    const owner = (await registry.read.owner()) as string
    if (owner.toLowerCase() !== deployer.account.address.toLowerCase()) {
      console.log(
        kleur.yellow(
          'Caller is not the owner of InstitutionalVaultRegistry V2. Please register the institution via the owner account.',
        ),
      )
      return
    }

    console.log(kleur.cyan('Registering institution in InstitutionalVaultRegistry V2...'))
    const publicClient = await hre.viem.getPublicClient()
    const hash = await registry.write.addInstitution([
      institutionBytes32,
      {
        configurationManager: deployed.configurationManager.address,
        protocolAccessManager: deployed.protocolAccessManager.address,
        admiralsQuarters: deployed.admiralsQuarters.address,
      },
    ])
    await publicClient.waitForTransactionReceipt({ hash })
    console.log(kleur.green().bold('Institution successfully registered in registry V2.'))
  } catch (e) {
    console.error(
      kleur.red(
        `Failed to register institution in registry V2: ${e instanceof Error ? e.message : String(e)}`,
      ),
    )
  }

  // Grant governor and guardian roles to accounts from institution governance
  try {
    const protocolAccessManagerV2 = await hre.viem.getContractAt(
      'ProtocolAccessManagerV2' as string,
      deployed.protocolAccessManager.address,
    )
    const publicClient = await hre.viem.getPublicClient()

    for (const addr of governance.governor) {
      const hash = await protocolAccessManagerV2.write.grantGovernorRole([addr as ViemAddress])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green(`Granted GOVERNOR_ROLE to ${addr}`))
    }

    for (const addr of governance.guardian) {
      const hash = await protocolAccessManagerV2.write.grantGuardianRole([addr as ViemAddress])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green(`Granted GUARDIAN_ROLE to ${addr}`))
    }

    if (
      governance.superKeeper &&
      governance.superKeeper !== '0x0000000000000000000000000000000000000000'
    ) {
      const hash = await protocolAccessManagerV2.write.grantSuperKeeperRole([
        governance.superKeeper as ViemAddress,
      ])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green(`Granted SUPER_KEEPER_ROLE to ${governance.superKeeper}`))
    }

    for (const addr of governance.whitelistManagers) {
      const hash = await protocolAccessManagerV2.write.grantWhitelistManagerRole([
        addr as ViemAddress,
      ])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green(`Granted WHITELIST_MANAGER_ROLE to ${addr}`))
    }
  } catch (e) {
    console.error(
      kleur.red(`Failed to grant governance roles: ${e instanceof Error ? e.message : String(e)}`),
    )
    throw e
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
