import { TransactionBase } from '@safe-global/types-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import path from 'path'
import { Address, encodeFunctionData, getAddress, createPublicClient, http } from 'viem'
import { BaseConfig, Token } from '../../types/config-types'
import { logPercentageComparison, logValueComparison } from '../helpers/fleet-config-reader'

import { arbitrum, base, mainnet, sonic } from 'viem/chains'

enum SupportedChain {
  base = 'base',
  arbitrum = 'arbitrum',
  mainnet = 'mainnet',
  sonic = 'sonic',
}

const SUPPORTED_CHAINS = [SupportedChain.base, SupportedChain.arbitrum, SupportedChain.mainnet, SupportedChain.sonic]

const RPC_URL_MAP = {
  [SupportedChain.mainnet]: process.env.MAINNET_RPC_URL,
  [SupportedChain.base]: process.env.BASE_RPC_URL,
  [SupportedChain.arbitrum]: process.env.ARBITRUM_RPC_URL,
  [SupportedChain.sonic]: process.env.SONIC_RPC_URL,
}

const VIEM_CHAIN_MAP = {
  [SupportedChain.mainnet]: mainnet,
  [SupportedChain.base]: base,
  [SupportedChain.arbitrum]: arbitrum,
  [SupportedChain.sonic]: sonic,
}

const CHAIN_MAP_BY_ID = Object.fromEntries(
  Object.values(VIEM_CHAIN_MAP).map((chain) => [chain.id, chain]),
)
// Hardcoded ABIs - these will be replaced with actual ABIs
const FLEET_COMMANDER_ABI = [
  // Add your FleetCommander ABI here
  { inputs: [], name: "getConfig", outputs: [{"name": "bufferArk", "type": "address"}, { name: "depositCap", type: "uint256" }, { name: "minimumBufferBalance", type: "uint256" }], stateMutability: "view", type: "function" },
  { inputs: [], name: "getCooldown", outputs: [{ name: "", type: "uint256" }], stateMutability: "view", type: "function" },
  { inputs: [{ name: "cap", type: "uint256" }], name: "setFleetDepositCap", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "balance", type: "uint256" }], name: "setMinimumBufferBalance", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "cooldown", type: "uint256" }], name: "updateRebalanceCooldown", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "arkAddress", type: "address" }, { name: "cap", type: "uint256" }], name: "setArkDepositCap", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "arkAddress", type: "address" }, { name: "percentage", type: "uint256" }], name: "setArkMaxDepositPercentageOfTVL", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "arkAddress", type: "address" }, { name: "amount", type: "uint256" }], name: "setArkMaxRebalanceInflow", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "arkAddress", type: "address" }, { name: "amount", type: "uint256" }], name: "setArkMaxRebalanceOutflow", outputs: [], stateMutability: "nonpayable", type: "function" }
]

const ARK_ABI = [
  // Add your Ark ABI here
  { inputs: [], name: "depositCap", outputs: [{ name: "", type: "uint256" }], stateMutability: "view", type: "function" },
  { inputs: [], name: "maxDepositPercentageOfTVL", outputs: [{ name: "", type: "uint256" }], stateMutability: "view", type: "function" },
  { inputs: [], name: "maxRebalanceInflow", outputs: [{ name: "", type: "uint256" }], stateMutability: "view", type: "function" },
  { inputs: [], name: "maxRebalanceOutflow", outputs: [{ name: "", type: "uint256" }], stateMutability: "view", type: "function" }
]

const RAFT_ABI = [
  // Add your Raft ABI here
  { inputs: [{ name: "arkAddress", type: "address" }, { name: "rewardTokenAddress", type: "address" }], name: "sweepableTokens", outputs: [{ name: "", type: "bool" }], stateMutability: "view", type: "function" },
  { inputs: [{ name: "arkAddress", type: "address" }, { name: "rewardTokenAddress", type: "address" }], name: "arkAuctionParameters", outputs: [{ name: "duration", type: "uint256" }, { name: "startPrice", type: "uint256" }, { name: "endPrice", type: "uint256" }, { name: "kickerRewardPercentage", type: "uint256" }, { name: "decayType", type: "uint256" }], stateMutability: "view", type: "function" },
  { inputs: [{ name: "arkAddress", type: "address" }, { name: "rewardTokenAddress", type: "address" }, { name: "params", type: "tuple", components: [{ name: "duration", type: "uint256" }, { name: "startPrice", type: "uint256" }, { name: "endPrice", type: "uint256" }, { name: "kickerRewardPercentage", type: "uint256" }, { name: "decayType", type: "uint256" }] }], name: "setArkAuctionParameters", outputs: [], stateMutability: "nonpayable", type: "function" },
  { inputs: [{ name: "arkAddress", type: "address" }, { name: "rewardTokenAddress", type: "address" }, { name: "isSweepable", type: "bool" }], name: "setSweepableToken", outputs: [], stateMutability: "nonpayable", type: "function" }
]

dotenv.config()

if (!process.env.CURATOR_MULTISIG_ADDRESS) {
  throw new Error('❌ CURATOR_MULTISIG_ADDRESS not set in environment')
}

if (!process.env.CURATOR_MULTISIG_PROPOSER_PRIV_KEY) {
  throw new Error('❌ CURATOR_MULTISIG_PROPOSER_PRIV_KEY not set in environment')
}

const safeAddress = getAddress(process.env.CURATOR_MULTISIG_ADDRESS as Address)

// Build chain configuration.
type ChainConfiguration = {
  chain: any
  chainId: number
  config: BaseConfig
  rpcUrl: string
}

interface ArkConfig {
  chain: string
  fleetAsset: string
  fleetAddress: string
  arkAddress: string
  fleetCap: string
  FleetMinimumBuffer: string
  ark: string
  arkSymbol: string
  arkMaxCap: string
  arkMaxPercTVL: string
  arkMaxInflow: string
  arkMaxOutflow: string
  reallocInterval: string
  deployedBySummerFi: string
  WhiteListedByBA: string
}

// Add new interface for auction config
interface AuctionConfig {
  rewardTokenSymbol: string
  rewardTokenDecimals: number
  prices: {
    [key in Token]: number
  }
  duration: string
  kickerRewardPercentage: number
  decayType: string
}

async function loadConfigurations() {
  const arksConfigPath = path.join(__dirname, '../../config/curation/arks.json')
  const arksConfig: ArkConfig[] = JSON.parse(fs.readFileSync(arksConfigPath, 'utf-8'))

  const auctionsConfigPath = path.join(__dirname, '../../config/curation/auctions.json')
  const auctionsConfig: AuctionConfig[] = JSON.parse(fs.readFileSync(auctionsConfigPath, 'utf-8'))

  return { arksConfig,  auctionsConfig }
}

function parseTimeString(timeStr: string): number {
  const unit = timeStr.slice(-1)
  const value = parseInt(timeStr.slice(0, -1))

  switch (unit) {
    case 'd':
      return value * 86400 // days to seconds
    case 'h':
      return value * 3600
    case 'm':
      return value * 60
    case 's':
      return value
    default:
      throw new Error(`Invalid time unit: ${unit}`)
  }
}

const WAD = BigInt(1e18)
const SIX_DECIMALS = 6n
const EIGHTEEN_DECIMALS = 18n

function getAssetDecimals(assetSymbol: string): bigint {
  switch (assetSymbol.toLowerCase()) {
    case 'weth':
    case 'reul':
    case 'ws':
    case 'seam':
      return EIGHTEEN_DECIMALS
    case 'usdc':
    case 'usdce':
    case 'usdt':
    case 'eurc':
      return SIX_DECIMALS
    default:
      throw new Error(`Unknown asset symbol: ${assetSymbol}`)
  }
}

function parseAmount(amountValue: string | number, assetSymbol: string): bigint {
  const decimals = getAssetDecimals(assetSymbol)

  // If it's already a number, convert directly
  if (typeof amountValue === 'number') {
    return BigInt(Math.floor(amountValue * Math.pow(10, Number(decimals))))
  }
  // If it's a string, remove commas first and multiply by decimals
  const baseAmount = BigInt(amountValue.replace(/,/g, ''))
  return baseAmount * BigInt(Math.pow(10, Number(decimals)))
}

/**
 *
 * @param percentValue Lazy Summer ocntracts use `Percentage` library where 1% == 1 WAD (1e18)
 * @returns
 */
function parsePercentage(percentValue: string | number): bigint {
  // If it's already a number (e.g. 0.37), multiply by 10000 to get basis points
  if (typeof percentValue === 'number') {
    // Fix: Round to avoid floating point precision issues
    const basisPoints = Math.round(percentValue * 100)
    return BigInt(basisPoints) * WAD
  }
  // If it's a string with % (legacy format), convert to basis points
  const percent = parseFloat(percentValue.replace('%', ''))
  return BigInt(BigInt(percent * 100) * WAD)
}

// Update the multiplier calculation to handle decimals correctly
function calculateAuctionMultipliers(
  basePrice: number,
  assetDecimals: bigint,
): { startPrice: bigint; endPrice: bigint } {
  // Convert base price to asset decimals
  const baseWithDecimals = BigInt(Math.round(basePrice * Math.pow(10, Number(assetDecimals))))

  // Start at 2x price and end at 0.1x price
  const startPrice = baseWithDecimals * 2n
  const endPrice = baseWithDecimals / 5n // 0.1x

  return { startPrice, endPrice }
}
const rewardsConfig: Record<number, Record<string, string[]>> = {
  1: {
    morpho: ['morpho'],
    euler: ['reul'],
  },
  8453: {
    morpho: ['morpho', 'seam'],
    euler: ['ws'],
  },
  146: {
    aave_v3: ['ws'],
    euler: ['ws'],
  },
}

// Custom function to read fleet config without hre
async function readFleetConfig(fleetAddress: Address, chain: SupportedChain) {
  const publicClient = createPublicClient({
    chain: VIEM_CHAIN_MAP[chain],
    transport: http(RPC_URL_MAP[chain])
  })

  const config = await publicClient.readContract({
    address: fleetAddress,
    abi: FLEET_COMMANDER_ABI,
    functionName: 'getConfig'
  }) as bigint[]

  const rebalanceCooldown = await publicClient.readContract({
    address: fleetAddress,
    abi: FLEET_COMMANDER_ABI,
    functionName: 'getCooldown'
  }) as bigint

  return {
    depositCap: BigInt(config[2]),
    minimumBufferBalance: BigInt(config[1]),
    rebalanceCooldown: Number(rebalanceCooldown),
  }
}

// Custom function to read ark config without hre
async function readArkConfig(arkAddress: Address, chain: SupportedChain) {
  const publicClient = createPublicClient({
    chain: VIEM_CHAIN_MAP[chain],
    transport: http(RPC_URL_MAP[chain])
  })

  const [depositCap, maxDepositPercentageOfTVL, maxRebalanceInflow, maxRebalanceOutflow] =
    await Promise.all([
      publicClient.readContract({
        address: arkAddress,
        abi: ARK_ABI,
        functionName: 'depositCap'
      }),
      publicClient.readContract({
        address: arkAddress,
        abi: ARK_ABI,
        functionName: 'maxDepositPercentageOfTVL'
      }),
      publicClient.readContract({
        address: arkAddress,
        abi: ARK_ABI,
        functionName: 'maxRebalanceInflow'
      }),
      publicClient.readContract({
        address: arkAddress,
        abi: ARK_ABI,
        functionName: 'maxRebalanceOutflow'
      })
    ])

  return {
    depositCap: BigInt(depositCap as bigint),
    maxDepositPercentageOfTVL: BigInt(maxDepositPercentageOfTVL as bigint),
    maxRebalanceInflow: BigInt(maxRebalanceInflow as bigint),
    maxRebalanceOutflow: BigInt(maxRebalanceOutflow as bigint),
  }
}

async function createAuctionConfigurationTransaction(
  arkConfig: ArkConfig,
  auctionsConfig: AuctionConfig[],
  chain: SupportedChain,
): Promise<TransactionBase[] | null> {
  // Only configure auction parameters for Morpho and Euler arks
  if (!rewardsConfig[chain] || !rewardsConfig[chain][arkConfig.ark]) {
    return null
  }
  const transactions: TransactionBase[] = []
  // Determine reward token based on ark type
  const rewardTokenSymbols = rewardsConfig[chain][arkConfig.ark]
  for (const rewardTokenSymbol of rewardTokenSymbols) {
    const txes = await handleSingleRewardToken(
      rewardTokenSymbol,
      auctionsConfig,
      chain,
      arkConfig,
    )
    if (txes && txes.length > 0) {
      transactions.push(...txes)
    }
  }
  return transactions
}
async function handleSingleRewardToken(
  rewardTokenSymbol: string,
  auctionsConfig: AuctionConfig[],
  chain: SupportedChain,
  arkConfig: ArkConfig,
) {
  if (rewardTokenSymbol === 'seam' && !arkConfig.arkSymbol.includes('seam')) {
    console.log(
      `Skipping ${rewardTokenSymbol.toUpperCase()} for ${arkConfig.arkSymbol} as it does not support seam`,
    )
    return []
  }
  // Find matching auction config
  const auctionConfig = auctionsConfig.find(
    (config) => config.rewardTokenSymbol.toLowerCase() === rewardTokenSymbol,
  )

  if (!auctionConfig) {
    throw new Error(`No auction configuration found for ${rewardTokenSymbol.toUpperCase()}`)
  }

  // Get base price for the fleet's asset
  const assetKey = arkConfig.fleetAsset.toLowerCase() as Token
  const basePrice = auctionConfig.prices[assetKey]
  if (basePrice === undefined) {
    throw new Error(
      `No price configuration found for asset ${assetKey} in ${rewardTokenSymbol.toUpperCase()} auctions`,
    )
  }

  const assetDecimals = getAssetDecimals(arkConfig.fleetAsset)
  const { startPrice, endPrice } = calculateAuctionMultipliers(basePrice, assetDecimals)
  const duration = parseTimeString(auctionConfig.duration)
  const kickerRewardPercentage = parsePercentage(auctionConfig.kickerRewardPercentage)
  const decayType = auctionConfig.decayType === 'linear' ? 0 : 1

  // Get current auction parameters
  const rewardTokenAddress = chainConfig.config.tokens[rewardTokenSymbol.toLowerCase() as Token]
  if (!rewardTokenAddress || rewardTokenAddress === '0x0000000000000000000000000000000000000000') {
    throw new Error(`No reward token address found for ${auctionConfig.rewardTokenSymbol}`)
  }

  const publicClient = createPublicClient({
    chain: VIEM_CHAIN_MAP[chain],
    transport: http(RPC_URL_MAP[chain])
  })

  const raftAddress = chainConfig.config.deployedContracts.core.raft.address as `0x${string}`

  const isWhitelistedInRaft = await publicClient.readContract({
    address: raftAddress,
    abi: RAFT_ABI,
    functionName: 'sweepableTokens',
    args: [arkConfig.arkAddress, rewardTokenAddress]
  }) as boolean

  const currentAuctionParams = await publicClient.readContract({
    address: raftAddress,
    abi: RAFT_ABI,
    functionName: 'arkAuctionParameters',
    args: [arkConfig.arkAddress, rewardTokenAddress]
  }) as [bigint, bigint, bigint, bigint, bigint]

  const currentDuration = currentAuctionParams[0]
  const currentStartPrice = currentAuctionParams[1]
  const currentEndPrice = currentAuctionParams[2]
  const currentKickerRewardPercentage = currentAuctionParams[3]
  const currentDecayType = currentAuctionParams[4]

  console.log(`\n🔄 Configuring ${arkConfig.ark.toUpperCase()} auction parameters: \n`)
  console.log(`Reward token: ${rewardTokenSymbol.toUpperCase()}`)
  logValueComparison('Duration', currentDuration, duration, ' seconds')
  logValueComparison(
    'Start price',
    currentStartPrice,
    startPrice,
    ` ${arkConfig.fleetAsset}`,
  )
  logValueComparison('End price', currentEndPrice, endPrice, ` ${arkConfig.fleetAsset}`)
  logValueComparison('Kicker reward', currentKickerRewardPercentage, kickerRewardPercentage, ' %')
  logValueComparison('Decay type', currentDecayType, decayType)

  const txes: TransactionBase[] = []
  // Only update if any parameter has changed
  if (
    BigInt(duration) != currentDuration ||
    startPrice !== currentStartPrice ||
    endPrice !== currentEndPrice ||
    kickerRewardPercentage !== currentKickerRewardPercentage ||
    decayType !== Number(currentDecayType)
  ) {
    console.log(
      BigInt(duration) !== currentDuration,
      startPrice !== currentStartPrice,
      endPrice !== currentEndPrice,
      kickerRewardPercentage !== currentKickerRewardPercentage,
      decayType !== Number(currentDecayType),
    )
    const setAuctionParamsCalldata = encodeFunctionData({
      abi: RAFT_ABI,
      functionName: 'setArkAuctionParameters',
      args: [
        arkConfig.arkAddress,
        rewardTokenAddress,
        {
          duration,
          startPrice,
          endPrice,
          kickerRewardPercentage,
          decayType,
        },
      ],
    })

    console.log('📝 Auction parameters update transaction created')
    txes.push({
      to: raftAddress,
      data: setAuctionParamsCalldata,
      value: '0',
    })
  }
  if (!isWhitelistedInRaft) {
    console.log('📝 Adding sweepable token transaction')
    console.log(`Setting ${arkConfig.arkAddress} to sweepable for ${rewardTokenAddress}`)
    const setSweepableTokenCalldata = encodeFunctionData({
      abi: RAFT_ABI,
      functionName: 'setSweepableToken',
      args: [arkConfig.arkAddress, rewardTokenAddress, true],
    })
    txes.push({
      to: raftAddress,
      data: setSweepableTokenCalldata,
      value: '0',
    })
  }
  return txes
}
async function createConfigurationTransactions(
  // fleetDeployment: FleetDeployment,
  arkConfig: ArkConfig,
  auctionsConfig: AuctionConfig[],
  chain: SupportedChain,
  isFirstArkForFleet: boolean,
): Promise<TransactionBase[]> {
  const transactions: TransactionBase[] = []

  // Only set fleet-wide parameters once per fleet
  if (isFirstArkForFleet) {
    console.log(`\n📊 Reading current fleet configuration...`)
    const currentFleetConfig = await readFleetConfig(arkConfig.fleetAddress as Address, chain)

    console.log(`\n🔄 Fleet-wide parameters for ${arkConfig.fleetAddress}:`)

    // Set fleet deposit cap
    const fleetCap = parseAmount(arkConfig.fleetCap, arkConfig.fleetAsset)
    logValueComparison(
      'Fleet deposit cap',
      currentFleetConfig.depositCap,
      fleetCap,
      ` ${arkConfig.fleetAsset}`,
    )
    if (currentFleetConfig.depositCap !== fleetCap) {
      const setFleetCapCalldata = encodeFunctionData({
        abi: FLEET_COMMANDER_ABI,
        functionName: 'setFleetDepositCap',
        args: [fleetCap],
      })
      transactions.push({
        to: arkConfig.fleetAddress,
        data: setFleetCapCalldata,
        value: '0',
      })
    }

    // Set minimum buffer balance
    const minBuffer = parseAmount(arkConfig.FleetMinimumBuffer, arkConfig.fleetAsset)
    logValueComparison(
      'Minimum buffer balance',
      currentFleetConfig.minimumBufferBalance,
      minBuffer,
      ` ${arkConfig.fleetAsset}`,
    )
    if (currentFleetConfig.minimumBufferBalance !== minBuffer) {
      const setMinBufferCalldata = encodeFunctionData({
        abi: FLEET_COMMANDER_ABI,
        functionName: 'setMinimumBufferBalance',
        args: [minBuffer],
      })
      transactions.push({
        to: arkConfig.fleetAddress,
        data: setMinBufferCalldata,
        value: '0',
      })
    }

    // Update rebalance cooldown
    const cooldown = parseTimeString(arkConfig.reallocInterval)
    logValueComparison(
      'Rebalance cooldown',
      currentFleetConfig.rebalanceCooldown,
      cooldown,
      ' seconds',
    )
    if (currentFleetConfig.rebalanceCooldown !== cooldown) {
      const setCooldownCalldata = encodeFunctionData({
        abi: FLEET_COMMANDER_ABI,
        functionName: 'updateRebalanceCooldown',
        args: [cooldown],
      })
      transactions.push({
        to: arkConfig.fleetAddress,
        data: setCooldownCalldata,
        value: '0',
      })
    }
  }

  // Handle auction configuration
  const auctionTransactions = await createAuctionConfigurationTransaction(
    arkConfig,
    // fleetDeployment,
    auctionsConfig,
    chain,
  )

  if (auctionTransactions && auctionTransactions.length > 0) {
    transactions.push(...auctionTransactions)
  }

  // Configure ark parameters
  const arkAddress = arkConfig.arkAddress
  console.log(`\n📊 Reading current ark configuration for ${arkAddress}...`)
  const currentArkConfig = await readArkConfig(arkAddress as Address, chain)

  console.log(`\n🔄 Ark parameters for ${arkConfig.arkSymbol} (${arkConfig.ark}):`)

  // Set ark deposit cap
  const arkCap = parseAmount(arkConfig.arkMaxCap, arkConfig.fleetAsset)

  logValueComparison(
    'Ark deposit cap',
    currentArkConfig.depositCap,
    arkCap,
    ` ${arkConfig.fleetAsset}`,
  )
  if (currentArkConfig.depositCap !== arkCap) {
    const setArkCapCalldata = encodeFunctionData({
      abi: FLEET_COMMANDER_ABI,
      functionName: 'setArkDepositCap',
      args: [arkAddress, arkCap],
    })
    transactions.push({
      to: arkConfig.fleetAddress,
      data: setArkCapCalldata,
      value: '0',
    })
  }

  // Set ark max deposit percentage of TVL
  const maxPercTVL = parsePercentage(arkConfig.arkMaxPercTVL)
  logPercentageComparison(
    'Ark max TVL percentage',
    currentArkConfig.maxDepositPercentageOfTVL,
    maxPercTVL,
    WAD,
  )
  if (currentArkConfig.maxDepositPercentageOfTVL !== maxPercTVL) {
    const setMaxPercTVLCalldata = encodeFunctionData({
      abi: FLEET_COMMANDER_ABI,
      functionName: 'setArkMaxDepositPercentageOfTVL',
      args: [arkAddress, maxPercTVL],
    })
    transactions.push({
      to: arkConfig.fleetAddress,
      data: setMaxPercTVLCalldata,
      value: '0',
    })
  }

  // Set ark max rebalance inflow/outflow
  const maxInflow = parseAmount(arkConfig.arkMaxInflow, arkConfig.fleetAsset)
  const maxOutflow = parseAmount(arkConfig.arkMaxOutflow, arkConfig.fleetAsset)

  logValueComparison(
    'Ark max inflow',
    currentArkConfig.maxRebalanceInflow,
    maxInflow,
    ` ${arkConfig.fleetAsset}`,
  )
  if (currentArkConfig.maxRebalanceInflow !== maxInflow) {
    const setMaxInflowCalldata = encodeFunctionData({
      abi: FLEET_COMMANDER_ABI,
      functionName: 'setArkMaxRebalanceInflow',
      args: [arkAddress, maxInflow],
    })
    transactions.push({
      to: arkConfig.fleetAddress,
      data: setMaxInflowCalldata,
      value: '0',
    })
  }

  logValueComparison(
    'Ark max outflow',
    currentArkConfig.maxRebalanceOutflow,
    maxOutflow,
    ` ${arkConfig.fleetAsset}`,
  )
  if (currentArkConfig.maxRebalanceOutflow !== maxOutflow) {
    const setMaxOutflowCalldata = encodeFunctionData({
      abi: FLEET_COMMANDER_ABI,
      functionName: 'setArkMaxRebalanceOutflow',
      args: [arkAddress, maxOutflow],
    })
    transactions.push({
      to: arkConfig.fleetAddress,
      data: setMaxOutflowCalldata,
      value: '0',
    })
  }

  return transactions
}

async function main() {
  console.log('🚀 Starting fleet configuration update process...\n')

  // Load configurations
  const { arksConfig: allArksConfig,  auctionsConfig } = await loadConfigurations()

  // Process each chain
  for (const chain of SUPPORTED_CHAINS) {
    console.log(`\n🔗 Processing chain: ${chain}`)
    
    const chainConfig = {
      chain: VIEM_CHAIN_MAP[chain],
      chainId: VIEM_CHAIN_MAP[chain].id,
      rpcUrl: RPC_URL_MAP[chain],
    }

    // Filter arks for current chain
    const arksConfig = allArksConfig.filter((arkConfig) => {
      const isMatchingChain = arkConfig.chain.toLowerCase() === chain.toLowerCase()
      if (!isMatchingChain) {
        console.log(
          `⚠️ Skipping ark config for different chain: ${arkConfig.chain} (current: ${chain})`,
        )
      }
      return isMatchingChain
    })

    if (arksConfig.length === 0) {
      console.log(`⚠️ No ark configurations found for chain ${chain}, skipping...`)
      continue
    }

    console.log(`\n📝 Found ${arksConfig.length} ark configurations for ${chain}`)

    const transactions: TransactionBase[] = []
    const configuredFleets = new Set<string>()

    for (const arkConfig of arksConfig) {
      // Skip if no arkAddress is provided
      if (!arkConfig.arkAddress) {
        console.log(
          `⚠️ Skipping ark config without arkAddress for ${arkConfig.chain} ${arkConfig.fleetAsset}`,
        )
        continue
      }

      // Use fleet address as part of the unique key
      const fleetKey = `${arkConfig.chain.toLowerCase()}_${arkConfig.fleetAddress.toLowerCase()}`
      const isFirstArkForFleet = !configuredFleets.has(fleetKey)

      if (isFirstArkForFleet) {
        console.log(
          `\n📝 Configuring new fleet ${arkConfig.fleetAddress} ` +
            `(${arkConfig.fleetAddress}) on ${arkConfig.chain}...`,
        )
        configuredFleets.add(fleetKey)
      }

      const fleetTransactions = await createConfigurationTransactions(
        arkConfig,
        auctionsConfig,
        chain,
        isFirstArkForFleet,
      )
      transactions.push(...fleetTransactions)
    }

    console.log(`\n🔧 Created ${transactions.length} configuration transactions for ${chain}`)

    if (transactions.length > 0) {
      // Create Safe transaction JSON for this chain
      const safeTransactionsJson = {
        version: '1.0',
        chainId: chainConfig.chainId.toString(),
        createdAt: Date.now(),
        meta: {
          name: `Fleet Configuration Update - ${chain}`,
          description: 'Update fleet and ark configurations',
          txBuilderVersion: '1.18.0',
          createdFromSafeAddress: safeAddress,
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
      const outputPath = path.join(__dirname, `../../safe-transactions-${chain}-${Date.now()}.json`)
      fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))
      console.log(`\n✅ Saved transactions to ${outputPath}`)
    } else {
      console.log(`\n⚠️ No transactions needed for ${chain}`)
    }
  }
}

main().catch((error) => {
  console.error('❌ Error:', error)
  process.exit(1)
})
