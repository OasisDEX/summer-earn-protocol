import hre from 'hardhat'
import fs from 'fs'
import path from 'path'
import { Address, getAddress } from 'viem'
import chalk from 'chalk'

// Constants
const WAD = BigInt(1e18)
const SIX_DECIMALS = 6n
const EIGHTEEN_DECIMALS = 18n
const MAX_UINT256 = BigInt(
  '115792089237316195423570985008687907853269984665640564039457584007913129639935',
)

// Fleet Commander ABI
const FLEET_COMMANDER_ABI = [
  {
    inputs: [],
    name: 'getActiveArks',
    outputs: [{ name: '', type: 'address[]' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getConfig',
    outputs: [
      { name: 'bufferArk', type: 'address' },
      { name: 'depositCap', type: 'uint256' },
      { name: 'minimumBufferBalance', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'cap', type: 'uint256' }],
    name: 'setFleetDepositCap',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'cap', type: 'uint256' },
    ],
    name: 'setArkDepositCap',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'percentage', type: 'uint256' },
    ],
    name: 'setArkMaxDepositPercentageOfTVL',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    name: 'setArkMaxRebalanceInflow',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'arkAddress', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    name: 'setArkMaxRebalanceOutflow',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

// Ark ABI for reading values
const ARK_ABI = [
  {
    inputs: [],
    name: 'depositCap',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'maxDepositPercentageOfTVL',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'maxRebalanceInflow',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'maxRebalanceOutflow',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

interface FleetDeployment {
  fleetName: string
  isBummer?: boolean
  fleetSymbol: string
  assetSymbol: string
  fleetAddress: Address
  bufferArkAddress: Address
  network: string
  arks: Address[]
  initialMinimumBufferBalance?: string
  initialRebalanceCooldown?: string
  depositCap?: string
  initialTipRate?: string
}

/**
 * Get asset decimals based on asset symbol
 */
function getAssetDecimals(assetSymbol: string): bigint {
  const symbol = assetSymbol.toLowerCase()
  if (symbol === 'usdc' || symbol === 'usdce' || symbol === 'usdt' || symbol === 'eurc') {
    return SIX_DECIMALS
  }
  if (symbol === 'weth' || symbol === 'eth') {
    return EIGHTEEN_DECIMALS
  }
  throw new Error(`Unknown asset symbol: ${assetSymbol}`)
}

/**
 * Parse amount with appropriate decimals
 * Supports both integer amounts (e.g., 100) and decimal amounts (e.g., 0.1)
 */
function parseAmount(amount: number, assetSymbol: string): bigint {
  const decimals = getAssetDecimals(assetSymbol)
  // Handle decimal amounts (e.g., 0.1 ETH)
  if (amount < 1) {
    return BigInt(Math.floor(amount * Number(10n ** decimals)))
  }
  return BigInt(amount) * BigInt(10 ** Number(decimals))
}

/**
 * Load all fleet deployment files
 */
function loadFleetDeployments(): FleetDeployment[] {
  const deploymentsDir = path.join(process.cwd(), 'deployments', 'fleets')

  if (!fs.existsSync(deploymentsDir)) {
    console.log(chalk.yellow(`Deployments directory not found: ${deploymentsDir}`))
    return []
  }

  const files = fs.readdirSync(deploymentsDir).filter((file) => file.endsWith('.json'))
  const deployments: FleetDeployment[] = []

  for (const file of files) {
    try {
      const filePath = path.join(deploymentsDir, file)
      const content = fs.readFileSync(filePath, 'utf-8')
      const deployment = JSON.parse(content) as FleetDeployment

      // Only include Bummer fleets
      if (deployment.isBummer === true) {
        // Ensure addresses are properly formatted
        deployment.fleetAddress = getAddress(deployment.fleetAddress)
        deployment.bufferArkAddress = getAddress(deployment.bufferArkAddress)
        deployment.arks = deployment.arks.map((ark) => getAddress(ark))
        deployments.push(deployment)
      }
    } catch (error) {
      console.log(chalk.yellow(`Error loading ${file}: ${error}`))
    }
  }

  return deployments
}

/**
 * Get all ark addresses for a fleet (from deployment file or contract)
 */
async function getFleetArks(fleetAddress: Address, deploymentArks: Address[]): Promise<Address[]> {
  try {
    const publicClient = await hre.viem.getPublicClient()
    const activeArks = (await publicClient.readContract({
      address: fleetAddress,
      abi: FLEET_COMMANDER_ABI,
      functionName: 'getActiveArks',
    })) as Address[]

    // Combine deployment arks with active arks, removing duplicates
    const allArks = new Set<Address>()
    deploymentArks.forEach((ark) => allArks.add(getAddress(ark)))
    activeArks.forEach((ark) => allArks.add(getAddress(ark)))

    return Array.from(allArks)
  } catch (error) {
    console.log(
      chalk.yellow(
        `Could not fetch active arks from contract, using deployment file arks: ${error}`,
      ),
    )
    return deploymentArks
  }
}

/**
 * Configure a single fleet
 */
async function configureFleet(deployment: FleetDeployment): Promise<void> {
  const network = hre.network.name
  const assetSymbol = deployment.assetSymbol

  console.log(chalk.blue(`\n📋 Configuring fleet: ${deployment.fleetName}`))
  console.log(chalk.gray(`   Network: ${network}`))
  console.log(chalk.gray(`   Fleet Address: ${deployment.fleetAddress}`))
  console.log(chalk.gray(`   Asset: ${assetSymbol}`))

  // Get all ark addresses
  const arks = await getFleetArks(deployment.fleetAddress, deployment.arks)
  console.log(chalk.gray(`   Found ${arks.length} arks`))

  // Determine deposit cap values based on asset
  const isStablecoin = ['usdc', 'usdce', 'usdt'].includes(assetSymbol.toLowerCase())
  const isEth = ['weth', 'eth'].includes(assetSymbol.toLowerCase())

  if (!isStablecoin && !isEth) {
    console.log(chalk.yellow(`   ⚠️  Skipping fleet with unsupported asset: ${assetSymbol}`))
    return
  }

  const fleetDepositCap = isStablecoin
    ? parseAmount(100, assetSymbol)
    : parseAmount(0.1, assetSymbol)
  const arkDepositCap = isStablecoin ? parseAmount(100, assetSymbol) : parseAmount(0.1, assetSymbol)
  const maxPercentage = 100n * WAD // 100% = 100 * 1e18

  // Get wallet client (default signer)
  const [walletClient] = await hre.viem.getWalletClients()
  const publicClient = await hre.viem.getPublicClient()
  const deployerAddress = walletClient.account.address
  console.log(chalk.gray(`   Deployer: ${deployerAddress}`))

  // Get initial nonce and manage it manually for HyperEVM compatibility
  let nonce = await publicClient.getTransactionCount({
    address: deployerAddress,
    blockTag: 'pending',
  })
  console.log(chalk.gray(`   Starting nonce: ${nonce}`))

  // Read current fleet config
  console.log(chalk.cyan(`   Reading current fleet configuration...`))
  const fleetConfig = (await publicClient.readContract({
    address: deployment.fleetAddress,
    abi: FLEET_COMMANDER_ABI,
    functionName: 'getConfig',
  })) as [Address, bigint, bigint]

  const currentFleetDepositCap = fleetConfig[1]

  // Set fleet deposit cap (only if different)
  if (currentFleetDepositCap !== fleetDepositCap) {
    try {
      console.log(
        chalk.cyan(
          `   Setting fleet deposit cap to ${isStablecoin ? '100' : '0.1'} ${assetSymbol}...`,
        ),
      )
      console.log(
        chalk.gray(
          `      Current: ${currentFleetDepositCap.toString()}, Target: ${fleetDepositCap.toString()}`,
        ),
      )
      const hash = await walletClient.writeContract({
        address: deployment.fleetAddress,
        abi: FLEET_COMMANDER_ABI,
        functionName: 'setFleetDepositCap',
        args: [fleetDepositCap],
        nonce: nonce++,
      })

      console.log(chalk.green(`   ✅ Fleet deposit cap set. Tx: ${hash} (nonce: ${nonce - 1})`))
    } catch (error) {
      console.log(chalk.red(`   ❌ Failed to set fleet deposit cap: ${error}`))
      throw error
    }
  } else {
    console.log(
      chalk.green(
        `   ✅ Fleet deposit cap already set correctly (${currentFleetDepositCap.toString()})`,
      ),
    )
  }

  // Configure each ark
  for (const arkAddress of arks) {
    console.log(chalk.cyan(`   Configuring ark: ${arkAddress}`))

    try {
      // Read current ark config
      const [currentArkDepositCap, currentMaxPerc, currentMaxInflow, currentMaxOutflow] =
        await Promise.all([
          publicClient.readContract({
            address: arkAddress,
            abi: ARK_ABI,
            functionName: 'depositCap',
          }),
          publicClient.readContract({
            address: arkAddress,
            abi: ARK_ABI,
            functionName: 'maxDepositPercentageOfTVL',
          }),
          publicClient.readContract({
            address: arkAddress,
            abi: ARK_ABI,
            functionName: 'maxRebalanceInflow',
          }),
          publicClient.readContract({
            address: arkAddress,
            abi: ARK_ABI,
            functionName: 'maxRebalanceOutflow',
          }),
        ])

      // Set ark deposit cap (only if different)
      if (BigInt(currentArkDepositCap as bigint) !== arkDepositCap) {
        console.log(
          chalk.gray(
            `      Current ark deposit cap: ${currentArkDepositCap.toString()}, Target: ${arkDepositCap.toString()}`,
          ),
        )
        const arkCapHash = await walletClient.writeContract({
          address: deployment.fleetAddress,
          abi: FLEET_COMMANDER_ABI,
          functionName: 'setArkDepositCap',
          args: [arkAddress, arkDepositCap],
          nonce: nonce++,
        })
        console.log(
          chalk.green(
            `      ✅ Ark deposit cap set to ${isStablecoin ? '100' : '0.1'} ${assetSymbol}. Tx: ${arkCapHash} (nonce: ${nonce - 1})`,
          ),
        )
      } else {
        console.log(
          chalk.green(
            `      ✅ Ark deposit cap already set correctly (${currentArkDepositCap.toString()})`,
          ),
        )
      }

      // Set max deposit percentage to 100% (only if different)
      if (BigInt(currentMaxPerc as bigint) !== maxPercentage) {
        console.log(
          chalk.gray(
            `      Current max percentage: ${currentMaxPerc.toString()}, Target: ${maxPercentage.toString()}`,
          ),
        )
        const maxPercHash = await walletClient.writeContract({
          address: deployment.fleetAddress,
          abi: FLEET_COMMANDER_ABI,
          functionName: 'setArkMaxDepositPercentageOfTVL',
          args: [arkAddress, maxPercentage],
          nonce: nonce++,
        })
        console.log(
          chalk.green(
            `      ✅ Max deposit percentage set to 100%. Tx: ${maxPercHash} (nonce: ${nonce - 1})`,
          ),
        )
      } else {
        console.log(
          chalk.green(
            `      ✅ Max deposit percentage already set correctly (${currentMaxPerc.toString()})`,
          ),
        )
      }

      // Set max rebalance inflow to max uint256 (only if different)
      if (BigInt(currentMaxInflow as bigint) !== MAX_UINT256) {
        console.log(
          chalk.gray(
            `      Current max inflow: ${currentMaxInflow.toString()}, Target: ${MAX_UINT256.toString()}`,
          ),
        )
        const maxInflowHash = await walletClient.writeContract({
          address: deployment.fleetAddress,
          abi: FLEET_COMMANDER_ABI,
          functionName: 'setArkMaxRebalanceInflow',
          args: [arkAddress, MAX_UINT256],
          nonce: nonce++,
        })
        console.log(
          chalk.green(
            `      ✅ Max rebalance inflow set to max uint256. Tx: ${maxInflowHash} (nonce: ${nonce - 1})`,
          ),
        )
      } else {
        console.log(
          chalk.green(`      ✅ Max rebalance inflow already set correctly (max uint256)`),
        )
      }

      // Set max rebalance outflow to max uint256 (only if different)
      if (BigInt(currentMaxOutflow as bigint) !== MAX_UINT256) {
        console.log(
          chalk.gray(
            `      Current max outflow: ${currentMaxOutflow.toString()}, Target: ${MAX_UINT256.toString()}`,
          ),
        )
        const maxOutflowHash = await walletClient.writeContract({
          address: deployment.fleetAddress,
          abi: FLEET_COMMANDER_ABI,
          functionName: 'setArkMaxRebalanceOutflow',
          args: [arkAddress, MAX_UINT256],
          nonce: nonce++,
        })
        console.log(
          chalk.green(
            `      ✅ Max rebalance outflow set to max uint256. Tx: ${maxOutflowHash} (nonce: ${nonce - 1})`,
          ),
        )
      } else {
        console.log(
          chalk.green(`      ✅ Max rebalance outflow already set correctly (max uint256)`),
        )
      }
    } catch (error) {
      console.log(chalk.red(`      ❌ Failed to configure ark ${arkAddress}: ${error}`))
      throw error
    }
  }

  console.log(chalk.gray(`   Final nonce: ${nonce}`))

  console.log(chalk.green(`\n✅ Successfully configured fleet: ${deployment.fleetName}`))
}

/**
 * Main function
 */
async function main() {
  console.log(chalk.bold.blue('\n🚀 Starting Bummer Fleet Configuration Script\n'))

  const network = hre.network.name
  console.log(chalk.cyan(`Network: ${network}`))

  // Load all Bummer fleet deployments
  const deployments = loadFleetDeployments()

  if (deployments.length === 0) {
    console.log(chalk.yellow('⚠️  No Bummer fleet deployments found'))
    return
  }

  console.log(chalk.green(`\n📦 Found ${deployments.length} Bummer fleet(s) to configure\n`))

  // Filter deployments for current network
  const networkDeployments = deployments.filter(
    (deployment) => deployment.network.toLowerCase() === network.toLowerCase(),
  )

  if (networkDeployments.length === 0) {
    console.log(chalk.yellow(`⚠️  No Bummer fleet deployments found for network: ${network}`))
    return
  }

  console.log(chalk.cyan(`📋 Found ${networkDeployments.length} Bummer fleet(s) on ${network}\n`))

  // Configure each fleet
  for (const deployment of networkDeployments) {
    try {
      await configureFleet(deployment)
    } catch (error) {
      console.log(chalk.red(`\n❌ Failed to configure fleet ${deployment.fleetName}: ${error}`))
      // Continue with next fleet
    }
  }

  console.log(chalk.bold.green('\n✨ Configuration complete!\n'))
}

main().catch((error) => {
  console.error(chalk.red('❌ Error:'), error)
  process.exit(1)
})
