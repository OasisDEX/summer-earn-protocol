import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address, Hex } from 'viem'
import { GOVERNOR_ROLE } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { ProposalData, loadProposal } from '../helpers/proposal-helpers'
import { validateAddress } from '../helpers/validation'

type ProposalAction = {
  target: Address
  value: bigint
  data: Hex
}

function getCurrentChainId(): number {
  const chainId = hre.network.config.chainId
  if (!chainId) {
    throw new Error('Missing chainId in hardhat network config')
  }
  return Number(chainId)
}

function getActionsForCurrentChain(proposal: ProposalData): ProposalAction[] {
  const currentChainId = getCurrentChainId()

  if (proposal.crossChainExecution && Array.isArray(proposal.crossChainExecution)) {
    const matching = proposal.crossChainExecution.find((c) => c.chainId === currentChainId)
    if (!matching) {
      const available = proposal.crossChainExecution
        .map((c) => `${c.name}(${c.chainId})`)
        .join(', ')
      throw new Error(
        `No crossChainExecution component for chainId=${currentChainId}. Available: ${available}`,
      )
    }

    if (
      matching.targets.length !== matching.values.length ||
      matching.targets.length !== matching.datas.length
    ) {
      throw new Error(
        `Invalid crossChainExecution arrays for chainId=${currentChainId}: lengths must match`,
      )
    }

    return matching.targets.map((t, i) => ({
      target: validateAddress(t, `proposal target[${i}]`),
      value: BigInt(matching.values[i]),
      data: matching.datas[i] as Hex,
    }))
  }

  if (
    proposal.targets.length !== proposal.values.length ||
    proposal.targets.length !== proposal.calldatas.length
  ) {
    throw new Error('Invalid proposal arrays: targets/values/calldatas lengths must match')
  }

  return proposal.targets.map((t, i) => ({
    target: t,
    value: proposal.values[i],
    data: proposal.calldatas[i] as Hex,
  }))
}

async function assertDeployerHasGovernorRole() {
  const network = hre.network.name
  const useBummerConfig = await promptForConfigType()
  const config = getConfigByNetwork(network, { gov: true, core: true }, useBummerConfig)

  const accessManagerAddress = validateAddress(
    config.deployedContracts.gov.protocolAccessManager.address,
    'ProtocolAccessManager',
  )
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    accessManagerAddress,
  )

  const [deployer] = await hre.viem.getWalletClients()
  const deployerAddress = deployer.account.address as Address

  const hasGovernorRole = await protocolAccessManager.read.hasRole([GOVERNOR_ROLE, deployerAddress])

  if (!hasGovernorRole) {
    throw new Error(
      `Deployer ${deployerAddress} does not have GOVERNOR_ROLE on ${accessManagerAddress}`,
    )
  }

  return { deployer, deployerAddress }
}

async function main() {
  const proposal = await loadProposal('Select a proposal file to execute directly:')
  if (!proposal) return

  const actions = getActionsForCurrentChain(proposal)

  console.log(kleur.cyan('\nDirect Proposal Execution (deployer)'))
  console.log(kleur.yellow(`Network: ${hre.network.name}`))
  console.log(kleur.yellow(`ChainId: ${getCurrentChainId()}`))
  console.log(kleur.yellow(`Title: ${proposal.title}`))
  console.log(kleur.yellow(`Actions: ${actions.length}`))
  actions.forEach((a, i) => {
    const shortened = a.data.length > 50 ? `${a.data.slice(0, 47)}...` : a.data
    console.log(
      kleur.yellow(`  ${i + 1}. target=${a.target} value=${a.value.toString()} data=${shortened}`),
    )
  })

  const confirmResponse = await prompts({
    type: 'confirm',
    name: 'proceed',
    message: 'Execute these actions directly as deployer?',
    initial: false,
  })
  if (!confirmResponse.proceed) {
    console.log(kleur.yellow('Cancelled.'))
    return
  }

  const { deployer, deployerAddress } = await assertDeployerHasGovernorRole()
  console.log(kleur.green(`Deployer ${deployerAddress} has GOVERNOR_ROLE. Executing...`))

  const publicClient = await hre.viem.getPublicClient()

  for (let i = 0; i < actions.length; i++) {
    const action = actions[i]
    console.log(kleur.cyan(`\nExecuting action ${i + 1}/${actions.length}...`))
    const hash = await deployer.sendTransaction({
      to: action.target,
      value: action.value,
      data: action.data,
    })
    console.log(kleur.green(`Submitted: ${hash}`))
    const receipt = await publicClient.waitForTransactionReceipt({ hash })
    console.log(kleur.green(`Mined in block ${receipt.blockNumber} (status=${receipt.status})`))
    if (receipt.status !== 'success') {
      throw new Error(`Action ${i + 1} failed (tx=${hash})`)
    }
  }

  console.log(kleur.green('\nAll actions executed successfully.'))
}

main().catch((err) => {
  console.error(kleur.red('Direct execution failed:'), err)
  process.exitCode = 1
})
