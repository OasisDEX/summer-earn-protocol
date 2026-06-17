import hre from 'hardhat'
import kleur from 'kleur'
import path from 'node:path'
import prompts from 'prompts'
import { Address, encodePacked, getAddress, keccak256 } from 'viem'
import { BaseConfig } from '../types/config-types'
import { GOVERNOR_ROLE } from './common/constants'
import { GovernorActionBatch } from './common/governor-actions'
import { buildRevokeOperatorRoleAction } from './fleets/fleet-deployment-helpers'
import { getInstitutionConfigByNetwork } from './helpers/config-handler'
import { promptForInstitutionId, readInstitutionConfigFile } from './helpers/institution-config'
import { promptForConfigType } from './helpers/prompt-helpers'
import { validateAddress } from './helpers/validation'

// OPERATOR_ROLE position in IProtocolAccessManager.ContractSpecificRoles
// (CURATOR=0, KEEPER=1, COMMANDER=2, OPERATOR=3).
const OPERATOR_ROLE_INDEX = 3

/**
 * Revokes the OPERATOR contract-specific role from an account on a given fleet.
 *
 * Primary use: a rounds-vaults (RWA) fleet that was first deployed as `admiralsQuarters`
 * still has AdmiralsQuarters holding OPERATOR after a retrofit. For RWA, deposits/withdrawals
 * must flow only through the input/output RoundsVaults, so the AdmiralsQuarters operator
 * grant should be revoked. Defaults the operator to the institution's AdmiralsQuarters.
 *
 * Mirrors the deploy scripts: executes directly when the deployer holds GOVERNOR_ROLE,
 * otherwise captures the action into a Safe Transaction Builder JSON.
 */
async function main() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const useBummerConfig = await promptForConfigType()
  const institutionId = await promptForInstitutionId()
  if (!institutionId) {
    console.log(kleur.red('No institution id provided. Exiting.'))
    return
  }

  const config = getInstitutionConfigByNetwork(
    network,
    institutionId,
    { gov: true, core: true },
    useBummerConfig,
  ) as BaseConfig

  const pamAddress = validateAddress(
    config.deployedContracts.gov.protocolAccessManager?.address,
    'institution protocolAccessManager',
  ) as Address

  // Pick the fleet to operate on from the institution's recorded fleets (avoids address typos).
  const index = readInstitutionConfigFile(institutionId, useBummerConfig) as any
  const fleets = (index?.[network]?.fleets ?? {}) as Record<string, { fleetCommander?: string }>
  const fleetNames = Object.keys(fleets).filter((n) => fleets[n]?.fleetCommander)
  if (fleetNames.length === 0) {
    console.log(kleur.red(`No fleets with a fleetCommander recorded for ${institutionId} on ${network}.`))
    return
  }
  const { fleetName } = await prompts({
    type: 'select',
    name: 'fleetName',
    message: 'Select the fleet to revoke OPERATOR on:',
    choices: fleetNames.map((n) => ({ title: `${n} (${fleets[n].fleetCommander})`, value: n })),
  })
  if (!fleetName) {
    console.log(kleur.red('No fleet selected. Exiting.'))
    return
  }
  const fleetAddress = getAddress(fleets[fleetName].fleetCommander as string)

  // Operator to revoke — defaults to the institution's AdmiralsQuarters, overridable.
  const aqDefault = config.deployedContracts.core.admiralsQuarters?.address
  const { operator } = await prompts({
    type: 'text',
    name: 'operator',
    message: 'Operator address to revoke (default = AdmiralsQuarters):',
    initial: aqDefault ?? '',
    validate: (v: string) => (/^0x[a-fA-F0-9]{40}$/.test(v) ? true : 'Enter a valid address'),
  })
  if (!operator) {
    console.log(kleur.red('No operator provided. Exiting.'))
    return
  }
  const operatorAddress = getAddress(operator)

  const pam = await hre.viem.getContractAt('ProtocolAccessManagerV2' as string, pamAddress)

  // Confirm the operator actually holds OPERATOR on this fleet before queuing a no-op revoke.
  const operatorRole = keccak256(
    encodePacked(['uint8', 'address'], [OPERATOR_ROLE_INDEX, fleetAddress]),
  )
  const holdsRole = (await pam.read.hasRole([operatorRole, operatorAddress])) as boolean
  if (!holdsRole) {
    console.log(
      kleur.yellow(
        `${operatorAddress} does not hold OPERATOR on fleet ${fleetAddress}. Nothing to revoke.`,
      ),
    )
    return
  }

  console.log(kleur.blue('Fleet    :'), kleur.cyan(`${fleetName} ${fleetAddress}`))
  console.log(kleur.blue('Operator :'), kleur.cyan(operatorAddress))
  const proceed = await prompts({
    type: 'confirm',
    name: 'value',
    message: 'Revoke OPERATOR role?',
    initial: true,
  })
  if (!proceed.value) {
    console.log(kleur.red('Cancelled.'))
    return
  }

  const [deployer] = await hre.viem.getWalletClients()
  const hasGovernorRole = (await pam.read.hasRole([
    GOVERNOR_ROLE,
    deployer.account.address,
  ])) as boolean

  const batch = new GovernorActionBatch(
    hasGovernorRole,
    hre,
    `Revoke OPERATOR on ${fleetName} (institution ${institutionId})`,
  )
  await batch.runOrQueue(buildRevokeOperatorRoleAction(pamAddress, fleetAddress, operatorAddress))

  const pending = batch.getPending()
  if (pending.length > 0) {
    const publicClient = await hre.viem.getPublicClient()
    const chainId = await publicClient.getChainId()
    const outRel = path.join(
      'scripts',
      'output',
      `pending-revoke-operator-${network}-${institutionId}-${fleetName.replace(/\W/g, '')}.json`,
    )
    const written = await batch.writeSafeBatch(outRel, Number(chainId))
    console.log(
      kleur
        .yellow()
        .bold(`Deployer lacks GOVERNOR_ROLE — captured for Safe. Import into the Safe UI: ${written}`),
    )
  } else {
    console.log(kleur.green().bold('OPERATOR role revoked on-chain.'))
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
