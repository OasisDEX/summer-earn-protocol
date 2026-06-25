import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import { GOVERNOR_ROLE } from '../common/constants'

/**
 * Grants fleet-scoped contract-specific roles (CURATOR and/or KEEPER) to one or more accounts.
 *
 * Why: the fleet config setters are gated by these roles, and Governor does NOT bypass them:
 *   - setArkDepositCap / setArkMaxRebalanceInflow / setArkMaxRebalanceOutflow → onlyCurator
 *     (revert: CallerIsNotCurator(address) — 0xc76a5dae)
 *   - rebalance / adjustBuffer → onlyKeeper
 *     (revert: CallerIsNotKeeper(address) — 0xa41a3a04)
 * Each role is scoped to a single fleet via generateRole(role, fleet), so it must be granted
 * per-fleet on the institution's ProtocolAccessManager. Granting needs GOVERNOR_ROLE.
 *
 * Usage (env-driven, mirrors the other gov scripts):
 *   FLEET=0x..              # the FleetCommander address the roles are scoped to (required)
 *   ACCESS_MANAGER=0x..     # the institution ProtocolAccessManager(V2) (required — no on-chain getter)
 *   ACCOUNTS=0x..,0x..      # comma-separated grantees (optional; default = signer)
 *   ROLES=curator,keeper    # which roles to grant (optional; default = both)
 *   NETWORK=sepolia_mainnet pnpm gov:grant-fleet-roles
 */

// ContractSpecificRoles enum (IProtocolAccessManager): CURATOR=0, KEEPER=1, COMMANDER=2, OPERATOR=3.
const ROLE_INDEX: Record<string, number> = { curator: 0, keeper: 1 }
// Convenience grant function per role on the access manager.
const GRANT_FN: Record<string, string> = {
  curator: 'grantCuratorRole',
  keeper: 'grantKeeperRole',
}

async function main() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const fleetEnv = process.env.FLEET
  const amEnv = process.env.ACCESS_MANAGER
  if (!fleetEnv || !amEnv) {
    throw new Error('FLEET and ACCESS_MANAGER env vars are required.')
  }
  const fleet = getAddress(fleetEnv)
  const accessManager = getAddress(amEnv)

  const roles = (process.env.ROLES ? process.env.ROLES.split(',') : ['curator', 'keeper'])
    .map((r) => r.trim().toLowerCase())
    .filter(Boolean)
  for (const role of roles) {
    if (!(role in ROLE_INDEX)) {
      throw new Error(`Unknown role "${role}". Supported: ${Object.keys(ROLE_INDEX).join(', ')}.`)
    }
  }

  const [deployer] = await hre.viem.getWalletClients()
  const signer = getAddress(deployer.account.address)

  const accounts = (process.env.ACCOUNTS ? process.env.ACCOUNTS.split(',') : [signer])
    .map((a) => a.trim())
    .filter(Boolean)
    .map(getAddress)

  console.log(kleur.blue('Signer        :'), kleur.cyan(signer))
  console.log(kleur.blue('Fleet         :'), kleur.cyan(fleet))
  console.log(kleur.blue('AccessManager :'), kleur.cyan(accessManager))
  console.log(kleur.blue('Accounts      :'), kleur.cyan(accounts.join(', ')))
  console.log(kleur.blue('Roles         :'), kleur.cyan(roles.join(', ')))

  const pam = await hre.viem.getContractAt('ProtocolAccessManagerV2' as string, accessManager)
  const fleetContract = await hre.viem.getContractAt('FleetCommanderWhitelist' as string, fleet)

  const hasGovernor = (await pam.read.hasRole([GOVERNOR_ROLE, signer])) as boolean
  if (!hasGovernor) {
    throw new Error(
      `Signer ${signer} lacks GOVERNOR_ROLE on ${accessManager}; cannot grant fleet roles.`,
    )
  }

  // Precompute the fleet-scoped role hash for each requested role (for read-back checks).
  const roleHashes: Record<string, `0x${string}`> = {}
  for (const role of roles) {
    roleHashes[role] = (await fleetContract.read.generateRole([
      ROLE_INDEX[role],
      fleet,
    ])) as `0x${string}`
  }

  for (const account of accounts) {
    for (const role of roles) {
      const already = (await pam.read.hasRole([roleHashes[role], account])) as boolean
      if (already) {
        console.log(kleur.gray(`  • ${account} already has ${role} — skipping`))
        continue
      }
      console.log(kleur.blue(`  → granting ${role} to ${account} ...`))
      const hash = (await (pam.write as any)[GRANT_FN[role]]([
        fleet,
        account,
      ])) as `0x${string}`
      await waitMined(hash)
      console.log(kleur.green(`    ✓ ${role} granted (${hash})`))
    }
  }

  // Verify ------------------------------------------------------------------------------------
  console.log(kleur.blue('\nFinal state:'))
  for (const account of accounts) {
    for (const role of roles) {
      const has = (await pam.read.hasRole([roleHashes[role], account])) as boolean
      console.log(`  ${account} ${role}: ${has}`)
    }
  }
  console.log(kleur.green().bold('\nDone.'))
}

async function waitMined(hash: `0x${string}`) {
  const publicClient = await hre.viem.getPublicClient()
  await publicClient.waitForTransactionReceipt({ hash })
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
