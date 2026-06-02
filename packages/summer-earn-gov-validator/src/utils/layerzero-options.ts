import { Options } from '@layerzerolabs/lz-v2-utilities'
import { bytesToHex, Hex } from 'viem'

export function constructLzOptions(gasLimit: bigint = 200000n): Hex {
  const options = Options.newOptions().addExecutorLzReceiveOption(Number(gasLimit), 0).toBytes()
  return bytesToHex(options)
}
