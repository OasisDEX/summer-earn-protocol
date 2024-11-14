import { HardhatRuntimeEnvironment } from 'hardhat/types'
import kleur from 'kleur'
import { Address } from 'viem'

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
  const protocolAccessManager = await hre.viem.getContractAt(
    `ProtocolAccessManager` as string,
    protocolAccessManagerAddress,
  )
  const role = await protocolAccessManager.read.generateRole([2, arkAddress])
  const hasRole = await protocolAccessManager.read.hasRole([role, fleetCommanderAddress])
  if (!hasRole) {
    console.log(kleur.red().bold('Granting commander role for buffer ark to fleet commander'))
    const hash = await protocolAccessManager.write.grantCommanderRole([
      arkAddress,
      fleetCommanderAddress,
    ])
    await publicClient.waitForTransactionReceipt({
      hash: hash,
    })
  }
}
