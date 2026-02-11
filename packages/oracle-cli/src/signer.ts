import { type Address, type Hex } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

/** EIP-712 domain for RwaOracle price updates - must match contract */
const DOMAIN_NAME = 'RwaOracle'
const DOMAIN_VERSION = '1'

/** EIP-712 types - users see these fields in wallet when signing */
const PRICE_UPDATE_TYPES = {
  PriceUpdate: [
    { name: 'price', type: 'int256' },
    { name: 'timestamp', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'oracle', type: 'address' },
    { name: 'chainId', type: 'uint256' },
  ],
} as const

export async function signPriceData(
  price: bigint,
  timestamp: bigint,
  nonce: bigint,
  oracleAddress: Address,
  chainId: number,
  privateKeys: Hex[],
): Promise<Hex[]> {
  const domain = {
    name: DOMAIN_NAME,
    version: DOMAIN_VERSION,
    chainId,
    verifyingContract: oracleAddress,
  }

  const message = {
    price,
    timestamp,
    nonce,
    oracle: oracleAddress,
    chainId: BigInt(chainId),
  }

  const signatures: Hex[] = []

  const signers = privateKeys
    .map((pk) => ({
      pk,
      address: privateKeyToAccount(pk).address,
    }))
    .sort((a, b) => a.address.toLowerCase().localeCompare(b.address.toLowerCase()))

  for (const signer of signers) {
    const account = privateKeyToAccount(signer.pk)
    const signature = await account.signTypedData({
      domain,
      types: PRICE_UPDATE_TYPES,
      primaryType: 'PriceUpdate',
      message,
    })
    signatures.push(signature)
  }

  return signatures
}
