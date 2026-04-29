import {
  createWalletClient,
  createPublicClient,
  http,
  type Address,
  type Hex,
  parseAbiItem,
  getAddress,
  zeroAddress,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { getRpcUrl, getChain } from './config'
import { z } from 'zod'
import {
  DeploymentFileSchema,
  YieldDeploymentFileSchema,
  type YieldEntry,
  type YieldDeploymentFile,
  type DeploymentFile,
} from './schemas'
import fs from 'fs'
import path from 'path'

const TestYieldFactoryJson = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, '../../rwa-oracles/out/TestYieldFactory.sol/TestYieldFactory.json'),
    'utf8',
  ),
)

const USDC_ADDRESSES: Record<string, Address> = {
  base: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
  mainnet: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
  arbitrum: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
}

const ConfigSchema = z.object({
  PRIVATE_KEYS: z.string().transform((val) => val.split(',').map((k) => k.trim()) as Hex[]),
})

const oracleDeploymentsPath = path.join(__dirname, './deployments.json')
const yieldDeploymentsPath = path.join(__dirname, './yield-deployments.json')
const dashboardYieldDeploymentsPath = path.join(
  __dirname,
  '../../oracle-dashboard/lib/yield-deployments.json',
)

function loadOracleDeployments(): DeploymentFile {
  if (!fs.existsSync(oracleDeploymentsPath)) {
    throw new Error(`Oracle deployments not found at ${oracleDeploymentsPath}`)
  }
  return DeploymentFileSchema.parse(JSON.parse(fs.readFileSync(oracleDeploymentsPath, 'utf8')))
}

function loadYieldDeployments(): YieldDeploymentFile {
  if (!fs.existsSync(yieldDeploymentsPath)) return {}
  return YieldDeploymentFileSchema.parse(JSON.parse(fs.readFileSync(yieldDeploymentsPath, 'utf8')))
}

function saveYieldDeployments(deployments: YieldDeploymentFile) {
  fs.writeFileSync(yieldDeploymentsPath, JSON.stringify(deployments, null, 2))
  if (fs.existsSync(path.dirname(dashboardYieldDeploymentsPath))) {
    fs.writeFileSync(dashboardYieldDeploymentsPath, JSON.stringify(deployments, null, 2))
  }
}

export async function deployYieldSystem(forcedFactory?: Address) {
  const env = ConfigSchema.parse(process.env)
  const account = privateKeyToAccount(env.PRIVATE_KEYS[0])

  const oracleDeployments = loadOracleDeployments()
  const yieldDeployments = loadYieldDeployments()

  for (const [networkKey, oracleChainData] of Object.entries(oracleDeployments)) {
    // Standardized network key from deployments.json
    const network = networkKey

    // Skip if no oracles
    if (oracleChainData.oracles.length === 0) continue

    console.log(`\n--- Processing ${network} (${oracleChainData.oracles.length} oracles) ---`)

    const usdcAddress = USDC_ADDRESSES[network]
    if (!usdcAddress) {
      console.warn(`No USDC address configured for ${network}, skipping...`)
      continue
    }

    // Setup clients
    let chain
    try {
      chain = getChain(network as any)
    } catch (e) {
      console.warn(`Skipping unknown network ${network}`)
      continue
    }

    const rpcUrl = getRpcUrl(network as any)

    const walletClient = createWalletClient({
      account,
      chain,
      transport: http(rpcUrl),
    })
    const publicClient = createPublicClient({
      chain,
      transport: http(rpcUrl),
    })

    // Prepare yield deployment record for this chain
    let yieldChainDeploy = yieldDeployments[networkKey]
    if (!yieldChainDeploy) {
      yieldChainDeploy = {
        chainId: chain.id,
        factoryAddress: zeroAddress,
        tokens: [],
      }
      yieldDeployments[networkKey] = yieldChainDeploy
    }

    // 1. Ensure Factory
    let factory = yieldChainDeploy.factoryAddress as Address

    if (forcedFactory) {
      console.log(`Using configured factory: ${forcedFactory}`)
      factory = forcedFactory
      yieldChainDeploy.factoryAddress = factory
    } else if (!factory || factory === zeroAddress) {
      console.log('Deploying TestYieldFactory...')
      if (!TestYieldFactoryJson.bytecode || !TestYieldFactoryJson.bytecode.object) {
        throw new Error('TestYieldFactory bytecode not found in JSON')
      }

      const hash = await walletClient.deployContract({
        abi: TestYieldFactoryJson.abi as any,
        bytecode: TestYieldFactoryJson.bytecode.object as Hex,
        args: [account.address],
      })
      console.log(`Factory deployment tx: ${hash}`)

      const receipt = await publicClient.waitForTransactionReceipt({ hash })
      if (!receipt.contractAddress) throw new Error('Factory deployment failed')

      factory = receipt.contractAddress
      console.log(`TestYieldFactory deployed at: ${factory}`)
      yieldChainDeploy.factoryAddress = factory
      saveYieldDeployments(yieldDeployments)
    } else {
      console.log(`Using existing TestYieldFactory at: ${factory}`)
    }

    // 2. Deploy Tokens for each Oracle
    for (const oracleEntry of oracleChainData.oracles) {
      const { ticker, oracleAddress } = oracleEntry
      console.log(`Processing ${ticker}...`)

      // Check local record
      const existingEntry = yieldChainDeploy.tokens.find((t) => t.ticker === ticker)

      // Check on-chain
      const onChainAddress = (await publicClient.readContract({
        address: factory,
        abi: TestYieldFactoryJson.abi as any,
        functionName: 'tickers',
        args: [ticker],
      })) as Address

      if (onChainAddress && onChainAddress !== zeroAddress) {
        console.log(`  -> Already deployed at ${onChainAddress}`)

        if (!existingEntry || existingEntry.yieldTokenAddress !== onChainAddress) {
          const pocket = (await publicClient.readContract({
            address: onChainAddress,
            abi: [parseAbiItem('function getPocket() external view returns (address)')],
            functionName: 'getPocket',
          })) as Address

          const entry: YieldEntry = {
            ticker,
            yieldTokenAddress: onChainAddress,
            pocketAddress: pocket,
            usdcAddress: usdcAddress,
            oracleAddress: oracleAddress as Address,
          }

          if (existingEntry) {
            Object.assign(existingEntry, entry)
          } else {
            yieldChainDeploy.tokens.push(entry)
          }
          saveYieldDeployments(yieldDeployments)
        }
        continue
      }

      // Deploy new
      console.log(`  -> Deploying new Yield Token...`)
      const { request } = await publicClient.simulateContract({
        account,
        address: factory,
        abi: TestYieldFactoryJson.abi as any,
        functionName: 'deployYieldToken',
        args: [`Test Yield ${ticker}`, ticker, usdcAddress, oracleAddress],
      })

      const hash = await walletClient.writeContract(request)
      console.log(`  -> Tx: ${hash}`)

      const receipt = await publicClient.waitForTransactionReceipt({ hash })

      const logs = await publicClient.getContractEvents({
        address: factory,
        abi: TestYieldFactoryJson.abi as any,
        eventName: 'YieldTokenDeployed',
        fromBlock: receipt.blockNumber,
        toBlock: receipt.blockNumber,
      })

      const log = (logs as any[]).find((l: any) => l.args.ticker === ticker)
      if (!log) {
        console.error(`  -> Failed to find deployment event for ${ticker}`)
        continue
      }

      const args = log.args as any
      console.log(`  -> Deployed at ${args.token}`)

      const entry: YieldEntry = {
        ticker,
        yieldTokenAddress: args.token as Address,
        pocketAddress: args.pocket as Address,
        usdcAddress: usdcAddress,
        oracleAddress: oracleAddress as Address,
      }
      yieldChainDeploy.tokens.push(entry)
      saveYieldDeployments(yieldDeployments)
    }
  }
}
