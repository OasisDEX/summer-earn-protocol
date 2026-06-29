import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import { GOVERNOR_ROLE, WHITELIST_MANAGER_ROLE } from '../common/constants'

/**
 * Opens a whitelisted FleetCommander for direct deposits by one or more accounts.
 *
 * A `FleetCommanderWhitelist` rejects a direct (non-operator) deposit unless BOTH:
 *   1. the operator gateway is open (`config.isOperatorGatewayOpen == true`), and
 *   2. the caller (and receiver) are whitelisted for the fleet's context.
 * Otherwise it reverts with `FleetCommanderDirectDepositsClosed()` (gateway) or
 * `NotWhitelisted(address,address)` (whitelist). This script fixes both in one run.
 *
 * Whitelist state lives on the institution's ProtocolAccessManagerV2, scoped by context = the fleet.
 * `setWhitelisted` needs WHITELIST_MANAGER_ROLE; `setOperatorGatewayStatus` needs GOVERNOR_ROLE.
 * The connected wallet (deployer) must hold the relevant role(s) or the matching step is skipped.
 *
 * Usage (env-driven, mirrors the other gov scripts):
 *   FLEET=0x..              # the FleetCommanderWhitelist address (required)
 *   ACCESS_MANAGER=0x..     # the institution ProtocolAccessManagerV2 (required — no on-chain getter)
 *   ACCOUNTS=0x..,0x..      # comma-separated accounts to whitelist (optional; default = signer)
 *   OPEN_GATEWAY=true       # also open the operator gateway (optional; default true)
 *   NETWORK=sepolia_mainnet pnpm gov:open-fleet-for
 */
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
  const openGateway = (process.env.OPEN_GATEWAY ?? 'true').toLowerCase() !== 'false'

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
  console.log(kleur.blue('Open gateway  :'), kleur.cyan(String(openGateway)))

  const pam = await hre.viem.getContractAt('ProtocolAccessManagerV2' as string, accessManager)
  const fleetContract = await hre.viem.getContractAt('FleetCommanderWhitelist' as string, fleet)

  const hasWhitelistManager = (await pam.read.hasRole([WHITELIST_MANAGER_ROLE, signer])) as boolean
  const hasGovernor = (await pam.read.hasRole([GOVERNOR_ROLE, signer])) as boolean

  // 1) Whitelist accounts (context = the fleet) ----------------------------------------------
  if (!hasWhitelistManager) {
    console.log(
      kleur.yellow(
        '! Signer lacks WHITELIST_MANAGER_ROLE — skipping whitelist step. ' +
          'Grant it (governor: grantWhitelistManagerRole) or run as a manager.',
      ),
    )
  } else {
    for (const account of accounts) {
      const already = (await pam.read.isWhitelisted([fleet, account])) as boolean
      if (already) {
        console.log(kleur.gray(`  • ${account} already whitelisted — skipping`))
        continue
      }
      console.log(kleur.blue(`  → whitelisting ${account} ...`))
      const hash = await pam.write.setWhitelisted([fleet, account, true])
      await waitMined(hash)
      console.log(kleur.green(`    ✓ whitelisted (${hash})`))
    }
  }

  // 2) Open the operator gateway -------------------------------------------------------------
  if (openGateway) {
    const config = (await fleetContract.read.config()) as unknown[]
    const isOpen = config[config.length - 1] as boolean // last field = isOperatorGatewayOpen
    if (isOpen) {
      console.log(kleur.gray('  • operator gateway already open — skipping'))
    } else if (!hasGovernor) {
      console.log(
        kleur.yellow(
          '! Signer lacks GOVERNOR_ROLE — cannot open the gateway. ' +
            'Direct deposits stay closed until a governor calls setOperatorGatewayStatus(true).',
        ),
      )
    } else {
      console.log(kleur.blue('  → opening operator gateway ...'))
      const hash = await fleetContract.write.setOperatorGatewayStatus([true])
      await waitMined(hash)
      console.log(kleur.green(`    ✓ gateway opened (${hash})`))
    }
  }

  // 3) Verify --------------------------------------------------------------------------------
  console.log(kleur.blue('\nFinal state:'))
  const finalConfig = (await fleetContract.read.config()) as unknown[]
  console.log(`  isOperatorGatewayOpen: ${finalConfig[finalConfig.length - 1]}`)
  for (const account of accounts) {
    const wl = (await pam.read.isWhitelisted([fleet, account])) as boolean
    console.log(`  isWhitelisted(${account}): ${wl}`)
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
