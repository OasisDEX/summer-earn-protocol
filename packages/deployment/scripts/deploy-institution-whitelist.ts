import hre from 'hardhat'
import kleur from 'kleur'
// prompts removed: treasury now read from institution index
import { Address as ViemAddress } from 'viem'
import {
  InstitutionWhitelistContracts,
  createInstitutionWhitelistModule,
} from '../ignition/modules/institution-whitelist'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork } from './helpers/config-handler'
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

  // Ensure InstitutionalVaultRegistry is configured in the base (regular) config
  const registryAddress = validateAddress(
    config.deployedContracts.core.institutionalVaultRegistry?.address,
    'InstitutionalVaultRegistry address',
  )
  const swapProvider = validateAddress(config.common.swapProvider, 'Swap provider address')
  const weth = validateToken(config, 'weth')
  const wethAddress = config.tokens[weth]

  // Read institution governance for current network and validate
  const governance = readInstitutionGovernance(institutionId, useBummerConfig, hre.network.name)

  const treasury = governance.treasury

  const moduleName = `InstitutionWhitelist_${institutionId}`
  const InstitutionModule = createInstitutionWhitelistModule(moduleName)
  const deployed = (await hre.ignition.deploy(InstitutionModule, {
    parameters: {
      [moduleName]: {
        swapProvider: swapProvider,
        weth: wethAddress,
        treasury: treasury as ViemAddress,
      },
    },
  })) as InstitutionWhitelistContracts

  console.log(kleur.green().bold('Institution contracts deployed. Writing institution index...'))

  // gov: only protocolAccessManager for whitelist flow
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
    const registry = await hre.viem.getContractAt(
      'InstitutionalVaultRegistry' as string,
      registryAddress,
    )

    // Compute id via contract helper to avoid encoding inconsistencies
    const institutionBytes32 = (await registry.read.getBytes32InstitutionId([
      institutionId,
    ])) as ViemAddress

    const alreadyExists = (await registry.read.exists([institutionBytes32])) as boolean
    if (alreadyExists) {
      console.log(
        kleur.yellow('Institution already registered in registry. Skipping registration.'),
      )
      return
    }

    const [deployer] = await hre.viem.getWalletClients()
    const owner = (await registry.read.owner()) as string
    if (owner.toLowerCase() !== deployer.account.address.toLowerCase()) {
      console.log(
        kleur.yellow(
          'Caller is not the owner of InstitutionalVaultRegistry. Please register the institution via the owner account.',
        ),
      )
      return
    }

    console.log(kleur.cyan('Registering institution in InstitutionalVaultRegistry...'))
    const publicClient = await hre.viem.getPublicClient()
    const hash = await registry.write.addInstitution([
      institutionBytes32,
      {
        configurationManager: deployed.configurationManager.address,
        protocolAccessManager: deployed.protocolAccessManager.address,
        admiralsQuarters: deployed.admiralsQuarters.address,
        active: true,
      },
    ])
    await publicClient.waitForTransactionReceipt({ hash })
    console.log(kleur.green().bold('Institution successfully registered in registry.'))
  } catch (e) {
    console.error(
      kleur.red(
        `Failed to register institution in registry: ${e instanceof Error ? e.message : String(e)}`,
      ),
    )
  }

  // Grant governor and guardian roles to accounts from institution governance
  try {
    const protocolAccessManager = await hre.viem.getContractAt(
      'ProtocolAccessManager' as string,
      deployed.protocolAccessManager.address,
    )
    const publicClient = await hre.viem.getPublicClient()

    for (const addr of governance.governor) {
      const hash = await protocolAccessManager.write.grantGovernorRole([addr as ViemAddress])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green(`Granted GOVERNOR_ROLE to ${addr}`))
    }

    for (const addr of governance.guardian) {
      const hash = await protocolAccessManager.write.grantGuardianRole([addr as ViemAddress])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green(`Granted GUARDIAN_ROLE to ${addr}`))
    }
  } catch (e) {
    console.error(
      kleur.red(
        `Failed to grant governor/guardian roles: ${e instanceof Error ? e.message : String(e)}`,
      ),
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
