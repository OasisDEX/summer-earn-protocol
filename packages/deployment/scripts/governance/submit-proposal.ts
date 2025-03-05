import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, Hex } from 'viem'
import { getConfigByNetwork } from '../helpers/config-handler'
import { submitProposal } from '../helpers/governance-helpers'

/**
 * Script to submit a governance proposal from a saved JSON file
 */
async function main() {
  console.log(kleur.cyan().bold('=== Lazy Summer Protocol Governance Proposal Submission ==='))
  console.log('')

  // Get config for current network
  const network = hre.network.name
  console.log(kleur.yellow(`Using network: ${network}`))
  const config = getConfigByNetwork(network, { common: true, gov: true, core: true })

  // Get the governor address from config
  const governorAddress = config.deployedContracts.gov.summerGovernor.address as Address
  console.log(kleur.yellow(`Governor address: ${governorAddress}`))

  // Prompt user to select a proposal file
  const proposalsDir = path.join(process.cwd(), 'packages/deployment/proposals/fleets')
  const files = fs.readdirSync(proposalsDir).filter((file) => file.endsWith('.json'))

  if (files.length === 0) {
    console.log(kleur.red('No proposal files found in the proposals directory'))
    return
  }

  const fileResponse = await prompts({
    type: 'select',
    name: 'filename',
    message: 'Select a proposal file to submit:',
    choices: files.map((file) => ({ title: file, value: file })),
  })

  if (!fileResponse.filename) {
    console.log(kleur.yellow('No file selected. Exiting.'))
    return
  }

  // Read and parse the proposal file
  const filePath = path.join(proposalsDir, fileResponse.filename)
  console.log(kleur.yellow(`Loading proposal from: ${filePath}`))

  try {
    const fileContent = fs.readFileSync(filePath, 'utf8')
    const proposal = JSON.parse(fileContent)

    // Extract proposal data
    const { title, description, targets, values, calldatas } = proposal

    // Convert values from strings to BigInt if needed
    const bigintValues = values.map((value: unknown) =>
      typeof value === 'string' ? BigInt(value) : BigInt(String(value)),
    )

    // Ensure calldatas are properly typed as 0x-prefixed strings
    const formattedCalldatas = calldatas.map((calldata: string | Hex) => calldata as `0x${string}`)

    // Display proposal summary
    console.log(kleur.cyan('Proposal Summary:'))
    console.log(kleur.blue('Title:'), title)
    console.log(kleur.blue('Description:'), description.substring(0, 200) + '...')
    console.log(kleur.blue('Number of actions:'), targets.length)

    // Submit the proposal
    const success = await submitProposal({
      title,
      description,
      targets: targets as Address[],
      values: bigintValues,
      calldatas: formattedCalldatas,
      governorAddress,
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
