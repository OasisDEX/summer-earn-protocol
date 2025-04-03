import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import { getConfigByNetwork } from '../helpers/config-handler'
import { submitProposal } from '../helpers/governance-helpers'
import { promptForConfigType } from '../helpers/prompt-helpers'
import {
  ProposalData,
  displayProposalSummary,
  loadProposalFile,
  promptForProposalFile,
} from '../helpers/proposal-helpers'

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
  )

  // Get the governor address from config
  const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address
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
    const success = await submitProposal({
      title,
      description,
      targets,
      values,
      calldatas,
      governorAddress,
      useBummerConfig,
    })

    if (success) {
      console.log(kleur.green('Proposal submitted successfully!'))
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
