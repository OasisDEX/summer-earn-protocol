import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import { getConfigByNetwork } from '../helpers/config-handler'

export async function finalizeGov() {
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

  console.log(kleur.green().bold('\nGovernance finalization completed!'))
}

if (require.main === module) {
  finalizeGov().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
