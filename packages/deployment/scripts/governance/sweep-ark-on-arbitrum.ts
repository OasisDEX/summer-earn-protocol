import hre from 'hardhat'
import kleur from 'kleur'
import path from 'node:path'
import prompts from 'prompts'
import { Address, encodeFunctionData, Hex } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { getChainIdByNetwork } from '../helpers/get-chainid'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { createGovernanceProposal } from '../helpers/proposal-helpers'

/**
 * Creates a cross-chain proposal to Arbitrum that:
 * 1) Sets ConfigurationManager.raft to the Arbitrum Timelock
 * 2) Calls Ark.sweep(tokens) so Timelock (as temporary raft) receives swept tokens
 * 3) Restores ConfigurationManager.raft back to the proper Raft contract
 *
 * Ark and token addresses are prompted.
 */
async function sweepArkOnArbitrum() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Must run from hub chain to send cross-chain proposal
  if (network !== HUB_CHAIN_NAME) {
    console.log(
      kleur.red(
        `This script must be run on ${HUB_CHAIN_NAME} to create the cross-chain governance proposal to Arbitrum.`,
      ),
    )
    return
  }

  const useBummerConfig = await promptForConfigType()

  // Load hub and arbitrum configs
  const hubConfig = getConfigByNetwork(
    HUB_CHAIN_NAME,
    { common: true, core: true, gov: true },
    useBummerConfig,
  ) as BaseConfig

  const arbitrumConfig = getConfigByNetwork(
    'arbitrum',
    { common: true, core: true, gov: true },
    useBummerConfig,
  ) as BaseConfig

  const hubGovernorAddress = hubConfig.deployedContracts.govV2.summerGovernor.address as Address
  const arbConfigurationManager = arbitrumConfig.deployedContracts.core.configurationManager
    .address as Address
  const arbTimelock = arbitrumConfig.deployedContracts.gov.timelock.address as Address
  const arbRaft = arbitrumConfig.deployedContracts.core.raft.address as Address
  const arbEid = Number(arbitrumConfig.common.layerZero.eID)
  const arbChainId = Number(getChainIdByNetwork('arbitrum'))

  // Prompt for Ark address (target of sweep)
  const { arkAddress } = await prompts({
    type: 'text',
    name: 'arkAddress',
    message: 'Enter the Arbitrum Ark address to sweep from:',
    validate: (val: string) => (/^0x[a-fA-F0-9]{40}$/.test(val) ? true : 'Invalid address'),
  })
  if (!arkAddress) {
    console.log(kleur.red('Ark address is required.'))
    return
  }
  const ark = arkAddress as Address

  // Prompt for token addresses (comma-separated)
  const { tokenInput } = await prompts({
    type: 'text',
    name: 'tokenInput',
    message:
      'Enter token address(es) to sweep from the Ark on Arbitrum (comma-separated if multiple):',
    validate: (val: string) => {
      const arr = val
        .split(',')
        .map((s) => s.trim())
        .filter((s) => s.length > 0)
      if (arr.length === 0) return 'At least one token address is required'
      for (const a of arr) {
        if (!/^0x[a-fA-F0-9]{40}$/.test(a)) return `Invalid address: ${a}`
      }
      return true
    },
  })
  const tokens = (tokenInput as string)
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0) as Address[]

  console.log(kleur.cyan('\nProposal plan (Arbitrum):'))
  console.log(kleur.yellow(`- ConfigurationManager: ${arbConfigurationManager}`))
  console.log(kleur.yellow(`- Timelock:             ${arbTimelock}`))
  console.log(kleur.yellow(`- Raft (restore to):    ${arbRaft}`))
  console.log(kleur.yellow(`- Ark:                  ${ark}`))
  console.log(kleur.yellow(`- Tokens to sweep:      ${tokens.join(', ')}`))

  const { continue: shouldContinue } = await prompts({
    type: 'confirm',
    name: 'continue',
    message:
      'This will create a cross-chain proposal to Arbitrum with 3 actions (set raft to timelock, Ark.sweep, restore raft). Continue?',
    initial: true,
  })
  if (!shouldContinue) {
    console.log(kleur.red('Operation cancelled by user.'))
    return
  }

  // Build destination (Arbitrum) actions
  const dstTargets: Address[] = []
  const dstValues: bigint[] = []
  const dstCalldatas: Hex[] = []

  // 1) Set raft to Timelock on Arbitrum
  dstTargets.push(arbConfigurationManager)
  dstValues.push(0n)
  dstCalldatas.push(
    encodeFunctionData({
      abi: [
        {
          name: 'setRaft',
          type: 'function',
          inputs: [{ name: 'newRaft', type: 'address' }],
          outputs: [],
          stateMutability: 'nonpayable',
        },
      ],
      functionName: 'setRaft',
      args: [arbTimelock],
    }),
  )

  // 2) Ark.sweep(tokens) — executed by Timelock (as temporary raft)
  dstTargets.push(ark)
  dstValues.push(0n)
  dstCalldatas.push(
    encodeFunctionData({
      abi: [
        {
          name: 'sweep',
          type: 'function',
          inputs: [{ name: 'tokens', type: 'address[]' }],
          outputs: [
            { name: 'sweptTokens', type: 'address[]' },
            { name: 'sweptAmounts', type: 'uint256[]' },
          ],
          stateMutability: 'nonpayable',
        },
      ],
      functionName: 'sweep',
      args: [tokens],
    }),
  )

  // 3) Restore raft to proper Raft on Arbitrum
  dstTargets.push(arbConfigurationManager)
  dstValues.push(0n)
  dstCalldatas.push(
    encodeFunctionData({
      abi: [
        {
          name: 'setRaft',
          type: 'function',
          inputs: [{ name: 'newRaft', type: 'address' }],
          outputs: [],
          stateMutability: 'nonpayable',
        },
      ],
      functionName: 'setRaft',
      args: [arbRaft],
    }),
  )

  // Destination description
  const dstDescription = `
# Arbitrum: Temporary raft switch to Timelock, Ark sweep, restore raft

## Summary
Temporarily sets ConfigurationManager.raft to the Timelock so it can invoke Ark.sweep(tokens),
then restores raft back to the Raft contract.

## Actions
1. Set raft to Timelock (${arbTimelock}) in ConfigurationManager (${arbConfigurationManager})
2. Call Ark.sweep on ${ark} with tokens: ${tokens.join(', ')}
3. Restore raft to Raft (${arbRaft}) in ConfigurationManager (${arbConfigurationManager})
  `.trim()

  // Hub action to send proposal to Arbitrum
  const ESTIMATED_GAS = 600000n
  const lzOptions = constructLzOptions(ESTIMATED_GAS)

  const srcTargets: Address[] = []
  const srcValues: bigint[] = []
  const srcCalldatas: Hex[] = []

  srcTargets.push(hubGovernorAddress)
  srcValues.push(0n)
  srcCalldatas.push(
    encodeFunctionData({
      abi: [
        {
          name: 'sendProposalToTargetChain',
          type: 'function',
          inputs: [
            { name: '_dstEid', type: 'uint32' },
            { name: '_dstTargets', type: 'address[]' },
            { name: '_dstValues', type: 'uint256[]' },
            { name: '_dstCalldatas', type: 'bytes[]' },
            { name: '_dstDescriptionHash', type: 'bytes32' },
            { name: '_options', type: 'bytes' },
          ],
          outputs: [],
          stateMutability: 'nonpayable',
        },
      ],
      functionName: 'sendProposalToTargetChain',
      args: [
        arbEid,
        dstTargets,
        dstValues,
        dstCalldatas,
        hashDescription(dstDescription),
        lzOptions,
      ],
    }),
  )

  // Cross-chain execution summary for persisted JSON
  const crossChainExecutions: Array<{
    name: string
    chainId: number
    targets: string[]
    values: string[]
    datas: string[]
  }> = [
    {
      name: 'arbitrum',
      chainId: arbChainId,
      targets: dstTargets.map((t) => t as string),
      values: dstValues.map((v) => v.toString()),
      datas: dstCalldatas.map((c) => c as string),
    },
  ]

  // Title/description
  const sipMinorNumber = await getSipMinorNumber()
  const sipNumber = sipMinorNumber !== undefined ? `SIP5.${sipMinorNumber}` : 'SIP5'
  const title = `${sipNumber}: Arbitrum Ark Sweep via Timelock`
  const description = `
# ${sipNumber}: Arbitrum Ark Sweep via Timelock

## Summary
On Arbitrum, temporarily set ConfigurationManager.raft to the Timelock to enable Ark.sweep(tokens)
to transfer specified tokens to the Timelock, then restore raft to the Raft contract.

## Target Chain
Arbitrum

## Contracts
- ConfigurationManager: ${arbConfigurationManager}
- Timelock: ${arbTimelock}
- Raft (restore): ${arbRaft}
- Ark (sweep target): ${ark}

## Tokens
${tokens.map((t) => `- ${t}`).join('\n')}

## Actions
1. Set raft to Timelock in ConfigurationManager
2. Ark.sweep(tokens) — executed by Timelock (as temporary raft)
3. Restore raft to Raft in ConfigurationManager
  `.trim()

  const actions = srcTargets.map((target, i) => ({
    target,
    value: srcValues[i],
    calldata: srcCalldatas[i],
  }))

  const actionSummary = [`Send cross-chain proposal to arbitrum (3 actions)`]

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const savePath = path.join(
    process.cwd(),
    '/proposals',
    `${useBummerConfig ? 'test' : 'prod'}_arb_ark_sweep_${timestamp}.json`,
  )

  console.log(kleur.cyan('Creating governance proposal with the following actions:'))
  console.log(kleur.yellow(`- Send cross-chain proposal to arbitrum (3 actions)`))

  await createGovernanceProposal(
    title,
    description,
    actions,
    hubGovernorAddress,
    HUB_CHAIN_ID,
    '', // optional discourse URL
    actionSummary,
    savePath,
    crossChainExecutions,
  )

  console.log(kleur.green('✅ Successfully created Arbitrum Ark sweep governance proposal'))
  console.log(
    kleur.yellow(
      'The proposal has been saved to a JSON file in the proposals directory and can be submitted manually.',
    ),
  )
}

// Execute
sweepArkOnArbitrum().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})

export { sweepArkOnArbitrum }
