import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, createPublicClient, encodeFunctionData, Hex, http, parseAbi } from 'viem'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { getChainConfigs } from '../helpers/chain-configs'
import { getChainIdByNetwork } from '../helpers/get-chainid'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { createGovernanceProposal } from '../helpers/proposal-helpers'
import { createClients } from '../helpers/wallet-helper'

const erc20Abi = parseAbi([
  'function balanceOf(address account) external view returns (uint256)',
  'function transfer(address to, uint256 amount) external returns (bool)',
])

const timelockAbi = parseAbi([
  'function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt, uint256 delay) external',
  'function execute(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt) external',
])

interface ChainBalance {
  chainName: string
  timelockAddress: Address
  tokenAddress: Address
  balance: bigint
}

async function main() {
  console.log(kleur.cyan().bold('=== Test: Transfer All Bummer Tokens from Timelocks ==='))
  console.log('')

  // Use bummer config
  const useBummerConfig = true
  console.log(kleur.yellow(`Using ${useBummerConfig ? 'bummer' : 'production'} configuration`))

  // Get all chain configs
  const chainConfigs = getChainConfigs(useBummerConfig)

  // Get hub chain configuration
  const hubConfig = chainConfigs[HUB_CHAIN_NAME]
  if (!hubConfig) {
    throw new Error(`Hub chain (${HUB_CHAIN_NAME}) not found in config`)
  }

  // Get proposer address (from wallet client)
  const { walletClient } = createClients(hubConfig.chain, hubConfig.rpcUrl)
  const proposerAddress = walletClient.account.address
  console.log(kleur.blue(`Proposer address: ${proposerAddress}`))

  // Get SIP minor number
  const sipMinorNumber = await getSipMinorNumber()

  try {
    // Step 1: Query balances on all chains
    console.log(kleur.cyan('\nQuerying timelock balances on all chains...'))
    const chainBalances: ChainBalance[] = []

    for (const [chainName, chainConfig] of Object.entries(chainConfigs)) {
      const timelockAddress = chainConfig.config.deployedContracts.govV2.timelock.address as Address
      const tokenAddress = chainConfig.config.deployedContracts.gov.summerToken.address as Address
      console.log(chainName, timelockAddress, tokenAddress)
      // Skip if addresses are zero
      if (
        timelockAddress === '0x0000000000000000000000000000000000000000' ||
        tokenAddress === '0x0000000000000000000000000000000000000000'
      ) {
        console.log(kleur.yellow(`Skipping ${chainName}: timelock or token address not set`))
        continue
      }

      // Create public client for this chain
      const publicClient = createPublicClient({
        chain: chainConfig.chain,
        transport: http(chainConfig.rpcUrl),
      })

      try {
        // Query balance
        const balance = await publicClient.readContract({
          address: tokenAddress,
          abi: erc20Abi,
          functionName: 'balanceOf',
          args: [timelockAddress],
        })

        console.log(
          kleur.yellow(
            `  ${chainName}: ${balance.toString()} tokens in timelock ${timelockAddress}`,
          ),
        )

        if (balance > 0n) {
          chainBalances.push({
            chainName,
            timelockAddress,
            tokenAddress,
            balance,
          })
        }
      } catch (error) {
        console.error(kleur.red(`Error querying balance for ${chainName}:`), error)
      }
    }

    if (chainBalances.length === 0) {
      console.log(kleur.yellow('\nNo tokens found in any timelock. Nothing to transfer.'))
      return
    }

    console.log(kleur.green(`\nFound tokens on ${chainBalances.length} chain(s) to transfer`))

    // Step 2: Prepare proposal actions
    const hubGovernorAddress = hubConfig.config.deployedContracts.govV2.summerGovernor
      .address as Address

    // Prepare actions for the hub chain
    const srcTargets: Address[] = []
    const srcValues: bigint[] = []
    const srcCalldatas: Hex[] = []

    // Store cross-chain execution details for the proposal data
    const crossChainExecutions: Array<{
      name: string
      chainId: number
      targets: string[]
      values: string[]
      datas: string[]
    }> = []

    // Process hub chain transfer
    const hubBalance = chainBalances.find((cb) => cb.chainName === HUB_CHAIN_NAME)
    if (hubBalance) {
      console.log(kleur.yellow(`\nPreparing hub chain (${HUB_CHAIN_NAME}) action...`))
      // The governor will execute this action, calling the token contract's transfer function
      // The timelock holds the tokens, so when the governor executes this, it should work
      // if the governor has the proper permissions to act on behalf of the timelock
      srcTargets.push(hubBalance.tokenAddress)
      srcValues.push(0n)
      srcCalldatas.push(
        encodeFunctionData({
          abi: erc20Abi,
          functionName: 'transfer',
          args: [proposerAddress, hubBalance.balance],
        }),
      )
      console.log(
        kleur.green(
          `  - Transfer ${hubBalance.balance.toString()} tokens from timelock ${hubBalance.timelockAddress} to proposer ${proposerAddress}`,
        ),
      )
    }

    // Process satellite chain transfers
    console.log(kleur.yellow('\nPreparing cross-chain actions for satellite chains...'))
    for (const chainBalance of chainBalances.filter((cb) => cb.chainName !== HUB_CHAIN_NAME)) {
      const chainConfig = chainConfigs[chainBalance.chainName as keyof typeof chainConfigs]
      if (!chainConfig) {
        console.log(kleur.red(`Chain config not found for ${chainBalance.chainName}`))
        continue
      }

      const currentChainEndpointId = chainConfig.config.common.layerZero.eID
      const chainId = getChainIdByNetwork(chainBalance.chainName)

      // Prepare the destination chain action
      const dstTargets: Address[] = [chainBalance.tokenAddress]
      const dstValues: bigint[] = [0n]
      const dstCalldatas: Hex[] = [
        encodeFunctionData({
          abi: erc20Abi,
          functionName: 'transfer',
          args: [proposerAddress, chainBalance.balance],
        }),
      ]

      // Store cross-chain execution data for this chain
      crossChainExecutions.push({
        name: chainBalance.chainName,
        chainId: Number(chainId),
        targets: dstTargets.map((t) => t as string),
        values: dstValues.map((v) => v.toString()),
        datas: dstCalldatas.map((c) => c as string),
      })

      // Create destination chain description
      const dstDescription = `
# Transfer Bummer Tokens from Timelock on ${chainBalance.chainName}

## Summary
This cross-chain proposal transfers all bummer tokens from the timelock to the proposer on ${chainBalance.chainName}.

## Actions
1. Transfer ${chainBalance.balance.toString()} tokens from timelock ${chainBalance.timelockAddress} to proposer ${proposerAddress}
      `.trim()

      // Add cross-chain proposal action to the source chain actions
      const ESTIMATED_GAS = 400000n
      const lzOptions = constructLzOptions(ESTIMATED_GAS)

      srcTargets.push(hubGovernorAddress)
      srcValues.push(0n)
      srcCalldatas.push(
        encodeFunctionData({
          abi: parseAbi([
            'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
          ]),
          functionName: 'sendProposalToTargetChain',
          args: [
            Number(currentChainEndpointId),
            dstTargets,
            dstValues,
            dstCalldatas,
            hashDescription(dstDescription),
            lzOptions,
          ],
        }),
      )

      console.log(
        kleur.green(
          `  - Added cross-chain proposal for ${chainBalance.chainName}: ${chainBalance.balance.toString()} tokens`,
        ),
      )
    }

    // Step 3: Create title and description for the full proposal
    const sipNumber = sipMinorNumber !== undefined ? `SIP5.${sipMinorNumber}` : 'SIP5'
    const title = `${sipNumber}: Test - Transfer All Bummer Tokens from Timelocks`
    const description = `
# ${sipNumber}: Test - Transfer All Bummer Tokens from Timelocks

## Summary
This test proposal transfers all bummer tokens from all timelock contracts to the proposer address across all chains in the Lazy Summer Protocol ecosystem.

## Motivation
This is a test proposal to verify that timelock transfers work correctly across all chains and that the governance system can execute multi-chain token transfers.

## Specifications

### Actions
${chainBalances
  .map(
    (cb) => `
${cb.chainName}:
- Transfer ${cb.balance.toString()} bummer tokens from timelock ${cb.timelockAddress} to proposer ${proposerAddress}`,
  )
  .join('\n')}

## Technical Details
The proposal transfers all bummer tokens from timelock contracts to the proposer address. This ensures that tokens held in timelocks can be moved via governance actions.
`.trim()

    // Create action summary for better display
    const actionSummary = chainBalances.map(
      (cb) => `Transfer ${cb.balance.toString()} tokens from ${cb.chainName} timelock to proposer`,
    )

    // Convert targets, values, and calldatas into ProposalAction array
    const actions = srcTargets.map((target, index) => ({
      target,
      value: srcValues[index],
      calldata: srcCalldatas[index],
    }))

    // Generate a save path for the proposal JSON
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const savePath = path.join(
      process.cwd(),
      '/proposals',
      `test_transfer_bummer_tokens_${timestamp}.json`,
    )

    console.log(kleur.cyan('\nCreating governance proposal with the following actions:'))
    chainBalances.forEach((cb) => {
      console.log(
        kleur.yellow(`- Transfer ${cb.balance.toString()} tokens from ${cb.chainName} timelock`),
      )
    })

    // Use createGovernanceProposal to save the proposal to JSON
    await createGovernanceProposal(
      title,
      description,
      actions,
      hubGovernorAddress,
      HUB_CHAIN_ID,
      '', // No discourse URL
      actionSummary,
      savePath,
      crossChainExecutions.length > 0 ? crossChainExecutions : undefined,
    )

    console.log(kleur.green('✅ Successfully created test proposal to transfer bummer tokens'))
    console.log(
      kleur.yellow(
        'The proposal has been saved to a JSON file in the proposals directory and can be submitted manually.',
      ),
    )
  } catch (error) {
    console.error(kleur.red('Error creating test proposal:'), error)
    throw error
  }
}

main().catch(console.error)
