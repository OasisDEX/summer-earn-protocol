import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import {
  Address,
  createPublicClient,
  encodeFunctionData,
  Hex,
  http,
  parseAbi,
  isAddress,
} from 'viem'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { getChainConfigs } from '../helpers/chain-configs'
import { getChainIdByNetwork } from '../helpers/get-chainid'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { createGovernanceProposal } from '../helpers/proposal-helpers'
import { createClients } from '../helpers/wallet-helper'
import { SupportedChain } from '../helpers/chain'

// ----------------------------------------------------------------------------
// CONFIGURATION
// ----------------------------------------------------------------------------

interface TransferRequest {
  chain: SupportedChain
  token: string // Ticker (e.g. "USDC") or Address
  amount: number // Amount without decimals (e.g. 1000 for 1000 USDC)
  recipient?: Address // Optional: defaults to proposer if not set
}

// EDIT THIS ARRAY WITH YOUR TRANSFER REQUESTS
const TRANSFER_REQUESTS: TransferRequest[] = [
  {
    chain: SupportedChain.mainnet,
    token: 'weth',
    amount: 7.76,
    recipient: '0xeaef8fb615a7d5ab6a356dec0549fd749460e970',
  },
  {
    chain: SupportedChain.sonic,
    token: 'usdce',
    amount: 7_720,
    recipient: '0xeaef8fb615a7d5ab6a356dec0549fd749460e970',
  },
]

// ----------------------------------------------------------------------------

const erc20Abi = parseAbi([
  'function balanceOf(address account) external view returns (uint256)',
  'function transfer(address to, uint256 amount) external returns (bool)',
  'function decimals() external view returns (uint8)',
  'function symbol() external view returns (string)',
])

async function main() {
  console.log(kleur.cyan().bold('=== Create Multi-Chain Transfer Proposal ==='))

  if (TRANSFER_REQUESTS.length === 0) {
    console.warn(
      kleur.yellow(
        'Warning: TRANSFER_REQUESTS array is empty. Please edit the script to add transfer requests.',
      ),
    )
    // We'll proceed but it won't do much
  }

  // Use bummer config - usually true for dev/test scripts, but maybe false for prod?
  // The user didn't specify, but existing scripts use a flag or default to one.
  // We'll assume prod config (useBummerConfig = false) unless we want to test.
  // Actually, let's stick to production config by default for "real" proposals,
  // or maybe allow a flag. For now, I'll set it to false as this seems like a utility tool.
  const useBummerConfig = process.env.USE_BUMMER === 'true'
  console.log(kleur.yellow(`Using ${useBummerConfig ? 'bummer' : 'production'} configuration`))

  // Get all chain configs
  const chainConfigs = getChainConfigs(useBummerConfig)

  // Get hub chain configuration
  const hubConfig = chainConfigs[HUB_CHAIN_NAME]
  if (!hubConfig) {
    throw new Error(`Hub chain (${HUB_CHAIN_NAME}) not found in config`)
  }

  // Get proposer address
  const { walletClient } = createClients(hubConfig.chain, hubConfig.rpcUrl)
  const proposerAddress = walletClient.account.address

  console.log(kleur.blue(`Proposer address: ${proposerAddress}`))

  // Get SIP minor number
  const sipMinorNumber = await getSipMinorNumber()

  try {
    // Lists to hold proposal data
    const srcTargets: Address[] = []
    const srcValues: bigint[] = []
    const srcCalldatas: Hex[] = []
    const crossChainExecutions: Array<{
      name: string
      chainId: number
      targets: string[]
      values: string[]
      datas: string[]
    }> = []

    const actionSummaries: string[] = []

    console.log(kleur.cyan('\nProcessing transfer requests...'))

    for (const req of TRANSFER_REQUESTS) {
      const chainName = req.chain
      const chainConfig = chainConfigs[chainName]

      if (!chainConfig) {
        console.error(kleur.red(`Error: Chain '${chainName}' not found in configuration`))
        continue
      }

      const timelockAddress = chainConfig.config.deployedContracts.govV2.timelock.address as Address
      if (!timelockAddress || timelockAddress === '0x0000000000000000000000000000000000000000') {
        console.error(kleur.red(`Error: Timelock address not found for chain '${chainName}'`))
        continue
      }

      // Create public client for this chain
      const publicClient = createPublicClient({
        chain: chainConfig.chain,
        transport: http(chainConfig.rpcUrl),
      })

      // Resolve Token Address
      let tokenAddress: Address
      let tokenSymbol: string = req.token

      if (isAddress(req.token)) {
        tokenAddress = req.token
      } else {
        // Look up ticker in config
        // The config structure is chainConfig.config.tokens[ticker]
        // We need to cast to any or check existence because tokens keys are dynamic/typed
        const tokens = chainConfig.config.tokens as Record<string, string>
        const addr = tokens[req.token.toLowerCase()] // tokens keys are usually lowercase in config? Let's check.
        // In the read file output: "usdc": "0x...", "dai": "0x..." -> yes, lowercase.

        if (!addr) {
          // Try as is
          const addrCase = tokens[req.token]
          if (!addrCase) {
            console.error(
              kleur.red(`Error: Token '${req.token}' not found in config for chain '${chainName}'`),
            )
            continue
          }
          tokenAddress = addrCase as Address
        } else {
          tokenAddress = addr as Address
        }
      }

      // Get Token Decimals and Symbol (if we don't have it from ticker)
      let decimals: number
      try {
        const [d, s] = await Promise.all([
          publicClient.readContract({
            address: tokenAddress,
            abi: erc20Abi,
            functionName: 'decimals',
          }),
          publicClient.readContract({
            address: tokenAddress,
            abi: erc20Abi,
            functionName: 'symbol',
          }),
        ])
        decimals = d
        tokenSymbol = s
      } catch (e) {
        console.error(
          kleur.red(`Error: Failed to fetch token info for ${tokenAddress} on ${chainName}`),
          e,
        )
        continue
      }

      const amountRaw = (BigInt(req.amount * 1000) * 10n ** BigInt(decimals)) / 1000n

      // Check Timelock Balance
      const balance = await publicClient.readContract({
        address: tokenAddress,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [timelockAddress],
      })

      if (balance < amountRaw) {
        console.warn(
          kleur.yellow(
            `WARNING: Timelock ${timelockAddress} on ${chainName} has insufficient balance.`,
          ),
        )
        console.warn(
          kleur.yellow(`  Required: ${amountRaw.toString()} (${req.amount} ${tokenSymbol})`),
        )
        console.warn(kleur.yellow(`  Available: ${balance.toString()}`))
        // We proceed anyway, assuming funds might be there at execution time or user knows what they are doing
      } else {
        console.log(
          kleur.green(
            `Verified balance on ${chainName}: OK (${balance.toString()} >= ${amountRaw.toString()})`,
          ),
        )
      }

      const recipient = req.recipient || proposerAddress

      // Prepare Transfer Calldata
      const transferCalldata = encodeFunctionData({
        abi: erc20Abi,
        functionName: 'transfer',
        args: [recipient, amountRaw],
      })

      const summary = `Transfer ${req.amount} ${tokenSymbol} on ${chainName} to ${recipient}`
      actionSummaries.push(summary)
      console.log(kleur.blue(`Adding action: ${summary}`))

      if (chainName === HUB_CHAIN_NAME) {
        // Direct execution by Hub Governor (via Timelock, but since Governor is proposer/executor in Timelock,
        // wait... The Governor calls the Timelock. The Timelock executes the call.
        // If the tokens are IN the Timelock, the Timelock calls "transfer" on the Token contract.
        // So target = TokenAddress.

        srcTargets.push(tokenAddress)
        srcValues.push(0n)
        srcCalldatas.push(transferCalldata)
      } else {
        // Cross-chain execution
        const dstTargets: Address[] = [tokenAddress]
        const dstValues: bigint[] = [0n]
        const dstCalldatas: Hex[] = [transferCalldata]

        const chainId = getChainIdByNetwork(chainName)

        crossChainExecutions.push({
          name: chainName,
          chainId: Number(chainId),
          targets: dstTargets.map((t) => t as string),
          values: dstValues.map((v) => v.toString()),
          datas: dstCalldatas.map((c) => c as string),
        })

        // Add Cross-Chain Proposal Action to Hub
        // We need to call sendProposalToTargetChain on the Hub Governor
        // But actually, we usually call it via the Timelock?
        // In `test-transfer-bummer-tokens.ts`:
        // srcTargets.push(hubGovernorAddress) -> calls sendProposalToTargetChain
        // This means the Timelock calls the Governor to send the payload.
        // Wait, why would Timelock call Governor?
        // Typically: Governor (Vote Pass) -> Timelock (Queue/Execute) -> Governor.sendProposalToTargetChain -> LayerZero -> Satellite Governor/Timelock.
        // In Summer Protocol, the Hub Governor handles the cross-chain messaging?
        // Let's check `test-transfer-bummer-tokens.ts`:
        // srcTargets.push(hubGovernorAddress)
        // functionName: 'sendProposalToTargetChain'
        // Yes, the proposal execution on Hub calls the HubGovernor to send the message.

        const hubGovernorAddress = hubConfig.config.deployedContracts.govV2.summerGovernor
          .address as Address
        const currentChainEndpointId = chainConfig.config.common.layerZero.eID

        const dstDescription = `
# Transfer ${tokenSymbol} on ${chainName}

## Summary
Transfer ${req.amount} ${tokenSymbol} from Timelock to ${recipient}.
`.trim()

        const ESTIMATED_GAS = 400000n // Standard estimate
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
      }
    }

    if (srcTargets.length === 0) {
      console.log(kleur.yellow('No actions to create.'))
      return
    }

    // Step 3: Create Proposal
    const sipNumber = sipMinorNumber !== undefined ? `SIP5.${sipMinorNumber}` : 'SIP5'
    const title = `${sipNumber}: Multi-chain Token Transfer`
    const description = `
# ${sipNumber}: Multi-chain Token Transfer

## Summary
This proposal executes token transfers from Timelock contracts across multiple chains.

## Actions
${actionSummaries.map((s) => `- ${s}`).join('\n')}
`.trim()

    // Generate a save path
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const savePath = path.join(
      process.cwd(),
      '/proposals',
      `multi_chain_transfer_${timestamp}.json`,
    )

    console.log(kleur.cyan('\nCreating governance proposal...'))

    // Create Action Objects
    const actions = srcTargets.map((target, index) => ({
      target,
      value: srcValues[index],
      calldata: srcCalldatas[index],
    }))

    const hubGovernorAddress = hubConfig.config.deployedContracts.govV2.summerGovernor
      .address as Address

    await createGovernanceProposal(
      title,
      description,
      actions,
      hubGovernorAddress,
      HUB_CHAIN_ID,
      '',
      actionSummaries,
      savePath,
      crossChainExecutions.length > 0 ? crossChainExecutions : undefined,
    )

    console.log(kleur.green('✅ Successfully created proposal'))
    console.log(kleur.yellow(`Saved to: ${savePath}`))
  } catch (error) {
    console.error(kleur.red('Error creating proposal:'), error)
    throw error
  }
}

main().catch(console.error)
