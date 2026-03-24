import { Address, PublicClient } from 'viem'
import { getEnsName } from 'viem/actions'
import { arbitrum, base, mainnet } from 'viem/chains'

import { getPublicClient } from '@/config/rpc'

const REVERSE_REGISTRAR_ABI = [
  {
    inputs: [{ name: 'addr', type: 'address' }],
    name: 'nameForAddr',
    outputs: [{ name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

const REGISTRARS = {
  ethereum: {
    chainId: mainnet.id,
  },
  base: {
    address: '0x0000000000D8e504002cC26E3Ec46D81971C1664' as Address,
    chainId: base.id,
  },
  arbitrum: {
    address: '0x0000000000D8e504002cC26E3Ec46D81971C1664' as Address,
    chainId: arbitrum.id,
  },
} as const

const getClient = (chainId: number) => getPublicClient(chainId)

export async function resolveEnsNames(addresses: string[]): Promise<Record<string, string>> {
  const ensMap: Record<string, string> = {}

  if (addresses.length === 0) return ensMap

  try {
    const addressesTyped = addresses as Address[]

    // Prepare multicall contracts for L2s
    const getL2Calls = (registrar: { address: Address; chainId: number }) =>
      addressesTyped.map((addr) => ({
        address: registrar.address,
        abi: REVERSE_REGISTRAR_ABI,
        functionName: 'nameForAddr' as const,
        args: [addr],
      }))

    // Perform resolutions: Parallel for Mainnet (robust), Multicall for L2s (fast)
    const [ethResultsRaw, baseRestultsRaw, arbResultsRaw] = await Promise.all([
      Promise.all(
        addressesTyped.map((addr) =>
          getEnsName(getClient(REGISTRARS.ethereum.chainId) as PublicClient, {
            address: addr,
          }).catch(() => null),
        ),
      ),
      getClient(REGISTRARS.base.chainId).multicall({
        contracts: getL2Calls(REGISTRARS.base),
        allowFailure: true,
      }),
      getClient(REGISTRARS.arbitrum.chainId).multicall({
        contracts: getL2Calls(REGISTRARS.arbitrum),
        allowFailure: true,
      }),
    ])

    const baseResults = baseRestultsRaw as Array<{ status: string; result?: unknown }>
    const arbResults = arbResultsRaw as Array<{ status: string; result?: unknown }>

    // Apply priority: Ethereum > Base > Arbitrum
    addresses.forEach((addr, i) => {
      const name =
        (ethResultsRaw[i] as string) ||
        (baseResults[i]?.status === 'success' ? (baseResults[i].result as string) : '') ||
        (arbResults[i]?.status === 'success' ? (arbResults[i].result as string) : '')

      if (name && name !== '') {
        ensMap[addr.toLowerCase()] = name
      }
    })
  } catch (error) {
    console.error('Error resolving ENS names with multicall:', error)
  }

  return ensMap
}
