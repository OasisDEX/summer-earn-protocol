import hre from 'hardhat'
import kleur from 'kleur'
import { Address as ViemAddress, getAddress } from 'viem'

import { BaseConfig } from '../types/config-types'
import { GOVERNOR_ROLE, WHITELIST_MANAGER_ROLE } from './common/constants'
import { getInstitutionConfigByNetwork } from './helpers/config-handler'
import {
  promptForInstitutionId,
  readInstitutionConfigFile,
  readInstitutionGovernance,
  readInstitutionTimelockConfig,
} from './helpers/institution-config'
import { promptForConfigType } from './helpers/prompt-helpers'
import { assertTimelockUsable, computeTimelockProposers } from './helpers/timelock'
import { validateAddress } from './helpers/validation'

// Position of CURATOR_ROLE in access-contracts IProtocolAccessManager.ContractSpecificRoles.
const CURATOR_ROLE_INDEX = 0

/**
 * Final timelock handover for an institution.
 *
 * Run this ONCE, after the institution and all its fleets have been deployed. By then the deployer
 * has acted as the bootstrap governor and granted every role directly. This script:
 *   0. verifies each recorded timelock has code, the configured minDelay, and that its expected
 *      proposers hold PROPOSER_ROLE (so the renounce cannot brick or misassign governance),
 *   1. ensures the governor timelock holds GOVERNOR_ROLE (idempotent),
 *   2. requires the curator timelock to hold CURATOR_ROLE on each of >= 1 fleets,
 *   3. revokes the deployer's WHITELIST_MANAGER_ROLE (seeded by the PAM V2 constructor),
 *   4. warns loudly about any configured governor EOA that still holds GOVERNOR_ROLE directly, and
 *   5. renounces the deployer's GOVERNOR_ROLE — leaving the governor timelock as the SOLE governor.
 *
 * Note: AdmiralsQuarters' Ownable owner is intentionally left as-is (not transferred here).
 */
async function main() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  const useBummerConfig = await promptForConfigType()
  const institutionId = await promptForInstitutionId()
  if (!institutionId) {
    console.log(kleur.red('No institution id provided. Exiting.'))
    return
  }

  const config = getInstitutionConfigByNetwork(
    hre.network.name,
    institutionId,
    { gov: true, core: true },
    useBummerConfig,
  ) as BaseConfig

  const pamAddress = validateAddress(
    config.deployedContracts.gov.protocolAccessManager?.address,
    'institution protocolAccessManager',
  ) as ViemAddress
  const governorTimelock = validateAddress(
    config.deployedContracts.gov.governorTimelock?.address,
    'institution governorTimelock',
  ) as ViemAddress
  const curatorTimelock = config.deployedContracts.gov.curatorTimelock?.address as
    | ViemAddress
    | undefined

  const timelockConfig = readInstitutionTimelockConfig(
    institutionId,
    useBummerConfig,
    hre.network.name,
  )
  console.log(
    kleur.blue('Timelock delays (seconds):'),
    kleur.cyan(`governor=${timelockConfig.governorDelay}, curator=${timelockConfig.curatorDelay}`),
  )

  const pam = await hre.viem.getContractAt('ProtocolAccessManagerV2' as string, pamAddress)
  const publicClient = await hre.viem.getPublicClient()
  const [deployerWallet] = await hre.viem.getWalletClients()
  const deployer = getAddress(deployerWallet.account.address)

  // Expected proposer sets for the two timelocks — the accounts that MUST be able to schedule once
  // the deployer renounces. Same derivation as the deploy script.
  const governance = readInstitutionGovernance(institutionId, useBummerConfig, hre.network.name)
  const { governorProposers, curatorProposers } = computeTimelockProposers(governance)

  // 0. Verify the recorded timelock addresses on-chain BEFORE any irreversible role change: each
  //    must have code, report the configured minDelay, AND grant PROPOSER_ROLE to its expected
  //    proposers. Verifying the delay alone is not enough — a stale/typo'd address, or a real
  //    timelock whose proposers don't match the configured governors/curators, would otherwise be
  //    handed sole GOVERNOR_ROLE and permanently brick (or misassign) the institution's governance.
  await assertTimelockUsable(
    'governor timelock',
    governorTimelock,
    timelockConfig.governorDelay,
    governorProposers,
    publicClient,
  )
  if (curatorTimelock) {
    await assertTimelockUsable(
      'curator timelock',
      curatorTimelock,
      timelockConfig.curatorDelay,
      curatorProposers,
      publicClient,
    )
  }

  // 1. Verify the curator timelock holds CURATOR_ROLE on EVERY fleet before changing any role.
  //    The curator timelock is mandatory, and handover must run only after every fleet is deployed
  //    — otherwise the deployer renounces GOVERNOR_ROLE while the institution is incompletely wired.
  if (!curatorTimelock) {
    throw new Error(
      `No curator timelock recorded for institution "${institutionId}" on network ` +
        `"${hre.network.name}". Timelocks are mandatory — re-run the institution deploy so the ` +
        `curator timelock is recorded before handover.`,
    )
  }
  const index = readInstitutionConfigFile(institutionId, useBummerConfig)
  const fleets = index[hre.network.name]?.fleets ?? {}
  if (Object.keys(fleets).length === 0) {
    throw new Error(
      `Institution "${institutionId}" has no fleets recorded on network "${hre.network.name}". ` +
        `Handover renounces the deployer's GOVERNOR_ROLE and must run only AFTER all fleets are ` +
        `deployed — otherwise the deployer could no longer wire fleets directly. Deploy the fleets ` +
        `first, then retry.`,
    )
  }
  const missingFleets: { name: string; fleetCommander: string }[] = []
  for (const [fleetName, entry] of Object.entries(fleets)) {
    const role = (await pam.read.generateRole([
      CURATOR_ROLE_INDEX,
      entry.fleetCommander as ViemAddress,
    ])) as `0x${string}`
    const hasCurator = (await pam.read.hasRole([role, curatorTimelock])) as boolean
    if (hasCurator) {
      console.log(kleur.gray(`[ok] curator timelock holds CURATOR_ROLE on ${fleetName}`))
    } else {
      missingFleets.push({ name: fleetName, fleetCommander: entry.fleetCommander })
    }
  }
  if (missingFleets.length > 0) {
    const list = missingFleets.map((f) => `  - ${f.name} (${f.fleetCommander})`).join('\n')
    throw new Error(
      `Curator timelock ${curatorTimelock} is missing CURATOR_ROLE on ${missingFleets.length} ` +
        `of the institution's fleets:\n${list}\n` +
        `Aborting handover — no roles were changed. Re-run the fleet deploy for the listed ` +
        `fleets so the curator timelock is granted CURATOR_ROLE, then retry.`,
    )
  }
  console.log(kleur.green('Curator timelock holds CURATOR_ROLE on all fleets.'))

  // 2. Ensure the governor timelock holds GOVERNOR_ROLE before we drop the deployer's.
  const timelockIsGovernor = (await pam.read.hasRole([GOVERNOR_ROLE, governorTimelock])) as boolean
  if (timelockIsGovernor) {
    console.log(kleur.gray(`[skip] governor timelock already holds GOVERNOR_ROLE`))
  } else {
    const deployerIsGovernor = (await pam.read.hasRole([GOVERNOR_ROLE, deployer])) as boolean
    if (!deployerIsGovernor) {
      throw new Error(
        'Governor timelock does not hold GOVERNOR_ROLE and the deployer is not a governor — cannot complete handover. Re-run the institution deploy or grant the timelock GOVERNOR_ROLE first.',
      )
    }
    const hash = await pam.write.grantGovernorRole([governorTimelock])
    await publicClient.waitForTransactionReceipt({ hash })
    console.log(kleur.green(`Granted GOVERNOR_ROLE to governor timelock ${governorTimelock}`))
  }

  // 3. Revoke the deployer's WHITELIST_MANAGER_ROLE (seeded by the PAM V2 constructor) — but ONLY
  //    if another configured whitelist manager already holds the role on-chain. Whitelisting
  //    (setWhitelisted/...) is gated by WHITELIST_MANAGER_ROLE, not by governor; if we dropped the
  //    deployer with no other manager, nobody could whitelist and restoring it would require a
  //    governor-timelock proposal. This revoke runs while the deployer is still a governor.
  const deployerIsWhitelistManager = (await pam.read.hasRole([
    WHITELIST_MANAGER_ROLE,
    deployer,
  ])) as boolean
  if (deployerIsWhitelistManager) {
    const otherManagers = governance.whitelistManagers
      .map((a) => getAddress(a))
      .filter((a) => a.toLowerCase() !== deployer.toLowerCase())

    let remainingManagerExists = false
    for (const manager of otherManagers) {
      if ((await pam.read.hasRole([WHITELIST_MANAGER_ROLE, manager])) as boolean) {
        remainingManagerExists = true
        break
      }
    }

    if (remainingManagerExists) {
      const hash = await pam.write.revokeWhitelistManagerRole([deployer])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green(`Revoked deployer WHITELIST_MANAGER_ROLE (${deployer})`))
    } else {
      console.log(
        kleur
          .yellow()
          .bold(
            `[keep] Not revoking deployer WHITELIST_MANAGER_ROLE: no other configured whitelist ` +
              `manager holds the role on-chain. Configure whitelistManagers[] and grant one (via ` +
              `the governor timelock) before revoking, or the system would have no whitelist manager.`,
          ),
      )
    }
  } else {
    console.log(kleur.gray(`[skip] deployer does not hold WHITELIST_MANAGER_ROLE`))
  }

  // 4. Loudly surface any configured governor EOA that STILL holds GOVERNOR_ROLE directly on the
  //    PAM. On institutions deployed before the timelock flow these were granted directly and are
  //    NOT revoked here — they BYPASS the governor timelock, so it is not truly the sole governor
  //    until they are revoked (via a governor-timelock proposal). This script does not revoke them.
  const directGovernors: string[] = []
  for (const configuredGovernor of governance.governor) {
    const ga = getAddress(configuredGovernor)
    if (ga.toLowerCase() === deployer.toLowerCase()) continue
    if ((await pam.read.hasRole([GOVERNOR_ROLE, ga])) as boolean) directGovernors.push(ga)
  }
  if (directGovernors.length > 0) {
    const list = directGovernors.map((d) => `  - ${d}`).join('\n')
    console.log(
      kleur
        .yellow()
        .bold(
          `[warn] ${directGovernors.length} configured governor EOA(s) still hold GOVERNOR_ROLE ` +
            `DIRECTLY and BYPASS the governor timelock:\n${list}\n` +
            `The governor timelock is NOT the sole governor until these are revoked (do so via a ` +
            `governor-timelock proposal). This script does not revoke them automatically.`,
        ),
    )
  }

  // 5. Renounce the deployer's GOVERNOR_ROLE — the governor timelock becomes the sole governor.
  const deployerStillGovernor = (await pam.read.hasRole([GOVERNOR_ROLE, deployer])) as boolean
  if (deployerStillGovernor) {
    const hash = await pam.write.revokeGovernorRole([deployer])
    await publicClient.waitForTransactionReceipt({ hash })
    console.log(
      kleur
        .green()
        .bold(
          `Renounced deployer GOVERNOR_ROLE (${deployer}). Governor timelock ${governorTimelock} is now the sole governor.`,
        ),
    )
  } else {
    console.log(kleur.gray(`[skip] deployer no longer holds GOVERNOR_ROLE — handover already done`))
  }

  console.log(
    kleur.blue(
      'Note: AdmiralsQuarters Ownable owner was not changed by this script (intentionally retained).',
    ),
  )
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
