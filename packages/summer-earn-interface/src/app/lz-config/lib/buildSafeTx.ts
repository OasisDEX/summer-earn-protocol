import { Address, encodeFunctionData, type Hex } from 'viem'

import { getEndpoint } from './configReader'
import { encodeExecutorConfig, encodeUlnConfig } from './encodeDecode'
import { CONFIG_TYPE_EXECUTOR, CONFIG_TYPE_ULN, LZ_ENDPOINT_ABI, OAPP_ABI } from './lzAbi'
import { CHAIN_NAME_TO_ID, ChainName, PendingEdit } from './types'

export interface SafeBuilderJson {
  version: '1.0'
  chainId: string
  createdAt: number
  meta: {
    name: string
    description: string
    txBuilderVersion: string
    createdFromSafeAddress: string
    createdFromOwnerAddress: string
    checksum: string
  }
  transactions: Array<{
    to: string
    value: string
    data: string
    contractMethod: null
    contractInputsValues: null
  }>
}

export function editToTx(edit: PendingEdit, endpoint: Address): { to: Address; data: Hex } {
  switch (edit.kind) {
    case 'setPeer': {
      const data = encodeFunctionData({
        abi: OAPP_ABI,
        functionName: 'setPeer',
        args: [edit.eid, edit.peerBytes32],
      })
      return { to: edit.oAppAddress, data }
    }
    case 'setSendLibrary': {
      const data = encodeFunctionData({
        abi: LZ_ENDPOINT_ABI,
        functionName: 'setSendLibrary',
        args: [edit.oAppAddress, edit.eid, edit.lib],
      })
      return { to: endpoint, data }
    }
    case 'setReceiveLibrary': {
      const data = encodeFunctionData({
        abi: LZ_ENDPOINT_ABI,
        functionName: 'setReceiveLibrary',
        args: [edit.oAppAddress, edit.eid, edit.lib, edit.gracePeriod],
      })
      return { to: endpoint, data }
    }
    case 'setSendConfig': {
      const executorBytes = encodeExecutorConfig(edit.executor)
      const ulnBytes = encodeUlnConfig(edit.uln)
      const params = [
        { eid: edit.eid, configType: CONFIG_TYPE_EXECUTOR, config: executorBytes },
        { eid: edit.eid, configType: CONFIG_TYPE_ULN, config: ulnBytes },
      ]
      const data = encodeFunctionData({
        abi: LZ_ENDPOINT_ABI,
        functionName: 'setConfig',
        args: [edit.oAppAddress, edit.sendLib, params],
      })
      return { to: endpoint, data }
    }
    case 'setReceiveConfig': {
      const ulnBytes = encodeUlnConfig(edit.uln)
      const params = [{ eid: edit.eid, configType: CONFIG_TYPE_ULN, config: ulnBytes }]
      const data = encodeFunctionData({
        abi: LZ_ENDPOINT_ABI,
        functionName: 'setConfig',
        args: [edit.oAppAddress, edit.receiveLib, params],
      })
      return { to: endpoint, data }
    }
    case 'setDelegate': {
      const data = encodeFunctionData({
        abi: OAPP_ABI,
        functionName: 'setDelegate',
        args: [edit.delegate],
      })
      return { to: edit.oAppAddress, data }
    }
    case 'setEnforcedOptions': {
      const data = encodeFunctionData({
        abi: OAPP_ABI,
        functionName: 'setEnforcedOptions',
        args: [edit.entries],
      })
      return { to: edit.oAppAddress, data }
    }
  }
}

export function describeEdit(e: PendingEdit): string {
  switch (e.kind) {
    case 'setPeer':
      return `setPeer on ${e.oApp} (${e.sourceChain} -> ${e.remoteChain}, eid=${e.eid})`
    case 'setSendLibrary':
      return `setSendLibrary on ${e.oApp} (${e.sourceChain} -> ${e.remoteChain})`
    case 'setReceiveLibrary':
      return `setReceiveLibrary on ${e.oApp} (${e.sourceChain} -> ${e.remoteChain})`
    case 'setSendConfig':
      return `setSendConfig (ULN+Executor) on ${e.oApp} (${e.sourceChain} -> ${e.remoteChain})`
    case 'setReceiveConfig':
      return `setReceiveConfig (ULN) on ${e.oApp} (${e.sourceChain} -> ${e.remoteChain})`
    case 'setDelegate':
      return `setDelegate → ${e.delegate} (${e.sourceChain}, ${e.oApp})`
    case 'setEnforcedOptions':
      return `setEnforcedOptions ${e.entries.length} entry/entries (${e.sourceChain}, ${e.oApp})`
  }
}

/**
 * Group edits by sourceChain. Each chain produces one SafeBuilderJson — the
 * Safe Transaction Builder is chain-scoped.
 */
export function buildSafeTxJsonByChain(
  edits: PendingEdit[],
  safeAddress: string,
): Record<ChainName, SafeBuilderJson> {
  const byChain: Partial<Record<ChainName, PendingEdit[]>> = {}
  for (const edit of edits) {
    if (!byChain[edit.sourceChain]) byChain[edit.sourceChain] = []
    byChain[edit.sourceChain]!.push(edit)
  }

  const result: Partial<Record<ChainName, SafeBuilderJson>> = {}
  const now = Date.now()

  for (const [chain, chainEdits] of Object.entries(byChain) as [ChainName, PendingEdit[]][]) {
    const endpoint = getEndpoint(chain)
    if (!endpoint) continue

    const txs = chainEdits.map((edit) => {
      const { to, data } = editToTx(edit, endpoint)
      return {
        to,
        value: '0',
        data,
        contractMethod: null,
        contractInputsValues: null,
      }
    })

    const description = chainEdits.map((e) => `- ${describeEdit(e)}`).join('\n')

    result[chain] = {
      version: '1.0',
      chainId: CHAIN_NAME_TO_ID[chain],
      createdAt: now,
      meta: {
        name: `LZ config update — ${chain}`,
        description: `Generated by summer-earn-interface lz-config explorer.\n\nIncluded actions:\n${description}`,
        txBuilderVersion: '1.18.0',
        createdFromSafeAddress: safeAddress,
        createdFromOwnerAddress: '',
        checksum: '',
      },
      transactions: txs,
    }
  }

  return result as Record<ChainName, SafeBuilderJson>
}

/** Browser-side download helper. */
export function downloadSafeTxJson(filename: string, json: SafeBuilderJson): void {
  const blob = new Blob([JSON.stringify(json, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}
