#!/usr/bin/env tsx
/**
 * Convert governance proposal(s) to Safe transaction format
 *
 * Usage:
 *   tsx convert-gov-proposal-to-safe-tx.ts <proposal1.json> [proposal2.json ...] --safe <safeAddress> --chainId <chainId> --output <output.json>
 *   tsx convert-gov-proposal-to-safe-tx.ts proposals/*.json --safe 0x97aE56497C7b2D3998d8d7Cb77a0959BeF8f0a55 --chainId 1 --output merged-safe-tx.json
 */

import { readFileSync, writeFileSync } from 'fs'
import { resolve } from 'path'

interface GovernanceProposal {
  title: string
  description: string
  crossChainExecution?:
    | Array<{
        name: string
        chainId: number
        targets: string[]
        values: string[]
        datas: string[]
      }>
    | {
        targetChain: {
          name: string
          chainId: number
          targets: string[]
          values: string[]
          datas: string[]
        }
      }
  timestamp?: number
}

interface SafeTransaction {
  version: string
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

function parseArgs(): {
  proposals: string[]
  safeAddress: string
  chainId: number
  output: string
} {
  const args = process.argv.slice(2)
  const proposals: string[] = []
  let safeAddress = ''
  let chainId = 1
  let output = 'safe-transaction.json'

  for (let i = 0; i < args.length; i++) {
    const arg = args[i]
    if (arg === '--safe' && i + 1 < args.length) {
      safeAddress = args[++i]
    } else if (arg === '--chainId' && i + 1 < args.length) {
      chainId = parseInt(args[++i], 10)
    } else if (arg === '--output' && i + 1 < args.length) {
      output = args[++i]
    } else if (!arg.startsWith('--')) {
      proposals.push(arg)
    }
  }

  if (proposals.length === 0) {
    console.error('Error: No proposal files provided')
    console.error(
      'Usage: tsx convert-gov-proposal-to-safe-tx.ts <proposal1.json> [proposal2.json ...] --safe <safeAddress> --chainId <chainId> --output <output.json>',
    )
    process.exit(1)
  }

  if (!safeAddress) {
    console.error('Error: --safe address is required')
    process.exit(1)
  }

  return { proposals, safeAddress, chainId, output }
}

function loadProposal(filePath: string): GovernanceProposal {
  try {
    const content = readFileSync(filePath, 'utf-8')
    return JSON.parse(content) as GovernanceProposal
  } catch (error) {
    console.error(`Error loading proposal from ${filePath}:`, error)
    process.exit(1)
  }
}

function extractChainExecution(
  proposal: GovernanceProposal,
  chainId: number,
): {
  targets: string[]
  values: string[]
  datas: string[]
} | null {
  if (!proposal.crossChainExecution) {
    console.warn(`Warning: No crossChainExecution found in proposal: ${proposal.title}`)
    return null
  }
  const execution =
    'targetChain' in proposal.crossChainExecution
      ? proposal.crossChainExecution.targetChain
      : proposal.crossChainExecution.find((exec) => exec.chainId === chainId)
  if (!execution) {
    console.warn(
      `Warning: No crossChainExecution found for chainId ${chainId} in proposal: ${proposal.title}`,
    )
    return null
  }

  return {
    targets: execution.targets,
    values: execution.values,
    datas: execution.datas,
  }
}

function convertToSafeTransaction(
  proposals: GovernanceProposal[],
  safeAddress: string,
  chainId: number,
): SafeTransaction {
  const allTransactions: SafeTransaction['transactions'] = []
  const proposalTitles: string[] = []
  const proposalDescriptions: string[] = []

  for (const proposal of proposals) {
    proposalTitles.push(proposal.title)
    proposalDescriptions.push(proposal.description.split('\n')[0] || proposal.title)

    const execution = extractChainExecution(proposal, chainId)
    if (!execution) {
      continue
    }

    // Validate arrays have same length
    if (
      execution.targets.length !== execution.values.length ||
      execution.targets.length !== execution.datas.length
    ) {
      console.error(`Error: Mismatched array lengths in proposal ${proposal.title}`)
      process.exit(1)
    }

    // Add transactions from this proposal
    for (let i = 0; i < execution.targets.length; i++) {
      allTransactions.push({
        to: execution.targets[i],
        value: execution.values[i] || '0',
        data: execution.datas[i],
        contractMethod: null,
        contractInputsValues: null,
      })
    }
  }

  // Use the latest timestamp from proposals, or current time
  const latestTimestamp = Math.max(...proposals.map((p) => p.timestamp || 0)) || Date.now()

  const safeTx: SafeTransaction = {
    version: '1.0',
    chainId: chainId.toString(),
    createdAt: latestTimestamp,
    meta: {
      name:
        proposalTitles.length === 1
          ? proposalTitles[0]
          : `Merged Proposals: ${proposalTitles.join(', ')}`,
      description: proposalDescriptions.join('\n\n'),
      txBuilderVersion: '1.18.0',
      createdFromSafeAddress: safeAddress,
      createdFromOwnerAddress: '',
      checksum: '',
    },
    transactions: allTransactions,
  }

  return safeTx
}

function main() {
  const { proposals, safeAddress, chainId, output } = parseArgs()

  console.log(`📋 Loading ${proposals.length} proposal(s)...`)
  const loadedProposals = proposals.map((filePath) => {
    const fullPath = resolve(filePath)
    console.log(`  - ${filePath}`)
    return loadProposal(fullPath)
  })

  console.log(`\n🔄 Converting to Safe transaction format...`)
  console.log(`   Chain ID: ${chainId}`)
  console.log(`   Safe Address: ${safeAddress}`)

  const safeTx = convertToSafeTransaction(loadedProposals, safeAddress, chainId)

  console.log(`\n✅ Generated ${safeTx.transactions.length} transaction(s)`)

  const outputPath = resolve(output)
  writeFileSync(outputPath, JSON.stringify(safeTx, null, 2), 'utf-8')

  console.log(`\n💾 Saved to: ${outputPath}`)
}

if (require.main === module) {
  main()
}

export { convertToSafeTransaction, loadProposal, extractChainExecution }
