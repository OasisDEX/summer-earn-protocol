import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, Hex } from 'viem'
import {
  ProposalDetails,
  getProposalsDirectory,
  listProposalFiles,
  saveProposalToFile,
} from './helpers/proposal-helpers'

interface MergedCrossChainExecution {
  name: string
  chainId: number
  targets: string[]
  values: string[]
  datas: string[]
  predecessor?: string
  delay?: string
}

/**
 * Load proposal data from a file
 */
function loadProposalFromFile(filePath: string): ProposalDetails {
  const fileContent = fs.readFileSync(filePath, 'utf8')
  return JSON.parse(fileContent)
}

/**
 * Merge multiple cross-chain execution objects, grouping by target chain
 */
function mergeCrossChainExecutions(
  crossChainExecutions: any[],
): MergedCrossChainExecution[] | undefined {
  if (crossChainExecutions.length === 0) {
    return undefined
  }

  // Map to store merged data by chain ID
  const mergedByChain = new Map<number, MergedCrossChainExecution>()

  for (const execution of crossChainExecutions) {
    if (!execution) continue

    // Handle both object format (with targetChain property) and array format
    let targetChains: any[] = []

    if (execution.targetChain) {
      // Object format: { targetChain: {...} }
      targetChains = [execution.targetChain]
    } else if (Array.isArray(execution)) {
      // Already an array
      targetChains = execution
    } else {
      // Direct object format (treat as single chain)
      targetChains = [execution]
    }

    for (const targetChain of targetChains) {
      const chainId = targetChain.chainId

      if (!mergedByChain.has(chainId)) {
        // First time seeing this chain, initialize
        mergedByChain.set(chainId, {
          name: targetChain.name,
          chainId: targetChain.chainId,
          targets: [],
          values: [],
          datas: [],
          predecessor: targetChain.predecessor,
          delay: targetChain.delay,
        })
      }

      const merged = mergedByChain.get(chainId)!

      // Append the targets, values, and datas
      merged.targets.push(...targetChain.targets)
      merged.values.push(...targetChain.values)
      merged.datas.push(...targetChain.datas)
    }
  }

  return Array.from(mergedByChain.values())
}

/**
 * Merge multiple proposals into a single proposal
 */
function mergeProposals(
  proposals: ProposalDetails[],
  mergedTitle: string,
  mergedDescription: string,
): ProposalDetails {
  // Validate all proposals have the same governor
  const firstGovernorId = proposals[0].governorId
  const allSameGovernor = proposals.every((p) => p.governorId === firstGovernorId)

  if (!allSameGovernor) {
    throw new Error('Cannot merge proposals with different governor addresses')
  }

  // Merge targets, values, and calldatas
  const mergedTargets: Address[] = []
  const mergedValues: string[] = []
  const mergedCalldatas: Hex[] = []
  const crossChainExecutions: any[] = []

  for (const proposal of proposals) {
    // Append hub-chain actions
    mergedTargets.push(...proposal.targets)
    mergedValues.push(...proposal.values)
    mergedCalldatas.push(...proposal.calldatas)

    // Collect cross-chain executions
    if (proposal.crossChainExecution) {
      crossChainExecutions.push(proposal.crossChainExecution)
    }
  }

  // Merge cross-chain executions by target chain
  const mergedCrossChainExecution = mergeCrossChainExecutions(crossChainExecutions)

  // Combine discourse URLs if they exist
  const discourseURLs = proposals
    .map((p) => p.discourseURL)
    .filter(Boolean)
    .filter((url, index, self) => self.indexOf(url) === index) // Unique URLs

  return {
    title: mergedTitle,
    description: mergedDescription,
    governorId: firstGovernorId,
    targets: mergedTargets,
    values: mergedValues,
    calldatas: mergedCalldatas,
    discourseURL: discourseURLs.length > 0 ? discourseURLs.join(', ') : undefined,
    timestamp: Date.now(),
    crossChainExecution: mergedCrossChainExecution as any,
  }
}

/**
 * Generate a merged description from individual proposals
 */
function generateMergedDescription(
  proposals: ProposalDetails[],
  customTitle?: string,
  customDescription?: string,
): { title: string; description: string } {
  // Use custom title/description if provided
  if (customTitle && customDescription) {
    return { title: customTitle, description: customDescription }
  }

  // Generate default merged description
  const title = customTitle || `Merged Proposal: ${proposals.length} Fleet Actions`

  const proposalSummaries = proposals
    .map((p, i) => `### Included Proposal ${i + 1}: ${p.title}\n${p.description}`)
    .join('\n\n---\n\n')

  const description =
    customDescription ||
    `# ${title}

## Summary
This is a merged governance proposal combining ${proposals.length} individual proposals into a single coordinated action.

## Included Proposals
${proposalSummaries}

## Total Actions
- Hub Chain Actions: ${proposals.reduce((sum, p) => sum + p.targets.length, 0)}
- Cross-Chain Actions: ${proposals.filter((p) => p.crossChainExecution).length > 0 ? 'Yes' : 'No'}
`

  return { title, description }
}

/**
 * Main function to merge proposals
 */
async function mergeProposalsScript() {
  console.log(kleur.blue().bold('Proposal Merger'))
  console.log(kleur.yellow('This script merges multiple proposals into a single proposal.\n'))

  const proposalsDir = getProposalsDirectory()
  const files = listProposalFiles()

  if (files.length === 0) {
    console.log(kleur.red('No proposal files found in the proposals directory'))
    return
  }

  console.log(kleur.cyan(`Found ${files.length} proposal file(s)\n`))

  // Allow user to select multiple files
  const { selectedFiles } = await prompts({
    type: 'multiselect',
    name: 'selectedFiles',
    message: 'Select proposals to merge (use space to select, enter to confirm):',
    choices: files.map((file) => ({ title: file, value: file })),
    min: 2,
    hint: '- Space to select. Return to submit',
  })

  if (!selectedFiles || selectedFiles.length < 2) {
    console.log(kleur.red('You must select at least 2 proposals to merge.'))
    return
  }

  console.log(kleur.green(`\nSelected ${selectedFiles.length} proposals to merge\n`))

  // Load all selected proposals
  const proposals: ProposalDetails[] = []
  for (const filename of selectedFiles) {
    const filePath = path.join(proposalsDir, filename)
    console.log(kleur.blue(`Loading: ${filename}`))
    const proposal = loadProposalFromFile(filePath)
    proposals.push(proposal)
  }

  // Validate all proposals have the same governor
  const firstGovernorId = proposals[0].governorId
  const allSameGovernor = proposals.every((p) => p.governorId === firstGovernorId)

  if (!allSameGovernor) {
    console.log(kleur.red('\n❌ Error: Cannot merge proposals with different governor addresses'))
    console.log(kleur.yellow('\nGovernor addresses found:'))
    proposals.forEach((p, i) => {
      console.log(kleur.cyan(`  Proposal ${i + 1}: ${p.governorId}`))
    })
    return
  }

  console.log(kleur.green('\n✓ All proposals use the same governor'))

  // Display summary
  console.log(kleur.cyan('\nProposal Summary:'))
  proposals.forEach((p, i) => {
    console.log(kleur.blue(`\nProposal ${i + 1}:`))
    console.log(kleur.yellow(`  Title: ${p.title}`))
    console.log(kleur.yellow(`  Hub Actions: ${p.targets.length}`))
    console.log(kleur.yellow(`  Cross-Chain: ${p.crossChainExecution ? 'Yes' : 'No'}`))
  })

  // Ask for custom title and description
  const { useCustom } = await prompts({
    type: 'confirm',
    name: 'useCustom',
    message: 'Do you want to provide a custom title and description for the merged proposal?',
    initial: true,
  })

  let customTitle: string | undefined
  let customDescription: string | undefined

  if (useCustom) {
    const titleResponse = await prompts({
      type: 'text',
      name: 'title',
      message: 'Enter the merged proposal title:',
      validate: (value) => (value.length > 0 ? true : 'Title is required'),
    })

    const descriptionResponse = await prompts({
      type: 'text',
      name: 'description',
      message: 'Enter the merged proposal description (markdown supported):',
      validate: (value) => (value.length > 0 ? true : 'Description is required'),
    })

    customTitle = titleResponse.title
    customDescription = descriptionResponse.description
  }

  // Generate merged description
  const { title, description } = generateMergedDescription(
    proposals,
    customTitle,
    customDescription,
  )

  // Merge proposals
  console.log(kleur.cyan('\nMerging proposals...'))
  const mergedProposal = mergeProposals(proposals, title, description)

  // Display merged proposal summary
  console.log(kleur.green('\n✓ Proposals merged successfully!\n'))
  console.log(kleur.cyan('Merged Proposal Summary:'))
  console.log(kleur.blue('Title:'), kleur.yellow(mergedProposal.title))
  console.log(kleur.blue('Total Hub Actions:'), kleur.yellow(mergedProposal.targets.length))

  if (mergedProposal.crossChainExecution) {
    console.log(kleur.blue('\nCross-Chain Execution:'))
    const crossChainArray = Array.isArray(mergedProposal.crossChainExecution)
      ? mergedProposal.crossChainExecution
      : [mergedProposal.crossChainExecution]

    crossChainArray.forEach((chain: any, i: number) => {
      console.log(kleur.yellow(`\n  Target Chain ${i + 1}:`))
      console.log(kleur.cyan(`    Name: ${chain.name}`))
      console.log(kleur.cyan(`    Chain ID: ${chain.chainId}`))
      console.log(kleur.cyan(`    Actions: ${chain.targets?.length || 0}`))
    })
  }

  // Ask for confirmation
  const { confirm } = await prompts({
    type: 'confirm',
    name: 'confirm',
    message: 'Save this merged proposal?',
    initial: true,
  })

  if (!confirm) {
    console.log(kleur.red('Merge cancelled.'))
    return
  }

  // Save merged proposal
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const savePath = path.join(proposalsDir, `merged_proposal_${timestamp}.json`)
  saveProposalToFile(mergedProposal, savePath)

  console.log(kleur.green().bold('\n✓ Merged proposal saved successfully!'))
  console.log(kleur.blue('File:'), kleur.cyan(savePath))

  // Ask if user wants to keep or delete the original files
  const { deleteOriginals } = await prompts({
    type: 'confirm',
    name: 'deleteOriginals',
    message: 'Do you want to delete the original proposal files?',
    initial: false,
  })

  if (deleteOriginals) {
    console.log(kleur.yellow('\nDeleting original proposal files...'))
    for (const filename of selectedFiles) {
      const filePath = path.join(proposalsDir, filename)
      fs.unlinkSync(filePath)
      console.log(kleur.green(`  ✓ Deleted: ${filename}`))
    }
  }

  console.log(kleur.green().bold('\n✓ Done!'))
}

// Execute the script
mergeProposalsScript().catch((error) => {
  console.error(kleur.red('Error merging proposals:'))
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
})
