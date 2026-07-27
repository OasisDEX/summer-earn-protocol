import fs from 'node:fs'
import path from 'node:path'

import kleur from 'kleur'
import { Address, encodeFunctionData, getAddress } from 'viem'

/**
 * Shared helpers for emitting Safe Transaction Builder JSON batches.
 *
 * Extracted from scripts/governance/remove-arks-safe.ts (kept untouched there — this is the
 * reusable copy for new scripts). Each transaction carries BOTH raw calldata and the decoded
 * `contractMethod` metadata so the Safe web UI can render the actions without ABI lookups.
 */

export interface SafeAbiFunctionFragment {
  name: string
  type: 'function'
  stateMutability: string
  inputs: readonly { name: string; type: string }[]
  outputs: readonly unknown[]
}

export interface SafeTx {
  to: string
  value: string
  data: string
  contractMethod: {
    inputs: readonly { name: string; type: string }[]
    name: string
    payable: boolean
  }
  contractInputsValues: Record<string, string>
}

export interface BatchAction {
  tx: SafeTx
  summary: string
}

export function buildTx(
  to: Address,
  abiFragment: SafeAbiFunctionFragment,
  args: readonly unknown[],
): SafeTx {
  const data = encodeFunctionData({
    abi: [abiFragment],
    functionName: abiFragment.name,
    args: args as never,
  })
  const contractInputsValues: Record<string, string> = {}
  abiFragment.inputs.forEach((input, i) => {
    const value = args[i]
    contractInputsValues[input.name] = Array.isArray(value) ? JSON.stringify(value) : String(value)
  })
  return {
    to: getAddress(to),
    value: '0',
    data,
    contractMethod: {
      inputs: abiFragment.inputs,
      name: abiFragment.name,
      payable: false,
    },
    contractInputsValues,
  }
}

export function writeSafeBatch(
  actions: BatchAction[],
  meta: { name: string; description: string; safeAddress: Address; chainId: number },
  outFile: string,
): string {
  const batch = {
    version: '1.0',
    chainId: meta.chainId.toString(),
    createdAt: Date.now(),
    meta: {
      name: meta.name,
      description: meta.description,
      txBuilderVersion: '1.16.5',
      createdFromSafeAddress: meta.safeAddress,
      createdFromOwnerAddress: '',
      checksum: '',
    },
    transactions: actions.map((a) => a.tx),
  }
  fs.mkdirSync(path.dirname(outFile), { recursive: true })
  fs.writeFileSync(outFile, JSON.stringify(batch, null, 2))
  return outFile
}

export function printActions(label: string, actions: BatchAction[]) {
  console.log(kleur.cyan().bold(`\n${label} (${actions.length} actions):`))
  actions.forEach((a, i) => {
    console.log(kleur.yellow(`  ${i + 1}. ${a.summary}`))
    console.log(kleur.gray(`     to: ${a.tx.to}  data: ${a.tx.data.slice(0, 10)}…`))
  })
}
