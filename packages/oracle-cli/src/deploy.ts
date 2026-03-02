import {
  createWalletClient,
  createPublicClient,
  http,
  type Address,
  type Hex,
  parseAbi,
  getAddress,
  zeroAddress,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import path from 'path'
import { getChain, getRpcUrl } from './config'

import fs from 'fs'
import {
  DeploymentInputSchema,
  DeploymentFileSchema,
  type OracleEntry,
  type ChainDeployment,
  type DeploymentFile,
  PrivateKeySchema,
} from './schemas'
import dotenv from 'dotenv'
dotenv.config()

// Load ABIs and Bytecode
const RwaOracleArtifact = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, '../../rwa-oracles/out/RwaOracle.sol/RwaOracle.json'),
    'utf8',
  ),
)
const OracleRegistryArtifact = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, '../../rwa-oracles/out/OracleRegistry.sol/OracleRegistry.json'),
    'utf8',
  ),
)

const deploymentsPath = path.join(__dirname, './deployments.json')
const dashboardDeploymentsPath = path.join(__dirname, '../../oracle-dashboard/lib/deployments.json')
const deployResultsPath = path.join(__dirname, '../deploy-results.json')

const NETWORK_TO_CHAIN_ID: Record<string, number> = {
  mainnet: 1,
  ethereum: 1,
  base: 8453,
  arbitrum: 42161,
  sonic: 146,
  hyperliquid: 999,
}

/** Map config network to deployment file key (mainnet <-> ethereum) */
function toDeploymentKey(network: string): string {
  return network === 'mainnet' ? 'ethereum' : network
}

function loadOrMigrateDeployments(): DeploymentFile {
  const raw = JSON.parse(fs.readFileSync(deploymentsPath, 'utf8'))
  const migrated: Record<string, ChainDeployment> = {}
  for (const [network, data] of Object.entries(raw) as [string, unknown][]) {
    const d = data as { oracleRegistry?: string; chainId?: number; oracles?: OracleEntry[] }
    migrated[network] = {
      chainId: d.chainId ?? NETWORK_TO_CHAIN_ID[network] ?? 1,
      oracleRegistry: d.oracleRegistry ?? zeroAddress,
      oracles: Array.isArray(d.oracles) ? d.oracles : [],
    }
  }

  // One-time migration: merge from deploy-results.json if it exists
  let didMigrate = false
  if (fs.existsSync(deployResultsPath)) {
    const results = JSON.parse(fs.readFileSync(deployResultsPath, 'utf8')) as Array<{
      ticker: string
      asset: string
      oracle: string
      status: string
      network: string
    }>
    for (const r of results) {
      if ((r.status === 'deployed' || r.status === 'skipped') && r.oracle !== '0x0') {
        const key = toDeploymentKey(r.network)
        const chain = migrated[key]
        if (
          chain &&
          !chain.oracles.some((o) => o.assetAddress.toLowerCase() === r.asset.toLowerCase())
        ) {
          chain.oracles.push({
            ticker: r.ticker,
            assetAddress: getAddress(r.asset),
            oracleAddress: getAddress(r.oracle),
            type: 'WisdomTree',
            subtype: 'variableNav',
          })
          didMigrate = true
        }
      }
    }
    if (didMigrate) console.log('Migrated oracles from deploy-results.json')
  }

  const parsed = DeploymentFileSchema.parse(migrated)
  if (didMigrate) {
    fs.writeFileSync(deploymentsPath, JSON.stringify(parsed, null, 2))
    if (fs.existsSync(path.dirname(dashboardDeploymentsPath))) {
      fs.writeFileSync(dashboardDeploymentsPath, JSON.stringify(parsed, null, 2))
    }
  }
  return parsed
}

function saveDeployments(deployments: DeploymentFile) {
  const validated = DeploymentFileSchema.parse(deployments)
  fs.writeFileSync(deploymentsPath, JSON.stringify(validated, null, 2))
  if (fs.existsSync(path.dirname(dashboardDeploymentsPath))) {
    fs.writeFileSync(dashboardDeploymentsPath, JSON.stringify(validated, null, 2))
  }
}

function upsertOracle(chain: ChainDeployment, entry: OracleEntry) {
  const idx = chain.oracles.findIndex(
    (o) => o.assetAddress.toLowerCase() === entry.assetAddress.toLowerCase(),
  )
  if (idx >= 0) {
    chain.oracles[idx] = entry
  } else {
    chain.oracles.push(entry)
  }
}

async function main() {
  const inputPath = process.argv[2] || 'deploy-input.json'
  if (!fs.existsSync(inputPath)) {
    console.error(`Input file not found: ${inputPath}`)
    process.exit(1)
  }

  const rawInput = JSON.parse(fs.readFileSync(inputPath, 'utf8'))
  const parsed = DeploymentInputSchema.parse(rawInput)
  const configs = Array.isArray(parsed) ? parsed : [parsed]
  console.log(process.env.DEPLOYER_PRIV_KEY)
  const privateKey = PrivateKeySchema.parse(process.env.DEPLOYER_PRIV_KEY)
  if (!privateKey) throw new Error('DEPLOYER_PRIV_KEY not set in env')
  const account = privateKeyToAccount(privateKey as `0x${string}`)

  const deployments = loadOrMigrateDeployments()

  for (const config of configs) {
    const normalizedAddress = getAddress(config.assetAddress)
    console.log(`\n--- Processing ${normalizedAddress} on ${config.network} ---`)

    try {
      const chain = getChain(config.network)
      const rpcUrl = getRpcUrl(config.network)

      const publicClient = createPublicClient({ chain, transport: http(rpcUrl) })
      const walletClient = createWalletClient({ account, chain, transport: http(rpcUrl) })

      const deployKey = toDeploymentKey(config.network)
      const chainDeploy = deployments[deployKey] ?? {
        chainId: chain.id,
        oracleRegistry: zeroAddress,
        oracles: [],
      }
      if (!deployments[deployKey]) {
        deployments[deployKey] = chainDeploy
      }

      let registryAddress = getAddress(chainDeploy.oracleRegistry)

      if (!registryAddress || registryAddress === zeroAddress) {
        console.log('Deploying OracleRegistry...')
        const hash = await walletClient.deployContract({
          abi: OracleRegistryArtifact.abi,
          bytecode: OracleRegistryArtifact.bytecode.object,
          args: [account.address],
        })
        const receipt = await publicClient.waitForTransactionReceipt({ hash })
        registryAddress = receipt.contractAddress!
        console.log(`OracleRegistry deployed at: ${registryAddress}`)

        chainDeploy.oracleRegistry = registryAddress
        chainDeploy.chainId = chain.id
      } else {
        console.log(`Using Registry at: ${registryAddress}`)
      }

      const existingOracle = await publicClient.readContract({
        address: registryAddress,
        abi: OracleRegistryArtifact.abi,
        functionName: 'getOracleByAsset',
        args: [normalizedAddress],
      })

      if (existingOracle && existingOracle !== zeroAddress) {
        console.log(`Oracle already exists at ${existingOracle}. Skipped.`)
        const existingTicker = (await publicClient.readContract({
          address: registryAddress,
          abi: OracleRegistryArtifact.abi,
          functionName: 'oracleToTicker',
          args: [existingOracle],
        })) as string

        upsertOracle(chainDeploy, {
          ticker: existingTicker,
          assetAddress: normalizedAddress,
          oracleAddress: existingOracle as Address,
          type: config.type,
          subtype: config.subtype,
        })
        saveDeployments(deployments)
        continue
      }

      console.log(`Fetching symbol for asset ${normalizedAddress}...`)
      const ticker = (await publicClient.readContract({
        address: normalizedAddress,
        abi: parseAbi(['function symbol() view returns (string)']),
        functionName: 'symbol',
      })) as string
      console.log(`Ticker: ${ticker}`)

      const description = config.description || `Oracle for ${ticker}`
      const signers = config.signers as Address[]
      const threshold = BigInt(config.threshold)

      console.log(`Deploying RwaOracle...`)
      const hash = await walletClient.deployContract({
        abi: RwaOracleArtifact.abi,
        bytecode: RwaOracleArtifact.bytecode.object,
        args: [description, signers, threshold, account.address],
      })
      const receipt = await publicClient.waitForTransactionReceipt({ hash })
      const oracleAddress = receipt.contractAddress!
      console.log(`RwaOracle deployed at: ${oracleAddress}`)

      console.log(`Registering ${ticker} in Registry...`)
      const regHash = await walletClient.writeContract({
        address: registryAddress,
        abi: OracleRegistryArtifact.abi,
        functionName: 'setOracle',
        args: [ticker, normalizedAddress, oracleAddress],
      })
      await publicClient.waitForTransactionReceipt({ hash: regHash })
      console.log(`Registered!`)

      upsertOracle(chainDeploy, {
        ticker,
        assetAddress: normalizedAddress,
        oracleAddress,
        type: config.type,
        subtype: config.subtype,
      })
      saveDeployments(deployments)
    } catch (error: unknown) {
      console.error(`Failed to process ${normalizedAddress}:`, error)
      // Do not add failed oracles to deployments
    }
  }

  console.log('\nDeployment complete. Summary:')
  for (const [network, chain] of Object.entries(deployments)) {
    console.log(`  ${network}: ${chain.oracles.length} oracles`)
  }
}

main().catch(console.error)
