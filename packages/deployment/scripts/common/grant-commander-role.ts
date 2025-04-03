import { HardhatRuntimeEnvironment } from 'hardhat/types'
import kleur from 'kleur'
import { Address } from 'viem'

/**
 * Grants the COMMANDER_ROLE to a Fleet Commander for a specific Ark
 * @param protocolAccessManagerAddress - Address of the ProtocolAccessManager contract
 * @param arkAddress - Address of the Ark contract
 * @param fleetCommanderAddress - Address of the Fleet Commander to receive the role
 * @param hre - Hardhat Runtime Environment
 */
export async function grantCommanderRole(
  protocolAccessManagerAddress: Address,
  arkAddress: Address,
  fleetCommanderAddress: Address,
  hre: HardhatRuntimeEnvironment,
) {
  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()

  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    protocolAccessManagerAddress,
  )

  console.log(
    kleur.yellow(
      `Granting COMMANDER_ROLE to Fleet Commander ${fleetCommanderAddress} for Ark ${arkAddress}`,
    ),
  )

  try {
    // Use the grantCommanderRole function that takes arkAddress and account
    const hash = await protocolAccessManager.write.grantCommanderRole([
      arkAddress,
      fleetCommanderAddress,
    ])

    await publicClient.waitForTransactionReceipt({ hash })
    console.log(kleur.green('Successfully granted COMMANDER_ROLE'))
  } catch (error) {
    console.error(kleur.red('Failed to grant COMMANDER_ROLE:'), error)
    throw error
  }
}
