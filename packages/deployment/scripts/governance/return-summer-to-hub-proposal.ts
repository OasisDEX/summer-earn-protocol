import { addressToBytes32 } from '@layerzerolabs/lz-v2-utilities'
import fs from 'fs'
import kleur from 'kleur'
import path from 'path'
import {
  Address,
  createPublicClient,
  encodeFunctionData,
  formatEther,
  Hex,
  http,
  parseAbi,
} from 'viem'
import SummerTokenABI from '../../artifacts/src/contracts/SummerToken.sol/SummerToken.json'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../common/constants'
import { getChainConfigs } from '../helpers/chain-configs'
import { getSipMinorNumber } from '../helpers/get-sip-minor-number'
import { hashDescription } from '../helpers/hash-description'
import { constructLzOptions } from '../helpers/layerzero-options'
import { createGovernanceProposal } from '../helpers/proposal-helpers'
import { SupportedChain } from '../helpers/chain'
import { erc20Abi } from 'viem'

// ----------------------------------------------------------------------------
// CONFIGURATION
// ----------------------------------------------------------------------------

/** Safety multiplier for LZ fee estimates to account for gas price fluctuations during timelock delay */
const FEE_SAFETY_MULTIPLIER = 1.5

/** Gas limit for LZ receive on hub chain when receiving SUMR tokens */
const LZ_RECEIVE_GAS_LIMIT = 300000n

/** Gas limit for cross-chain governance proposal execution on satellite */
const CROSS_CHAIN_PROPOSAL_GAS_LIMIT = 400000n

// ----------------------------------------------------------------------------
// TYPES
// ----------------------------------------------------------------------------

interface SatelliteChainInfo {
  chainName: string
  summerTokenAddress: Address
  timelockAddress: Address
  lzEndpointId: number
  sumrBalance: bigint
  nativeBalance: bigint
  estimatedFee: bigint
  feeWithBuffer: bigint
  hasEnoughNativeGas: boolean
}

// ----------------------------------------------------------------------------
// MAIN
// ----------------------------------------------------------------------------

async function main() {
  console.log(kleur.cyan().bold('=== Return SUMR Tokens from Satellite Timelocks to Hub ==='))
  console.log()

  const useBummerConfig = process.env.USE_BUMMER === 'true'
  console.log(kleur.yellow(`Using ${useBummerConfig ? 'bummer' : 'production'} configuration`))

  // Get all chain configs
  const chainConfigs = getChainConfigs(useBummerConfig)

  // Get hub chain configuration
  const hubConfig = chainConfigs[HUB_CHAIN_NAME]
  if (!hubConfig) {
    throw new Error(`Hub chain (${HUB_CHAIN_NAME}) not found in config`)
  }

  const hubTimelockAddress = hubConfig.config.deployedContracts.govV2.timelock.address as Address
  const hubGovernorAddress = hubConfig.config.deployedContracts.govV2.summerGovernor
    .address as Address
  const hubLzEndpointId = Number(hubConfig.config.common.layerZero.eID)

  console.log(kleur.blue('Hub chain:'), kleur.cyan(HUB_CHAIN_NAME))
  console.log(kleur.blue('Hub timelock:'), kleur.cyan(hubTimelockAddress))
  console.log(kleur.blue('Hub governor (v2):'), kleur.cyan(hubGovernorAddress))
  console.log(kleur.blue('Hub LZ eID:'), kleur.cyan(hubLzEndpointId.toString()))
  console.log()

  // Get SIP minor number
  const sipMinorNumber = await getSipMinorNumber()

  // Identify satellite chains (everything except hub)
  const satelliteChainNames = Object.keys(chainConfigs).filter(
    (name) => name !== HUB_CHAIN_NAME,
  ) as SupportedChain[]

  console.log(
    kleur.cyan(`Checking ${satelliteChainNames.length} satellite chains for SUMR balances...`),
  )
  console.log()

  // --------------------------------------------------------------------------
  // Step 1: Pre-flight checks for each satellite chain
  // --------------------------------------------------------------------------

  const eligibleChains: SatelliteChainInfo[] = []

  for (const chainName of satelliteChainNames) {
    const chainConfig = chainConfigs[chainName]
    if (!chainConfig) {
      console.log(kleur.yellow(`Skipping ${chainName}: no config found`))
      continue
    }

    const summerTokenAddress = chainConfig.config.deployedContracts.gov.summerToken
      .address as Address
    const timelockAddress = chainConfig.config.deployedContracts.govV2.timelock.address as Address
    const lzEndpointId = Number(chainConfig.config.common.layerZero.eID)

    // Skip chains with zero addresses
    if (
      timelockAddress === '0x0000000000000000000000000000000000000000' ||
      summerTokenAddress === '0x0000000000000000000000000000000000000000'
    ) {
      console.log(kleur.yellow(`Skipping ${chainName}: zero address for timelock or summer token`))
      continue
    }

    console.log(kleur.blue(`--- ${chainName.toUpperCase()} ---`))
    console.log(kleur.gray(`  SummerToken: ${summerTokenAddress}`))
    console.log(kleur.gray(`  Timelock:    ${timelockAddress}`))
    console.log(kleur.gray(`  LZ eID:      ${lzEndpointId}`))

    // Create public client for this satellite chain
    const publicClient = createPublicClient({
      chain: chainConfig.chain,
      transport: http(chainConfig.rpcUrl),
    })

    // Check SUMR balance of the timelock
    let sumrBalance: bigint
    try {
      sumrBalance = await publicClient.readContract({
        address: summerTokenAddress,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [timelockAddress],
      })
    } catch (error) {
      console.error(kleur.red(`  Error reading SUMR balance on ${chainName}: ${error}`))
      continue
    }

    if (sumrBalance === 0n) {
      console.log(kleur.yellow(`  SUMR balance: 0 — skipping`))
      console.log()
      continue
    }

    // Format SUMR balance (18 decimals)
    const readableBalance = Number(sumrBalance / 10n ** 18n)
    console.log(
      kleur.green(
        `  SUMR balance: ${readableBalance.toLocaleString()} (${sumrBalance.toString()} raw)`,
      ),
    )

    // Check native balance of the timelock
    let nativeBalance: bigint
    try {
      nativeBalance = await publicClient.getBalance({ address: timelockAddress })
    } catch (error) {
      console.error(kleur.red(`  Error reading native balance on ${chainName}: ${error}`))
      nativeBalance = 0n
    }

    console.log(kleur.gray(`  Native balance: ${formatEther(nativeBalance)}`))

    // Quote the LZ send fee from satellite -> hub
    const recipientBytes32 = `0x${Buffer.from(addressToBytes32(hubTimelockAddress)).toString(
      'hex',
    )}` as Hex

    const lzOptions = constructLzOptions(LZ_RECEIVE_GAS_LIMIT)

    const sendParam = {
      dstEid: hubLzEndpointId,
      to: recipientBytes32,
      amountLD: sumrBalance,
      minAmountLD: sumrBalance,
      extraOptions: lzOptions,
      composeMsg: '0x' as Hex,
      oftCmd: '0x' as Hex,
    }

    let estimatedFee: bigint
    let feeWithBuffer: bigint
    try {
      const quoteResult = await publicClient.readContract({
        address: summerTokenAddress,
        abi: SummerTokenABI.abi,
        functionName: 'quoteSend',
        args: [sendParam, false],
      })

      // Handle different possible return structures
      const rawFee =
        typeof quoteResult === 'object' && quoteResult !== null
          ? 'nativeFee' in quoteResult
            ? (quoteResult as any).nativeFee
            : Array.isArray(quoteResult)
              ? (quoteResult as any[])[0]
              : quoteResult
          : quoteResult

      estimatedFee = BigInt(rawFee as bigint)
      feeWithBuffer = BigInt(Math.floor(Number(estimatedFee) * FEE_SAFETY_MULTIPLIER))

      console.log(
        kleur.gray(
          `  LZ fee estimate: ${formatEther(estimatedFee)} (with ${FEE_SAFETY_MULTIPLIER}x buffer: ${formatEther(feeWithBuffer)})`,
        ),
      )
    } catch (error) {
      console.error(kleur.red(`  Error quoting LZ send fee on ${chainName}: ${error}`))
      continue
    }

    // Check if timelock has enough native gas
    const hasEnoughNativeGas = nativeBalance >= feeWithBuffer
    if (!hasEnoughNativeGas) {
      console.warn(kleur.yellow(`  ⚠ WARNING: Timelock has insufficient native gas for LZ fee!`))
      console.warn(
        kleur.yellow(
          `    Required: ${formatEther(feeWithBuffer)} | Available: ${formatEther(nativeBalance)}`,
        ),
      )
      console.warn(kleur.yellow(`    Deficit:  ${formatEther(feeWithBuffer - nativeBalance)}`))
      console.warn(
        kleur.yellow(
          `    Proceeding anyway — ensure timelock is funded before proposal execution.`,
        ),
      )
    } else {
      console.log(kleur.green(`  ✓ Timelock has sufficient native gas for LZ fee`))
    }

    eligibleChains.push({
      chainName,
      summerTokenAddress,
      timelockAddress,
      lzEndpointId,
      sumrBalance,
      nativeBalance,
      estimatedFee,
      feeWithBuffer,
      hasEnoughNativeGas,
    })

    console.log()
  }

  // --------------------------------------------------------------------------
  // Step 2: Check if there are any eligible chains
  // --------------------------------------------------------------------------

  if (eligibleChains.length === 0) {
    console.log(
      kleur.yellow('No satellite chains have SUMR balances in their timelocks. Nothing to do.'),
    )
    return
  }

  console.log(
    kleur.cyan(
      `Found ${eligibleChains.length} satellite chain(s) with SUMR balances. Building proposal...`,
    ),
  )
  console.log()

  // --------------------------------------------------------------------------
  // Step 3: Build cross-chain actions for each eligible satellite
  // --------------------------------------------------------------------------

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

  for (const satellite of eligibleChains) {
    const readableBalance = Number(satellite.sumrBalance / 10n ** 18n)

    console.log(
      kleur.blue(
        `Building cross-chain action for ${satellite.chainName}: ${readableBalance.toLocaleString()} SUMR`,
      ),
    )

    // --- Destination actions (executed on satellite by its timelock) ---

    // Build the send parameters for the satellite -> hub transfer
    const recipientBytes32 = `0x${Buffer.from(addressToBytes32(hubTimelockAddress)).toString(
      'hex',
    )}` as Hex

    const lzOptions = constructLzOptions(LZ_RECEIVE_GAS_LIMIT)

    const sendParam = {
      dstEid: hubLzEndpointId,
      to: recipientBytes32,
      amountLD: satellite.sumrBalance,
      minAmountLD: satellite.sumrBalance,
      extraOptions: lzOptions,
      composeMsg: '0x' as Hex,
      oftCmd: '0x' as Hex,
    }

    // Encode the SummerToken.send() call
    const sendCalldata = encodeFunctionData({
      abi: SummerTokenABI.abi,
      functionName: 'send',
      args: [
        sendParam,
        {
          nativeFee: satellite.feeWithBuffer,
          lzTokenFee: 0n,
        },
        satellite.timelockAddress, // refund address = satellite timelock
      ],
    }) as Hex

    const dstTargets: Address[] = [satellite.summerTokenAddress]
    const dstValues: bigint[] = [satellite.feeWithBuffer] // Native fee for the LZ send
    const dstCalldatas: Hex[] = [sendCalldata]

    // Build destination description for hashing
    const dstDescription = `# Return SUMR from ${satellite.chainName} to Hub

## Summary
Send ${readableBalance.toLocaleString()} SUMR tokens from ${satellite.chainName} timelock back to the hub chain (${HUB_CHAIN_NAME}) timelock via LayerZero OFT send.

## Actions
1. Call SummerToken.send() to bridge SUMR to hub timelock

## Details
- Source: ${satellite.timelockAddress} on ${satellite.chainName}
- Destination: ${hubTimelockAddress} on ${HUB_CHAIN_NAME}
- Amount: ${readableBalance.toLocaleString()} SUMR (${satellite.sumrBalance.toString()} raw)
- LZ Fee: ${formatEther(satellite.feeWithBuffer)} (with ${FEE_SAFETY_MULTIPLIER}x safety buffer)
`

    // --- Source action (hub governor calls sendProposalToTargetChain) ---
    const crossChainLzOptions = constructLzOptions(CROSS_CHAIN_PROPOSAL_GAS_LIMIT)

    srcTargets.push(hubGovernorAddress)
    srcValues.push(0n)
    srcCalldatas.push(
      encodeFunctionData({
        abi: parseAbi([
          'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
        ]),
        functionName: 'sendProposalToTargetChain',
        args: [
          satellite.lzEndpointId,
          dstTargets,
          dstValues,
          dstCalldatas,
          hashDescription(dstDescription),
          crossChainLzOptions,
        ],
      }),
    )

    // Track cross-chain execution metadata
    const chainConfigs2 = getChainConfigs(useBummerConfig)
    const chainConfig = chainConfigs2[satellite.chainName as SupportedChain]
    crossChainExecutions.push({
      name: satellite.chainName,
      chainId: chainConfig ? chainConfig.chain.id : 0,
      targets: dstTargets.map((t) => t as string),
      values: dstValues.map((v) => v.toString()),
      datas: dstCalldatas.map((c) => c as string),
    })

    const summary = `Send ${readableBalance.toLocaleString()} SUMR from ${satellite.chainName} timelock to hub`
    actionSummaries.push(summary)
    console.log(kleur.green(`  ✓ ${summary}`))
  }

  // --------------------------------------------------------------------------
  // Step 4: Build proposal description
  // --------------------------------------------------------------------------

  const sipNumber = sipMinorNumber !== undefined ? `SIP5.${sipMinorNumber}` : 'SIP5'
  const title = `${sipNumber}: Return SUMR Tokens from Satellite Timelocks to Hub`

  // Build chain summary table for description
  const chainSummaryLines = eligibleChains.map((chain) => {
    const readableBalance = Number(chain.sumrBalance / 10n ** 18n)
    const gasStatus = chain.hasEnoughNativeGas ? '✅ Sufficient' : '⚠️ Insufficient'
    return `| ${chain.chainName} | ${readableBalance.toLocaleString()} | ${formatEther(chain.feeWithBuffer)} | ${gasStatus} |`
  })

  const totalSumr = eligibleChains.reduce((sum, c) => sum + c.sumrBalance, 0n)
  const readableTotalSumr = Number(totalSumr / 10n ** 18n)

  const description = `# ${title}

## Summary
This proposal sends SUMR tokens from satellite chain timelocks back to the hub chain (${HUB_CHAIN_NAME}) timelock via LayerZero OFT \`send\`.

**Total SUMR to return:** ${readableTotalSumr.toLocaleString()} tokens across ${eligibleChains.length} chain(s).

## Chain Details

| Chain | SUMR Amount | LZ Fee (with buffer) | Native Gas Status |
|-------|-------------|---------------------|-------------------|
${chainSummaryLines.join('\n')}

## Actions
${actionSummaries.map((s, i) => `${i + 1}. ${s}`).join('\n')}

## Technical Details
- Hub Timelock (destination): ${hubTimelockAddress}
- Hub LZ eID: ${hubLzEndpointId}
- Fee Safety Multiplier: ${FEE_SAFETY_MULTIPLIER}x
- LZ Receive Gas Limit: ${LZ_RECEIVE_GAS_LIMIT.toString()}

## Cross-chain Mechanism
Each satellite chain action is sent via \`sendProposalToTargetChain\` on the hub governor. On the satellite chain, the timelock executes \`SummerToken.send()\` which bridges the tokens back via LayerZero. The native fee for the LZ message is included in the destination call values.

## Warnings
${
  eligibleChains.some((c) => !c.hasEnoughNativeGas)
    ? `> ⚠️ Some satellite timelocks have insufficient native gas for LZ fees. Ensure they are funded before this proposal is executed.
${eligibleChains
  .filter((c) => !c.hasEnoughNativeGas)
  .map(
    (c) =>
      `> - ${c.chainName}: needs ${formatEther(c.feeWithBuffer - c.nativeBalance)} more native gas`,
  )
  .join('\n')}`
    : 'All satellite timelocks have sufficient native gas for LZ fees.'
}
`

  // --------------------------------------------------------------------------
  // Step 5: Save proposal via createGovernanceProposal
  // --------------------------------------------------------------------------

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const savePath = path.join(process.cwd(), '/proposals', `return_sumr_to_hub_${timestamp}.json`)

  console.log()
  console.log(kleur.cyan('Creating governance proposal...'))

  const actions = srcTargets.map((target, index) => ({
    target,
    value: srcValues[index],
    calldata: srcCalldatas[index],
  }))

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

  console.log(kleur.green('✅ Proposal created successfully'))
  console.log(kleur.yellow(`Saved to: ${savePath}`))

  // Print summary
  console.log()
  console.log(kleur.cyan().bold('=== Summary ==='))
  console.log(kleur.blue('Total SUMR to return:'), `${readableTotalSumr.toLocaleString()} tokens`)
  console.log(kleur.blue('Satellite chains:'), eligibleChains.map((c) => c.chainName).join(', '))
  console.log(kleur.blue('Hub actions:'), srcTargets.length)

  if (eligibleChains.some((c) => !c.hasEnoughNativeGas)) {
    console.log()
    console.log(kleur.yellow().bold('⚠ Action required before execution:'))
    for (const chain of eligibleChains.filter((c) => !c.hasEnoughNativeGas)) {
      const deficit = chain.feeWithBuffer - chain.nativeBalance
      console.log(
        kleur.yellow(
          `  Fund ${chain.chainName} timelock (${chain.timelockAddress}) with at least ${formatEther(deficit)} native gas`,
        ),
      )
    }
  }
}

main().catch(console.error)
