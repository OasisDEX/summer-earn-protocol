import hre from 'hardhat'
import kleur from 'kleur'
import { Address, keccak256, toBytes } from 'viem'
import { getConfigByNetwork } from '../helpers/config-handler'

const GOVERNOR_ROLE = keccak256(toBytes('GOVERNOR_ROLE'))

export async function finalizeGov(governorAddressesToRevoke: string[] = []) {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
  const config = getConfigByNetwork(hre.network.name, { common: true, gov: true, core: false })

  const summerToken = await hre.viem.getContractAt(
    'SummerToken' as string,
    config.deployedContracts.gov.summerToken.address as Address,
  )
  const summerGovernor = await hre.viem.getContractAt(
    'SummerGovernor' as string,
    config.deployedContracts.gov.summerGovernor.address as Address,
  )
  const timelock = await hre.viem.getContractAt(
    'TimelockController' as string,
    config.deployedContracts.gov.timelock.address as Address,
  )
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )
  const publicClient = await hre.viem.getPublicClient()

  // Transfer SummerToken ownership to timelock
  console.log(kleur.cyan().bold('Transferring SummerToken ownership to timelock...'))
  const currentTokenOwner = (await summerToken.read.owner()) as Address
  if (
    currentTokenOwner.toLowerCase() ===
    (await hre.viem.getWalletClients())[0].account.address.toLowerCase()
  ) {
    const hash = await summerToken.write.transferOwnership([timelock.address])
    await publicClient.waitForTransactionReceipt({ hash })
    console.log(kleur.green('✓ SummerToken ownership transferred to timelock'))
  } else {
    console.log(kleur.yellow('! SummerToken ownership already transferred'))
  }

  // Transfer SummerGovernor ownership to timelock
  console.log(kleur.cyan().bold('\nTransferring SummerGovernor ownership to timelock...'))
  const currentGovernorOwner = (await summerGovernor.read.owner()) as Address
  if (
    currentGovernorOwner.toLowerCase() ===
    (await hre.viem.getWalletClients())[0].account.address.toLowerCase()
  ) {
    const hash = await summerGovernor.write.transferOwnership([timelock.address])
    await publicClient.waitForTransactionReceipt({ hash })
    console.log(kleur.green('✓ SummerGovernor ownership transferred to timelock'))
  } else {
    console.log(kleur.yellow('! SummerGovernor ownership already transferred'))
  }

  // Revoke governor roles from additional addresses
  if (governorAddressesToRevoke.length > 0) {
    console.log(kleur.cyan().bold('\nRevoking governor roles from additional addresses...'))
    for (const address of governorAddressesToRevoke) {
      const hasRole = await protocolAccessManager.read.hasRole([GOVERNOR_ROLE, address])
      if (hasRole) {
        console.log(`[PROTOCOL ACCESS MANAGER] - Revoking governor role from ${address}...`)
        const hash = await protocolAccessManager.write.revokeGovernorRole([address])
        await publicClient.waitForTransactionReceipt({ hash })
        console.log(kleur.green(`✓ Governor role revoked from ${address}`))
      } else {
        console.log(kleur.yellow(`! Address ${address} does not have governor role`))
      }
    }
  }

  console.log(kleur.green().bold('\nGovernance finalization completed!'))
}

if (require.main === module) {
  const args = process.argv.slice(2)
  const governorAddressesToRevoke = args.length > 0 ? args : []

  finalizeGov(governorAddressesToRevoke).catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
