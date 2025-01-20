import { Options } from '@layerzerolabs/lz-v2-utilities'
import { Hex } from 'viem'

export function constructLzOptions(gasLimit: bigint = 200000n): Hex {
  // Convert options to bytes
  const options = Options.newOptions().addExecutorLzReceiveOption(Number(gasLimit), 0).toBytes()

  // Convert to hex string directly from the Uint8Array that toBytes() returns
  return `0x${Buffer.from(options).toString('hex')}` as `0x${string}`
}
