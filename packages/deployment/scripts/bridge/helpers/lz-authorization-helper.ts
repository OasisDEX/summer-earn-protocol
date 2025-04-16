import kleur from 'kleur'
import { Address } from 'viem'
import { getChainPublicClient } from '../../helpers/client-by-chain-helper'
import { LZ_ENDPOINT_ABI } from '../lz-endpoint-abi'

/**
 * Check if the current deployer is authorized by the LZ endpoint
 * @param lzEndpointAddress The address of the LZ endpoint contract
 * @param oAppAddress The address of the OApp
 * @param deployerAddress The address of the deployer to check authorization for
 * @param chainName Optional chain name for logging purposes
 * @returns An object containing the delegate address and whether the deployer is authorized
 */
export async function checkLzAuthorization(
  lzEndpointAddress: Address,
  oAppAddress: Address,
  deployerAddress: Address,
  chainName: string,
): Promise<{ delegate: Address; isAuthorized: boolean }> {
  const publicClient = await getChainPublicClient(chainName)

  console.log(kleur.blue('Checking LZ authorization for OApp:'), kleur.cyan(oAppAddress))
  console.log(kleur.blue('Using deployer:'), kleur.cyan(deployerAddress))
  console.log(kleur.blue('On chain:'), kleur.cyan(chainName))

  // Call the endpoint contract to check the delegate
  const delegate = (await publicClient.readContract({
    address: lzEndpointAddress,
    abi: LZ_ENDPOINT_ABI,
    functionName: 'delegates',
    args: [oAppAddress],
  })) as Address

  // Check if the deployer is authorized (either as owner or delegate)
  const isAuthorized =
    delegate === deployerAddress || delegate === '0x0000000000000000000000000000000000000000'

  console.log(kleur.blue('Delegate for OApp:'), kleur.cyan(delegate))
  console.log(
    kleur.blue('Is deployer authorized:'),
    isAuthorized ? kleur.green('Yes') : kleur.red('No'),
  )

  return { delegate, isAuthorized }
}
