import hre from 'hardhat'
import kleur from 'kleur'

import { Address as ViemAddress, getAddress } from 'viem'
import { createInstitutionWhitelistModule } from '../ignition/modules/institution-whitelist'
import { BaseConfig } from '../types/config-types'
import { GOVERNOR_ROLE } from './common/constants'
import { getConfigByNetwork, getInstitutionConfigByNetwork } from './helpers/config-handler'
import {
  promptForInstitutionId,
  readInstitutionGovernance,
  readInstitutionTimelockConfig,
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

  // Read timelock delays (both timelocks are always deployed; delays may be 0 = immediate).
  const timelockConfig = readInstitutionTimelockConfig(
    institutionId,
    useBummerConfig,
    hre.network.name,
  )
  console.log(
    kleur.blue('Timelock delays (seconds):'),
    kleur.cyan(`governor=${timelockConfig.governorDelay}, curator=${timelockConfig.curatorDelay}`),
  )

  // Proposers for each timelock are segregated: the governor timelock is proposed to by the
  // institution governors, the curator timelock by the institution curators (a separate set; it
  // falls back to the governors when `curators` is not configured). The deployer is intentionally
  // NOT a proposer — during deployment it acts directly as the bootstrap governor and hands over
  // to the governor timelock only at the end (see the separate handover script). Executors are
  // left open at the contract level.
  const dedupeAddresses = (addrs: string[]): ViemAddress[] =>
    Array.from(new Set(addrs.map((a) => a.toLowerCase()))).map((a) => getAddress(a))

  const governorTimelockProposers = dedupeAddresses(governance.governor)
  const curatorTimelockProposers = dedupeAddresses(
    governance.curators.length > 0 ? governance.curators : governance.governor,
  )
  if (governorTimelockProposers.length === 0) {
    console.log(
      kleur.yellow(
        'Warning: no governors configured — the governor timelock will have no proposers and cannot schedule operations.',
      ),
    )
  }
  if (curatorTimelockProposers.length === 0) {
    console.log(
      kleur.yellow(
        'Warning: no curators configured — the curator timelock will have no proposers and cannot schedule operations.',
      ),
    )
  }

  const envLabel = useBummerConfig ? 'staging_' : ''
  const moduleName = `${envLabel}InstitutionWhitelist_${institutionId}`

  const InstitutionModule = createInstitutionWhitelistModule(moduleName)
  const deployed = await hre.ignition.deploy(InstitutionModule, {
    parameters: {
      [moduleName]: {
        swapProvider: swapProvider,
        weth: wethAddress,
        treasury: treasury as ViemAddress,
        governorDelay: timelockConfig.governorDelay,
        curatorDelay: timelockConfig.curatorDelay,
        governorTimelockProposers: governorTimelockProposers,
        curatorTimelockProposers: curatorTimelockProposers,
      },
    },
  })
  console.log(kleur.green().bold('Institution contracts deployed. Writing institution index...'))

  // gov: protocolAccessManagerV2 + the two RwaTimelock instances for the whitelist flow
  updateInstitutionDeployedContracts(institutionId, useBummerConfig, hre.network.name, 'gov', {
    protocolAccessManager: { address: deployed.protocolAccessManager.address },
    governorTimelock: { address: deployed.governorTimelock.address },
    curatorTimelock: { address: deployed.curatorTimelock.address },
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
    const owner = (await registry.read.owner()) as string
    const deployers = await hre.viem.getWalletClients()
    for (const deployer of deployers) {
      if (owner.toLowerCase() !== deployer.account.address.toLowerCase()) {
        console.log(
          kleur.yellow(
            'Caller is not the owner of InstitutionalVaultRegistry V2. Please register the institution via the owner account.',
          ),
        )
        continue
      }

      console.log(kleur.cyan('Registering institution in InstitutionalVaultRegistry V2...'))
      const publicClient = await hre.viem.getPublicClient()
      const hash = await registry.write.addInstitution(
        [
          institutionBytes32,
          {
            configurationManager: deployed.configurationManager.address,
            protocolAccessManager: deployed.protocolAccessManager.address,
            admiralsQuarters: deployed.admiralsQuarters.address,
          },
        ],
        { account: deployer.account },
      )
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green().bold('Institution successfully registered in registry V2.'))
    }
  } catch (e) {
    console.error(
      kleur.red(
        `Failed to register institution in registry V2: ${e instanceof Error ? e.message : String(e)}`,
      ),
    )
  }

  // Grant guardian/superKeeper/whitelistManager roles directly (the deployer is the bootstrap
  // governor), and grant GOVERNOR_ROLE to the governor timelock so it is ready to take over. The
  // deployer KEEPS its bootstrap GOVERNOR_ROLE here so it can wire fleets directly in subsequent
  // deploys; it renounces only at the end, via the separate handover script
  // (handover-institution-timelock.ts), which is what makes the timelock the sole governor. The
  // institution governors do not receive GOVERNOR_ROLE directly — they are the timelock proposers
  // (see timelockProposers above).
  try {
    const protocolAccessManagerV2 = await hre.viem.getContractAt(
      'ProtocolAccessManagerV2' as string,
      deployed.protocolAccessManager.address,
    )
    const publicClient = await hre.viem.getPublicClient()

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

    // Grant GOVERNOR_ROLE to the governor timelock so it is ready to act. The deployer is NOT
    // renounced here — run handover-institution-timelock.ts after all fleets are deployed to
    // renounce the deployer and leave the timelock as the sole governor.
    const governorTimelockAddress = getAddress(deployed.governorTimelock.address)

    const timelockAlreadyGovernor = (await protocolAccessManagerV2.read.hasRole([
      GOVERNOR_ROLE,
      governorTimelockAddress,
    ])) as boolean
    if (timelockAlreadyGovernor) {
      console.log(kleur.gray(`[skip] GOVERNOR_ROLE already held by governor timelock`))
    } else {
      const hash = await protocolAccessManagerV2.write.grantGovernorRole([governorTimelockAddress])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(
        kleur.green(`Granted GOVERNOR_ROLE to governor timelock ${governorTimelockAddress}`),
      )
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
