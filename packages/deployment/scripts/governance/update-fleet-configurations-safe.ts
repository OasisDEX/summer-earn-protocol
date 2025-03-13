import { TransactionBase } from '@safe-global/types-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import hre from 'hardhat'
import path from 'path'
import { Address, encodeFunctionData, getAddress } from 'viem'
import { BaseConfig, Token } from '../../types/config-types'
import { promptForChainFromHre } from '../helpers/chain-prompt'
import { logValueComparison } from '../helpers/fleet-config-reader'

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

interface FleetDeployment {
  fleetName: string
  fleetSymbol: string
  assetSymbol: string
  fleetAddress: string
  bufferArkAddress: string
  network: string
  initialMinimumBufferBalance: string
  initialRebalanceCooldown: string
  depositCap: string
  initialTipRate: string
  arks: string[]
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

  const fleetsPath = path.join(__dirname, '../../deployments/fleets')
  const fleetFiles = fs.readdirSync(fleetsPath)
  const fleetDeployments: FleetDeployment[] = fleetFiles
    .filter((file) => file.endsWith('_deployment.json'))
    .map((file) => JSON.parse(fs.readFileSync(path.join(fleetsPath, file), 'utf-8')))

  return { arksConfig, fleetDeployments, auctionsConfig }
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
const USDC_DECIMALS = 6n
const WETH_DECIMALS = 18n

function getAssetDecimals(assetSymbol: string): bigint {
  switch (assetSymbol) {
    case 'WETH':
      return WETH_DECIMALS
    case 'USDC':
    case 'USDT':
      return USDC_DECIMALS
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
  const endPrice = baseWithDecimals / 10n // 0.1x

  return { startPrice, endPrice }
}

async function createAuctionConfigurationTransaction(
  arkConfig: ArkConfig,
  fleetDeployment: FleetDeployment,
  auctionsConfig: AuctionConfig[],
  chainConfig: ChainConfiguration,
  raft: any, // TODO: Add proper type
): Promise<TransactionBase | null> {
  // Only configure auction parameters for Morpho and Euler arks
  if (!['morpho', 'euler'].includes(arkConfig.ark)) {
    return null
  }

  // Determine reward token based on ark type
  const rewardTokenSymbol = arkConfig.ark === 'morpho' ? 'morpho' : 'reul'

  // Find matching auction config
  const auctionConfig = auctionsConfig.find(
    (config) => config.rewardTokenSymbol.toLowerCase() === rewardTokenSymbol,
  )

  if (!auctionConfig) {
    throw new Error(`No auction configuration found for ${rewardTokenSymbol.toUpperCase()}`)
  }

  // Get base price for the fleet's asset
  const assetKey = fleetDeployment.assetSymbol.toLowerCase() as Token
  const basePrice = auctionConfig.prices[assetKey]
  if (basePrice === undefined) {
    throw new Error(
      `No price configuration found for asset ${assetKey} in ${rewardTokenSymbol.toUpperCase()} auctions`,
    )
  }

  const assetDecimals = getAssetDecimals(fleetDeployment.assetSymbol)
  const { startPrice, endPrice } = calculateAuctionMultipliers(basePrice, assetDecimals)
  const duration = parseTimeString(auctionConfig.duration)
  const kickerRewardPercentage = parsePercentage(auctionConfig.kickerRewardPercentage)
  const decayType = auctionConfig.decayType === 'linear' ? 0 : 1

  // Get current auction parameters
  const rewardTokenAddress = chainConfig.config.tokens[rewardTokenSymbol.toLowerCase() as Token]
  if (!rewardTokenAddress || rewardTokenAddress === '0x0000000000000000000000000000000000000000') {
    throw new Error(`No reward token address found for ${auctionConfig.rewardTokenSymbol}`)
  }

  const currentAuctionParams = (await raft.read.arkAuctionParameters([
    arkConfig.arkAddress,
    rewardTokenAddress,
  ])) as bigint[]

  const currentDuration = currentAuctionParams[0] as bigint
  const currentStartPrice = currentAuctionParams[1] as bigint
  const currentEndPrice = currentAuctionParams[2] as bigint
  const currentKickerRewardPercentage = currentAuctionParams[3] as bigint
  const currentDecayType = currentAuctionParams[4] as bigint

  console.log(`\n🔄 Configuring ${arkConfig.ark.toUpperCase()} auction parameters: \n`)

  logValueComparison('Duration', currentDuration, duration, ' seconds')
  logValueComparison(
    'Start price',
    currentStartPrice,
    startPrice,
    ` ${fleetDeployment.assetSymbol}`,
  )
  logValueComparison('End price', currentEndPrice, endPrice, ` ${fleetDeployment.assetSymbol}`)
  logValueComparison('Kicker reward', currentKickerRewardPercentage, kickerRewardPercentage, ' %')
  logValueComparison('Decay type', currentDecayType, decayType)

  // Only update if any parameter has changed
  if (
    BigInt(duration) !== currentDuration ||
    startPrice !== currentStartPrice ||
    endPrice !== currentEndPrice ||
    kickerRewardPercentage !== currentKickerRewardPercentage ||
    decayType !== Number(currentDecayType)
  ) {
    const setAuctionParamsCalldata = encodeFunctionData({
      abi: raft.abi,
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
    return {
      to: raft.address,
      data: setAuctionParamsCalldata,
      value: '0',
    }
  }

  console.log('✅ Auction parameters are up to date')
  return null
}

async function createConfigurationTransactions(
  fleetDeployment: FleetDeployment,
  arkConfig: ArkConfig,
  auctionsConfig: AuctionConfig[],
  chainConfig: ChainConfiguration,
  isFirstArkForFleet: boolean,
): Promise<TransactionBase[]> {
  const transactions: TransactionBase[] = []

  const configProvider = await hre.viem.getContractAt(
    'FleetCommander' as string,
    fleetDeployment.fleetAddress as `0x${string}`,
  )

  // Only set fleet-wide parameters once per fleet
  // if (isFirstArkForFleet) {
  //   console.log(`\n📊 Reading current fleet configuration...`)
  //   const currentFleetConfig = await readFleetConfig(fleetDeployment.fleetAddress as Address)

  //   console.log(`\n🔄 Fleet-wide parameters for ${fleetDeployment.fleetSymbol}:`)

  //   // Set fleet deposit cap
  //   const fleetCap = parseAmount(arkConfig.fleetCap, fleetDeployment.assetSymbol)
  //   logValueComparison(
  //     'Fleet deposit cap',
  //     currentFleetConfig.depositCap,
  //     fleetCap,
  //     ` ${fleetDeployment.assetSymbol}`,
  //   )
  //   if (currentFleetConfig.depositCap !== fleetCap) {
  //     const setFleetCapCalldata = encodeFunctionData({
  //       abi: configProvider.abi,
  //       functionName: 'setFleetDepositCap',
  //       args: [fleetCap],
  //     })
  //     transactions.push({
  //       to: fleetDeployment.fleetAddress,
  //       data: setFleetCapCalldata,
  //       value: '0',
  //     })
  //   }

  //   // Set minimum buffer balance
  //   const minBuffer = parseAmount(arkConfig.FleetMinimumBuffer, fleetDeployment.assetSymbol)
  //   logValueComparison(
  //     'Minimum buffer balance',
  //     currentFleetConfig.minimumBufferBalance,
  //     minBuffer,
  //     ` ${fleetDeployment.assetSymbol}`,
  //   )
  //   if (currentFleetConfig.minimumBufferBalance !== minBuffer) {
  //     const setMinBufferCalldata = encodeFunctionData({
  //       abi: configProvider.abi,
  //       functionName: 'setMinimumBufferBalance',
  //       args: [minBuffer],
  //     })
  //     transactions.push({
  //       to: fleetDeployment.fleetAddress,
  //       data: setMinBufferCalldata,
  //       value: '0',
  //     })
  //   }

  //   // Update rebalance cooldown
  //   const cooldown = parseTimeString(arkConfig.reallocInterval)
  //   logValueComparison(
  //     'Rebalance cooldown',
  //     currentFleetConfig.rebalanceCooldown,
  //     cooldown,
  //     ' seconds',
  //   )
  //   if (currentFleetConfig.rebalanceCooldown !== cooldown) {
  //     const setCooldownCalldata = encodeFunctionData({
  //       abi: configProvider.abi,
  //       functionName: 'updateRebalanceCooldown',
  //       args: [cooldown],
  //     })
  //     transactions.push({
  //       to: fleetDeployment.fleetAddress,
  //       data: setCooldownCalldata,
  //       value: '0',
  //     })
  //   }
  // }

  // Handle auction configuration
  const raft = await hre.viem.getContractAt(
    'Raft' as string,
    chainConfig.config.deployedContracts.core.raft.address as `0x${string}`,
  )

  const auctionTransaction = await createAuctionConfigurationTransaction(
    arkConfig,
    fleetDeployment,
    auctionsConfig,
    chainConfig,
    raft,
  )

  if (auctionTransaction) {
    transactions.push(auctionTransaction)
  }

  // // Configure ark parameters
  // const arkAddress = arkConfig.arkAddress
  // console.log(`\n📊 Reading current ark configuration for ${arkAddress}...`)
  // const currentArkConfig = await readArkConfig(arkAddress as Address)

  // console.log(`\n🔄 Ark parameters for ${arkConfig.arkSymbol} (${arkConfig.ark}):`)

  // // Set ark deposit cap
  // const arkCap = parseAmount(arkConfig.arkMaxCap, fleetDeployment.assetSymbol)

  // logValueComparison(
  //   'Ark deposit cap',
  //   currentArkConfig.depositCap,
  //   arkCap,
  //   ` ${fleetDeployment.assetSymbol}`,
  // )
  // if (currentArkConfig.depositCap !== arkCap) {
  //   const setArkCapCalldata = encodeFunctionData({
  //     abi: configProvider.abi,
  //     functionName: 'setArkDepositCap',
  //     args: [arkAddress, arkCap],
  //   })
  //   transactions.push({
  //     to: fleetDeployment.fleetAddress,
  //     data: setArkCapCalldata,
  //     value: '0',
  //   })
  // }

  // // Set ark max deposit percentage of TVL
  // const maxPercTVL = parsePercentage(arkConfig.arkMaxPercTVL)
  // logPercentageComparison(
  //   'Ark max TVL percentage',
  //   currentArkConfig.maxDepositPercentageOfTVL,
  //   maxPercTVL,
  //   WAD,
  // )
  // if (currentArkConfig.maxDepositPercentageOfTVL !== maxPercTVL) {
  //   const setMaxPercTVLCalldata = encodeFunctionData({
  //     abi: configProvider.abi,
  //     functionName: 'setArkMaxDepositPercentageOfTVL',
  //     args: [arkAddress, maxPercTVL],
  //   })
  //   transactions.push({
  //     to: fleetDeployment.fleetAddress,
  //     data: setMaxPercTVLCalldata,
  //     value: '0',
  //   })
  // }

  // // Set ark max rebalance inflow/outflow
  // const maxInflow = parseAmount(arkConfig.arkMaxInflow, fleetDeployment.assetSymbol)
  // const maxOutflow = parseAmount(arkConfig.arkMaxOutflow, fleetDeployment.assetSymbol)

  // logValueComparison(
  //   'Ark max inflow',
  //   currentArkConfig.maxRebalanceInflow,
  //   maxInflow,
  //   ` ${fleetDeployment.assetSymbol}`,
  // )
  // if (currentArkConfig.maxRebalanceInflow !== maxInflow) {
  //   const setMaxInflowCalldata = encodeFunctionData({
  //     abi: configProvider.abi,
  //     functionName: 'setArkMaxRebalanceInflow',
  //     args: [arkAddress, maxInflow],
  //   })
  //   transactions.push({
  //     to: fleetDeployment.fleetAddress,
  //     data: setMaxInflowCalldata,
  //     value: '0',
  //   })
  // }

  // logValueComparison(
  //   'Ark max outflow',
  //   currentArkConfig.maxRebalanceOutflow,
  //   maxOutflow,
  //   ` ${fleetDeployment.assetSymbol}`,
  // )
  // if (currentArkConfig.maxRebalanceOutflow !== maxOutflow) {
  //   const setMaxOutflowCalldata = encodeFunctionData({
  //     abi: configProvider.abi,
  //     functionName: 'setArkMaxRebalanceOutflow',
  //     args: [arkAddress, maxOutflow],
  //   })
  //   transactions.push({
  //     to: fleetDeployment.fleetAddress,
  //     data: setMaxOutflowCalldata,
  //     value: '0',
  //   })
  // }

  return transactions
}

async function main() {
  console.log('🚀 Starting fleet configuration update process...\n')

  // Get chain configuration first
  const {
    config: chainDeployConfig,
    chain,
    rpcUrl,
    name: chainName,
  } = await promptForChainFromHre(
    'Automatically detected chain. Confirm execution on this network:',
  )
  const currentChainId: number = chain.id
  console.log(`Selected Chain: ${chainName} (chainId ${currentChainId})`)

  const detectedChainId = hre.network.config.chainId || 'unknown'

  if (detectedChainId !== currentChainId) {
    console.log('❌ Chain ID mismatch detected. Exiting.')
    process.exit(1)
  }

  const chainConfig = {
    chain,
    chainId: chain.id,
    config: chainDeployConfig,
    rpcUrl,
  }

  // Load and filter configurations for current chain
  const { arksConfig: allArksConfig, fleetDeployments, auctionsConfig } = await loadConfigurations()

  // Filter arks for current chain
  const arksConfig = allArksConfig.filter((arkConfig) => {
    const isMatchingChain = arkConfig.chain.toLowerCase() === chainName.toLowerCase()
    if (!isMatchingChain) {
      console.log(
        `⚠️ Skipping ark config for different chain: ${arkConfig.chain} (current: ${chainName})`,
      )
    }
    return isMatchingChain
  })

  if (arksConfig.length === 0) {
    console.log(`❌ No ark configurations found for chain ${chainName}`)
    process.exit(1)
  }

  console.log(`\n📝 Found ${arksConfig.length} ark configurations for ${chainName}`)

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

    // Find matching fleet deployment by address and network
    const matchingFleet = fleetDeployments.find(
      (fleet) =>
        fleet.network === arkConfig.chain.toLowerCase() &&
        fleet.assetSymbol === arkConfig.fleetAsset &&
        fleet.fleetAddress.toLowerCase() === arkConfig.fleetAddress.toLowerCase(),
    )

    if (!matchingFleet) {
      console.log(
        `⚠️ No matching fleet found for ${arkConfig.chain} ${arkConfig.fleetAsset} ` +
          `at address ${arkConfig.fleetAddress}`,
      )
      throw new Error(
        `No matching fleet found for ${arkConfig.chain} ${arkConfig.fleetAsset} at address ${arkConfig.fleetAddress}`,
      )
    }

    // Use fleet address as part of the unique key
    const fleetKey = `${matchingFleet.network}_${matchingFleet.fleetAddress.toLowerCase()}`
    const isFirstArkForFleet = !configuredFleets.has(fleetKey)

    if (isFirstArkForFleet) {
      console.log(
        `\n📝 Configuring new fleet ${matchingFleet.fleetSymbol} ` +
          `(${matchingFleet.fleetAddress}) on ${matchingFleet.network}...`,
      )
      configuredFleets.add(fleetKey)
    }

    // Verify the ark address exists in the fleet
    if (
      !matchingFleet.arks.some((ark) => ark.toLowerCase() === arkConfig.arkAddress.toLowerCase())
    ) {
      console.log(`⚠️ Ark ${arkConfig.arkAddress} not found in fleet ${matchingFleet.fleetSymbol}`)
      continue
    }

    const fleetTransactions = await createConfigurationTransactions(
      matchingFleet,
      arkConfig,
      auctionsConfig,
      chainConfig,
      isFirstArkForFleet,
    )
    transactions.push(...fleetTransactions)
  }

  console.log(`\n🔧 Created ${transactions.length} configuration transactions`)

  // const deployer = getAddress((await hre.viem.getWalletClients())[0].account.address)
  // await proposeAllSafeTransactions(
  //   transactions,
  //   deployer,
  //   safeAddress,
  //   Number(hre.network.config.chainId),
  //   chainConfig.rpcUrl,
  //   process.env.CURATOR_MULTISIG_PROPOSER_PRIV_KEY as Address,
  // )

  // Replace Safe proposal with JSON export
  const safeTransactionsJson = {
    version: '1.0',
    chainId: hre.network.config.chainId?.toString(),
    createdAt: Date.now(),
    meta: {
      name: 'Fleet Configuration Update',
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
  const outputPath = path.join(__dirname, `../../safe-transactions-${chainName}-${Date.now()}.json`)
  fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))
  console.log(`\n✅ Saved transactions to ${outputPath}`)
}

main().catch((error) => {
  console.error('❌ Error:', error)
  process.exit(1)
})
