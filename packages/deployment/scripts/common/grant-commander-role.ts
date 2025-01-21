import { HardhatRuntimeEnvironment } from 'hardhat/types'
import kleur from 'kleur'
import { Address } from 'viem'
import { GOVERNOR_ROLE } from './constants'

/**
 * Grants the commander role for the buffer ark to the fleet commander.
 * @param {Address} protocolAccessManagerAddress - The address of the ProtocolAccessManager contract.
 * @param {Address} arkAddress - The address of an ark.
 * @param {Address} fleetCommanderAddress - The address of the fleet commander.
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
    `ProtocolAccessManager` as string,
    protocolAccessManagerAddress,
  )
  const role = await protocolAccessManager.read.generateRole([2, arkAddress])
  const hasRole = await protocolAccessManager.read.hasRole([role, fleetCommanderAddress])
  const hasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    deployer.account.address,
  ])
  if (!hasRole) {
    if (hasGovernorRole) {
      console.log(kleur.red().bold('Granting commander role for ark to fleet commander'))
      const hash = await protocolAccessManager.write.grantCommanderRole([
        arkAddress,
        fleetCommanderAddress,
      ])
      await publicClient.waitForTransactionReceipt({
        hash: hash,
      })
    } else {
      console.log(kleur.red('Deployer does not have GOVERNOR_ROLE in ProtocolAccessManager'))
      console.log(
        kleur.red(
          `Please grant the commander role for the ark (${arkAddress}) to the fleet commander (${fleetCommanderAddress}) via governance.\n grantCommanderRole(${arkAddress}, ${fleetCommanderAddress})`,
        ),
      )
    }
  }
}
