import { HardhatRuntimeEnvironment } from 'hardhat/types'
import kleur from 'kleur'
import { Address } from 'viem'
import { getGovernorClient } from './governance-utils'

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

  // Use the getGovernorClient helper to find a governor
  const governorClient = await getGovernorClient(hre, protocolAccessManagerAddress)

  if (!governorClient) {
    console.log(kleur.red('No governor account found among the first 10 deployers.'))
    console.log(
      kleur.yellow(
        `Please grant COMMANDER_ROLE for Ark ${arkAddress} to Fleet Commander ${fleetCommanderAddress} via governance`,
      ),
    )
    return
  }

  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    protocolAccessManagerAddress,
  )

  console.log(
    kleur.yellow(
      `Granting COMMANDER_ROLE to Fleet Commander ${fleetCommanderAddress} for Ark ${arkAddress} using governor ${governorClient.account?.address}`,
    ),
  )

  try {
    // Use the grantCommanderRole function that takes arkAddress and account
    const hash = await protocolAccessManager.write.grantCommanderRole(
      [arkAddress, fleetCommanderAddress],
      { account: governorClient.account },
    )

    await publicClient.waitForTransactionReceipt({ hash, confirmations: 2 })
    console.log(kleur.green('Successfully granted COMMANDER_ROLE'))
  } catch (error) {
    console.error(kleur.red('Failed to grant COMMANDER_ROLE:'), error)
    throw error
  }
}
