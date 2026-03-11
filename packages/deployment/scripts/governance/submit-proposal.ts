import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { Address } from 'viem'
import { getConfigByNetwork } from '../helpers/config-handler'
import { submitProposal } from '../helpers/governance-helpers'
import { promptForConfigType } from '../helpers/prompt-helpers'
import {
  ProposalData,
  displayProposalSummary,
  getProposalsDirectory,
  loadProposalFile,
  promptForProposalFile,
} from '../helpers/proposal-helpers'
import { BaseConfig } from '../../types/config-types'

/**
 * Script to submit a governance proposal from a saved JSON file
 */
async function main() {
  console.log(kleur.cyan().bold('=== Lazy Summer Protocol Governance Proposal Submission ==='))
  console.log('')

  // Get config for current network
  const network = hre.network.name
  console.log(kleur.yellow(`Using network: ${network}`))

  // Add prompt for bummer config selection
  const useBummerConfig = await promptForConfigType()

  const config = getConfigByNetwork(
    network,
    { common: true, gov: true, core: true },
    useBummerConfig,
  ) as BaseConfig

  // Get the governor address from config
  const governorAddress = config.deployedContracts.govV2.summerGovernor.address as Address
  console.log(kleur.yellow(`Governor address: ${governorAddress}`))

  // Load proposal from file
  const filename = await promptForProposalFile('Select a proposal file to submit:')
  if (!filename) {
    console.log(kleur.red('No proposal selected. Exiting.'))
    return
  }

  try {
    const proposal: ProposalData = loadProposalFile(filename)
    displayProposalSummary(proposal)

    const { title, description, targets, values, calldatas } = proposal

    // Submit the proposal
    const result = await submitProposal({
      title,
      description,
      targets,
      values,
      calldatas,
      governorAddress,
      useBummerConfig,
    })

    if (result.success) {
      console.log(kleur.green('Proposal submitted successfully!'))

      // Update the JSON file with the transaction hash
      if (result.transactionHash) {
        const proposalsDir = getProposalsDirectory()
        const proposalPath = path.join(proposalsDir, filename)

        // Convert BigInt values to strings for JSON serialization
        const updatedProposal = {
          ...proposal,
          values: proposal.values.map((value) => value.toString()),
          proposalTxHash: result.transactionHash,
        }

        fs.writeFileSync(proposalPath, JSON.stringify(updatedProposal, null, 2))
        const proposedDir = path.join(proposalsDir, 'proposed')
        if (!fs.existsSync(proposedDir)) {
          fs.mkdirSync(proposedDir, { recursive: true })
        }
        fs.renameSync(proposalPath, path.join(proposedDir, filename))
        console.log(kleur.green(`Proposal file moved to /proposed folder: ${filename}`))
      }
    } else {
      console.log(kleur.red('Proposal submission was cancelled or failed.'))
    }
  } catch (error) {
    console.error(kleur.red('Error processing proposal file:'), error)
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(kleur.red('Error running script:'), error)
    process.exit(1)
  })
