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

/**
 * Idempotently ensures the governor timelock holds GOVERNOR_ROLE. Safe to call on a fresh deploy
 * (deployer is the bootstrap governor) and on a re-run of an already-registered institution (a
 * prior run may have stopped before this grant). If the timelock lacks the role and the deployer
 * is not a governor, it warns instead of reverting — the grant must then go through the existing
 * governor (or the governor timelock itself).
 */
async function ensureGovernorTimelockIsGovernor(
  pam: any,
  publicClient: any,
  governorTimelockAddress: ViemAddress,
  deployerAddress: ViemAddress,
): Promise<void> {
  const timelockAlreadyGovernor = (await pam.read.hasRole([
    GOVERNOR_ROLE,
    governorTimelockAddress,
  ])) as boolean
  if (timelockAlreadyGovernor) {
    console.log(kleur.gray('[skip] GOVERNOR_ROLE already held by governor timelock'))
    return
  }

  const deployerIsGovernor = (await pam.read.hasRole([GOVERNOR_ROLE, deployerAddress])) as boolean
  if (!deployerIsGovernor) {
    console.log(
      kleur
        .yellow()
        .bold(
          `Governor timelock ${governorTimelockAddress} does NOT hold GOVERNOR_ROLE and the ` +
            `deployer is not a governor — grant it via the current governor (or the governor timelock).`,
        ),
    )
    return
  }

  const hash = await pam.write.grantGovernorRole([governorTimelockAddress])
  await publicClient.waitForTransactionReceipt({ hash })
  console.log(kleur.green(`Granted GOVERNOR_ROLE to governor timelock ${governorTimelockAddress}`))
}

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

  // Read and validate governance + timelock config up front — before any on-chain state changes
  // or contract deployments — so a misconfiguration fails fast and leaves nothing half-wired.
  const governance = readInstitutionGovernance(institutionId, useBummerConfig, hre.network.name)
  const treasury = governance.treasury

  // Timelock delays (both timelocks are always deployed; delays may be 0 = immediate).
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
  // Fail fast if either timelock would have no proposers. A proposer-less timelock can never
  // schedule operations and would be permanently stuck.
  if (governorTimelockProposers.length === 0) {
    throw new Error(
      `No governor timelock proposers for institution "${institutionId}" on network "${hre.network.name}". ` +
        `Configure "governor" in the institution index before deploying.`,
    )
  }
  if (curatorTimelockProposers.length === 0) {
    throw new Error(
      `No curator timelock proposers for institution "${institutionId}" on network "${hre.network.name}". ` +
        `Configure "curators" (or "governor" as fallback) in the institution index before deploying.`,
    )
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

    // Even when the contracts are already deployed and registered, make sure the governor timelock
    // holds GOVERNOR_ROLE — a previous run may have stopped before that grant.
    const governorTimelockAddress = institutionConfig.deployedContracts.gov.governorTimelock?.address
    const existingPamAddress = institutionConfig.deployedContracts.gov.protocolAccessManager?.address
    if (governorTimelockAddress && existingPamAddress) {
      const pam = await hre.viem.getContractAt(
        'ProtocolAccessManagerV2' as string,
        existingPamAddress as ViemAddress,
      )
      const [deployerWallet] = await hre.viem.getWalletClients()
      await ensureGovernorTimelockIsGovernor(
        pam,
        publicClient,
        governorTimelockAddress as ViemAddress,
        getAddress(deployerWallet.account.address),
      )
    } else {
      console.log(
        kleur.yellow(
          'No governor timelock recorded for this institution — was it deployed before the timelock flow? Skipping timelock governor check.',
        ),
      )
    }
    return
  }

  if (exists && !addressessMatch) {
    // remove institution from registry
    const hash = await registry.write.removeInstitution([institutionBytes32])
    await publicClient.waitForTransactionReceipt({ hash })
    console.log(kleur.green().bold('Institution successfully removed from registry V2.'))
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
    const [deployerWallet] = await hre.viem.getWalletClients()
    await ensureGovernorTimelockIsGovernor(
      protocolAccessManagerV2,
      publicClient,
      getAddress(deployed.governorTimelock.address),
      getAddress(deployerWallet.account.address),
    )
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
