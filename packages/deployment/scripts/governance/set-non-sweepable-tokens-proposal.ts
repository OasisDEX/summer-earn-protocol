import { TransactionBase } from '@safe-global/types-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import {
  Address,
  createPublicClient,
  encodeFunctionData,
  getAddress,
  Hex,
  http,
  parseAbi,
} from 'viem'
import { arbitrum, base, mainnet, sonic } from 'viem/chains'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { promptForChain } from '../helpers/chain-prompt'
import { getChainIdByNetwork } from '../helpers/get-chainid'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { createGovernanceProposal } from '../helpers/proposal-helpers'
import { ArkDetails } from '../helpers/zod-schemas'

dotenv.config({ path: '../../.env' })

interface ArkConfig {
  chain: string
  arkAddress: string
  fleetAddress: string
  arkSymbol: string
  [key: string]: unknown
}

const TARGET_CHAINS = ['base', 'arbitrum', 'mainnet', 'sonic']

const VIEM_CHAIN_MAP = {
  mainnet,
  base,
  arbitrum,
  sonic,
}

const RPC_URL_MAP = {
  mainnet: process.env.MAINNET_RPC_URL,
  base: process.env.BASE_RPC_URL,
  arbitrum: process.env.ARBITRUM_RPC_URL,
  sonic: process.env.SONIC_RPC_URL,
}

// Safe multisig address (optional - only needed for Safe proposal generation)
const CURATOR_MULTISIG_ADDRESS = process.env.CURATOR_MULTISIG_ADDRESS
  ? getAddress(process.env.CURATOR_MULTISIG_ADDRESS as Address)
  : null

const ARK_ABI = parseAbi(['function details() external view returns (string)'])

const RAFT_ABI = parseAbi([
  'function setNonSweepableToken(address ark, address token, bool isNonSweepable) external',
  'function nonSweepableTokens(address ark, address token) external view returns (bool)',
])

interface ArkTokenMapping {
  arkAddress: Address
  tokenAddress: Address
  arkSymbol: string
}

/**
 * Extract pool/vault/siUSDVault address from ark details JSON
 */
export function extractTokenAddress(detailsJson: string): Address | null {
  try {
    const parsed = JSON.parse(detailsJson) as Record<string, unknown>

    // Check for pool, vault, or siUSDVault fields (in order of preference)
    if (parsed.pool && typeof parsed.pool === 'string') {
      return parsed.pool as Address
    }
    if (parsed.vault && typeof parsed.vault === 'string') {
      return parsed.vault as Address
    }
    if (parsed.siUSDVault && typeof parsed.siUSDVault === 'string') {
      return parsed.siUSDVault as Address
    }

    return null
  } catch (error) {
    console.error(kleur.red(`Failed to parse details JSON: ${error}`))
    return null
  }
}

/**
 * Check if a token is already marked as non-sweepable for an ark
 */
async function isTokenNonSweepable(
  raftAddress: Address,
  arkAddress: Address,
  tokenAddress: Address,
  chainName: string,
): Promise<boolean> {
  const chain = VIEM_CHAIN_MAP[chainName as keyof typeof VIEM_CHAIN_MAP]
  const rpcUrl = RPC_URL_MAP[chainName as keyof typeof RPC_URL_MAP]

  if (!chain || !rpcUrl) {
    throw new Error(`Missing chain or RPC URL for ${chainName}`)
  }

  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  })

  try {
    const isNonSweepable = (await publicClient.readContract({
      address: raftAddress,
      abi: RAFT_ABI,
      functionName: 'nonSweepableTokens',
      args: [arkAddress, tokenAddress],
    })) as boolean

    return isNonSweepable
  } catch (error) {
    console.error(
      kleur.red(
        `Failed to check non-sweepable status for ark ${arkAddress}, token ${tokenAddress} on ${chainName}: ${error}`,
      ),
    )
    // Return false on error to be safe - we'll still try to set it
    return false
  }
}

/**
 * Fetch ark details from on-chain contract and extract token address
 */
export async function getArkTokenMapping(
  arkAddress: Address,
  chainName: string,
): Promise<{ arkAddress: Address; tokenAddress: Address; arkSymbol: string } | null> {
  const chain = VIEM_CHAIN_MAP[chainName as keyof typeof VIEM_CHAIN_MAP]
  const rpcUrl = RPC_URL_MAP[chainName as keyof typeof RPC_URL_MAP]

  if (!chain || !rpcUrl) {
    throw new Error(`Missing chain or RPC URL for ${chainName}`)
  }

  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  })

  try {
    const detailsJson = (await publicClient.readContract({
      address: arkAddress,
      abi: ARK_ABI,
      functionName: 'details',
    })) as string

    const tokenAddress = extractTokenAddress(detailsJson)
    if (!tokenAddress) {
      console.log(
        kleur.yellow(
          `⚠️  No pool/vault/siUSDVault found in details for ark ${arkAddress} on ${chainName}`,
        ),
      )
      return null
    }

    return {
      arkAddress,
      tokenAddress,
      arkSymbol: '', // Will be filled from config
    }
  } catch (error) {
    console.error(
      kleur.red(`Failed to fetch details for ark ${arkAddress} on ${chainName}: ${error}`),
    )
    return null
  }
}

async function main() {
  // Load arks configuration
  const arksConfigPath = path.join(__dirname, '../../config/curation/arks.json')
  const arksConfig = JSON.parse(fs.readFileSync(arksConfigPath, 'utf-8')) as ArkConfig[]

  // Get hub chain configuration through prompt
  const {
    config: hubConfig,
    chain: hubChain,
    rpcUrl: hubRpcUrl,
    name: hubChainName,
  } = await promptForChain('Select the hub chain:')

  // Get the governor and raft addresses
  const HUB_GOVERNOR_ADDRESS = hubConfig.deployedContracts.govV2.summerGovernor.address as Address
  const HUB_RAFT_ADDRESS = hubConfig.deployedContracts.core.raft.address as Address

  // Get SIP minor number
  const sipMinorNumber = await getSipMinorNumber()

  try {
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

    // Store chain configs for Safe proposal generation and cross-chain proposals
    const chainConfigs: Record<
      string,
      { chainId: number; raftAddress: Address; endpointId?: number }
    > = {}

    // Process each chain to build ark -> token mappings
    console.log(kleur.yellow('Fetching ark details from on-chain contracts...'))
    const chainMappings: Record<string, ArkTokenMapping[]> = {}

    for (const chainName of TARGET_CHAINS) {
      console.log(kleur.cyan(`\nProcessing ${chainName}...`))
      const chainArks = arksConfig.filter(
        (ark) =>
          ark.chain.toLowerCase() === chainName.toLowerCase() &&
          ark.arkAddress &&
          ark.arkAddress !== '',
      )

      if (chainArks.length === 0) {
        console.log(kleur.yellow(`No arks found for ${chainName}`))
        chainMappings[chainName] = []
        // Still store chain config even if no arks
        if (chainName === HUB_CHAIN_NAME) {
          const raftAddress = hubConfig.deployedContracts.core.raft.address as Address
          const chainId = getChainIdByNetwork(chainName)
          chainConfigs[chainName] = { chainId, raftAddress }
        }
        continue
      }

      console.log(kleur.blue(`Found ${chainArks.length} arks for ${chainName}`))

      // Get chain config for Raft address (needed for Safe proposals and cross-chain)
      let chainConfig
      if (chainName === HUB_CHAIN_NAME) {
        chainConfig = hubConfig
      } else {
        const chainSetup = await promptForChain(`Select the ${chainName} chain configuration:`)
        chainConfig = chainSetup.config
      }

      const raftAddress = chainConfig.deployedContracts.core.raft.address as Address
      const chainId = getChainIdByNetwork(chainName)
      chainConfigs[chainName] = {
        chainId,
        raftAddress,
        endpointId:
          chainName === HUB_CHAIN_NAME
            ? undefined
            : typeof chainConfig.common.layerZero.eID === 'number'
              ? chainConfig.common.layerZero.eID
              : Number(chainConfig.common.layerZero.eID),
      }

      // Fetch details for all arks in parallel
      const mappingPromises = chainArks.map(async (arkConfig) => {
        const mapping = await getArkTokenMapping(arkConfig.arkAddress as Address, chainName)
        if (mapping) {
          mapping.arkSymbol = arkConfig.arkSymbol
        }
        return mapping
      })

      const mappings = (await Promise.all(mappingPromises)).filter(
        (m): m is ArkTokenMapping => m !== null,
      )

      chainMappings[chainName] = mappings
      console.log(
        kleur.green(`✓ Found ${mappings.length} valid ark->token mappings for ${chainName}`),
      )
    }

    // Store processed mappings (after filtering already non-sweepable tokens) for description generation
    const processedMappings: Record<string, ArkTokenMapping[]> = {}

    // Process hub chain rewards first
    console.log(kleur.yellow('\nPreparing hub chain actions...'))
    const hubMappings = chainMappings[HUB_CHAIN_NAME] || []
    const hubMappingsToProcess: ArkTokenMapping[] = []

    // Check which tokens are already non-sweepable
    console.log(kleur.cyan('Checking existing non-sweepable status...'))
    for (const mapping of hubMappings) {
      const alreadyNonSweepable = await isTokenNonSweepable(
        HUB_RAFT_ADDRESS,
        mapping.arkAddress,
        mapping.tokenAddress,
        HUB_CHAIN_NAME,
      )

      if (alreadyNonSweepable) {
        console.log(
          kleur.yellow(
            `  ⚠️  Skipping ${mapping.arkSymbol} (ark: ${mapping.arkAddress}, token: ${mapping.tokenAddress}) - already non-sweepable`,
          ),
        )
      } else {
        hubMappingsToProcess.push(mapping)
      }
    }

    // Store processed mappings for hub chain
    processedMappings[HUB_CHAIN_NAME] = hubMappingsToProcess

    // Add actions for tokens that need to be set
    for (const mapping of hubMappingsToProcess) {
      srcTargets.push(HUB_RAFT_ADDRESS)
      srcValues.push(0n)
      srcCalldatas.push(
        encodeFunctionData({
          abi: RAFT_ABI,
          functionName: 'setNonSweepableToken',
          args: [mapping.arkAddress, mapping.tokenAddress, true],
        }),
      )
      console.log(
        kleur.green(
          `  - Added setNonSweepableToken for ${mapping.arkSymbol} (ark: ${mapping.arkAddress}, token: ${mapping.tokenAddress})`,
        ),
      )
    }

    // Process satellite chain rewards
    console.log(kleur.yellow('\nPreparing cross-chain actions for satellite chains...'))
    for (const chainName of TARGET_CHAINS.filter((chain) => chain !== HUB_CHAIN_NAME)) {
      const mappings = chainMappings[chainName] || []
      if (mappings.length === 0) {
        console.log(kleur.yellow(`Skipping ${chainName} - no mappings found`))
        continue
      }

      const chainConfig = chainConfigs[chainName]
      if (!chainConfig || !chainConfig.endpointId) {
        throw new Error(`Missing chain config or endpoint ID for ${chainName}`)
      }

      const currentChainEndpointId = chainConfig.endpointId
      const raftAddress = chainConfig.raftAddress
      const chainId = chainConfig.chainId

      // Check which tokens are already non-sweepable
      console.log(kleur.cyan(`Checking existing non-sweepable status on ${chainName}...`))
      const mappingsToProcess: ArkTokenMapping[] = []

      for (const mapping of mappings) {
        const alreadyNonSweepable = await isTokenNonSweepable(
          raftAddress,
          mapping.arkAddress,
          mapping.tokenAddress,
          chainName,
        )

        if (alreadyNonSweepable) {
          console.log(
            kleur.yellow(
              `  ⚠️  Skipping ${mapping.arkSymbol} (ark: ${mapping.arkAddress}, token: ${mapping.tokenAddress}) - already non-sweepable`,
            ),
          )
        } else {
          mappingsToProcess.push(mapping)
        }
      }

      if (mappingsToProcess.length === 0) {
        console.log(kleur.yellow(`Skipping ${chainName} - all tokens already non-sweepable`))
        processedMappings[chainName] = []
        continue
      }

      // Store processed mappings for this chain
      processedMappings[chainName] = mappingsToProcess

      // Prepare the destination chain actions
      const dstTargets: Address[] = []
      const dstValues: bigint[] = []
      const dstCalldatas: Hex[] = []

      for (const mapping of mappingsToProcess) {
        dstTargets.push(raftAddress)
        dstValues.push(0n)
        dstCalldatas.push(
          encodeFunctionData({
            abi: RAFT_ABI,
            functionName: 'setNonSweepableToken',
            args: [mapping.arkAddress, mapping.tokenAddress, true],
          }),
        )
      }

      // Store cross-chain execution data for this chain
      crossChainExecutions.push({
        name: chainName,
        chainId: Number(chainId),
        targets: dstTargets.map((t) => t as string),
        values: dstValues.map((v) => v.toString()),
        datas: dstCalldatas.map((c) => c as string),
      })

      // Create destination chain description
      const dstDescription = `
# Set Non-Sweepable Tokens on ${chainName}

## Summary
This cross-chain proposal sets non-sweepable tokens for arks on ${chainName} by calling setNonSweepableToken on the Raft contract.

## Actions
${mappingsToProcess
  .map(
    (mapping) => `
- Set ${mapping.tokenAddress} as non-sweepable for ark ${mapping.arkSymbol} (${mapping.arkAddress})`,
  )
  .join('\n')}
      `.trim()

      // Add cross-chain proposal action to the source chain actions
      const ESTIMATED_GAS = 400000n
      const lzOptions = constructLzOptions(ESTIMATED_GAS)

      srcTargets.push(HUB_GOVERNOR_ADDRESS)
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
          `- Added cross-chain proposal for ${chainName} with ${mappingsToProcess.length} actions`,
        ),
      )
    }

    // Create title and description for the full proposal
    const sipNumber = sipMinorNumber !== undefined ? `SIP5.${sipMinorNumber}` : 'SIP5'
    const title = `${sipNumber}: Multi-Chain Set Non-Sweepable Tokens`
    const description = `
# ${sipNumber}: Multi-Chain Set Non-Sweepable Tokens

## Summary
This proposal sets non-sweepable tokens for arks across all active chains in the Lazy Summer Protocol ecosystem by calling setNonSweepableToken on the Raft contract.

## Motivation
Certain tokens (pools, vaults, or siUSDVault addresses) should be marked as non-sweepable for their respective arks to prevent accidental sweeping during protocol operations.

## Specifications

### Actions
${HUB_CHAIN_NAME}:
${
  processedMappings[HUB_CHAIN_NAME] && processedMappings[HUB_CHAIN_NAME].length > 0
    ? processedMappings[HUB_CHAIN_NAME].map(
        (mapping) => `
- Set ${mapping.tokenAddress} as non-sweepable for ark ${mapping.arkSymbol} (${mapping.arkAddress})`,
      ).join('\n')
    : 'No arks configured (or all tokens already non-sweepable)'
}

${TARGET_CHAINS.filter((chain) => chain !== HUB_CHAIN_NAME)
  .map(
    (chain) => `
${chain}:
${
  processedMappings[chain] && processedMappings[chain].length > 0
    ? processedMappings[chain]
        .map(
          (mapping) => `
- Set ${mapping.tokenAddress} as non-sweepable for ark ${mapping.arkSymbol} (${mapping.arkAddress})`,
        )
        .join('\n')
    : 'No arks configured (or all tokens already non-sweepable)'
}`,
  )
  .join('\n')}

## Technical Details
The proposal calls setNonSweepableToken on the Raft contract for each ark's associated pool/vault/siUSDVault address. This ensures these tokens cannot be swept during protocol operations.
`.trim()

    // Create action summary for better display
    const actionSummary = [
      `Set non-sweepable tokens on ${HUB_CHAIN_NAME} (${processedMappings[HUB_CHAIN_NAME]?.length || 0} arks)`,
      ...TARGET_CHAINS.filter((chain) => chain !== HUB_CHAIN_NAME)
        .filter((chain) => processedMappings[chain] && processedMappings[chain].length > 0)
        .map(
          (chain) =>
            `Send cross-chain proposal to ${chain} (${processedMappings[chain].length} arks)`,
        ),
    ]

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
      `set_non_sweepable_tokens_proposal_${timestamp}.json`,
    )

    console.log(kleur.cyan('\nCreating governance proposal with the following actions:'))
    console.log(
      kleur.yellow(
        `- Set non-sweepable tokens on ${HUB_CHAIN_NAME} (${processedMappings[HUB_CHAIN_NAME]?.length || 0} arks)`,
      ),
    )
    for (const chain of TARGET_CHAINS.filter((chain) => chain !== HUB_CHAIN_NAME)) {
      const count = processedMappings[chain]?.length || 0
      if (count > 0) {
        console.log(kleur.yellow(`- Send cross-chain proposal to ${chain} (${count} arks)`))
      }
    }

    // Use createGovernanceProposal to save the proposal to JSON
    await createGovernanceProposal(
      title,
      description,
      actions,
      HUB_GOVERNOR_ADDRESS,
      HUB_CHAIN_ID,
      '', // No discourse URL
      actionSummary,
      savePath,
      crossChainExecutions,
    )

    console.log(
      kleur.green(
        '✅ Successfully created multi-chain set non-sweepable tokens governance proposal',
      ),
    )
    console.log(
      kleur.yellow(
        'The proposal has been saved to a JSON file in the proposals directory and can be submitted manually.',
      ),
    )

    // Generate Safe proposals for each chain
    if (CURATOR_MULTISIG_ADDRESS) {
      console.log(kleur.cyan('\n📝 Generating Safe proposals for each chain...'))

      for (const chainName of TARGET_CHAINS) {
        const mappings = processedMappings[chainName] || []
        if (mappings.length === 0) {
          console.log(
            kleur.yellow(
              `Skipping Safe proposal for ${chainName} - no mappings found (or all already non-sweepable)`,
            ),
          )
          continue
        }

        const { chainId, raftAddress } = chainConfigs[chainName]
        const transactions: TransactionBase[] = []

        for (const mapping of mappings) {
          transactions.push({
            to: raftAddress,
            value: '0',
            data: encodeFunctionData({
              abi: RAFT_ABI,
              functionName: 'setNonSweepableToken',
              args: [mapping.arkAddress, mapping.tokenAddress, true],
            }),
          })
        }

        if (transactions.length > 0) {
          // Create Safe transaction JSON for this chain
          const safeTransactionsJson = {
            version: '1.0',
            chainId: chainId.toString(),
            createdAt: Date.now(),
            meta: {
              name: `Set Non-Sweepable Tokens - ${chainName}`,
              description: `Set non-sweepable tokens for ${mappings.length} arks on ${chainName}`,
              txBuilderVersion: '1.18.0',
              createdFromSafeAddress: CURATOR_MULTISIG_ADDRESS,
              createdFromOwnerAddress: '',
              checksum: '',
            },
            transactions: transactions.map((tx) => ({
              to: tx.to,
              value: tx.value || '0',
              data: tx.data,
              contractMethod: null,
              contractInputsValues: null,
            })),
          }

          // Write to file
          const outputPath = path.join(
            __dirname,
            `../../proposals/curation/safe-transactions-set-non-sweepable-${chainName}-${Date.now()}.json`,
          )
          fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))
          console.log(
            kleur.green(
              `✅ Saved Safe transactions for ${chainName} (${transactions.length} transactions) to ${outputPath}`,
            ),
          )
        }
      }
    } else {
      console.log(
        kleur.yellow('\n⚠️  CURATOR_MULTISIG_ADDRESS not set - skipping Safe proposal generation'),
      )
    }
  } catch (error) {
    console.error(kleur.red('Error creating multi-chain governance proposal:'), error)
    throw error
  }
}

main().catch(console.error)
