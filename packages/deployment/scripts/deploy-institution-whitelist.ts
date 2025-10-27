import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address as ViemAddress } from 'viem'
import {
  InstitutionWhitelistContracts,
  InstitutionWhitelistModule,
} from '../ignition/modules/institution-whitelist'
import { BaseConfig } from '../types/config-types'
import { ADDRESS_ZERO } from './common/constants'
import { getConfigByNetwork } from './lib/config/handler'
import {
  promptForInstitutionId,
  updateInstitutionDeployedContracts,
} from './lib/config/institution'
import { promptForConfigType } from './lib/infrastructure/prompts'
import { AddressSchema } from './lib/infrastructure/zod-schemas'

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
  const registryAddress = config.deployedContracts.core.institutionalVaultRegistry?.address
  if (!registryAddress || registryAddress == ADDRESS_ZERO) {
    console.log(
      kleur.red(
        'InstitutionalVaultRegistry address not found in base config. Please deploy and configure it before proceeding.',
      ),
    )
    return
  }

  console.log(kleur.cyan().bold('Deploying Institution Whitelist...'))
  // Prompt for treasury (institution-specific) and validate with Zod Address
  const { treasury } = await prompts({
    type: 'text',
    name: 'treasury',
    message: 'Enter treasury address for this institution:',
    validate: (v) => (AddressSchema.safeParse(v).success ? true : 'Invalid address'),
  })

  const deployed = (await hre.ignition.deploy(InstitutionWhitelistModule, {
    parameters: {
      InstitutionWhitelistModule: {
        swapProvider: config.common.swapProvider,
        weth: config.tokens.weth,
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
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
