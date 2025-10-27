import { Hex, keccak256, toBytes } from 'viem'

export function hashDescription(description: string): Hex {
  return keccak256(toBytes(description))
}
