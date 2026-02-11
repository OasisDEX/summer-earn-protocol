import { Command } from 'commander'
import {
  createWalletClient,
  createPublicClient,
  http,
  type Address,
  type Hex,
  parseUnits,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { base } from 'viem/chains'
import { getRpcUrl } from './config'

import { z } from 'zod'
import { fetchOracleData } from './fetcher'
import { signPriceData } from './signer'
import { RWA_ORACLE_ABI, ORACLE_REGISTRY_ABI } from './constants'
import { DeploymentFileSchema } from './schemas'
import deploymentsData from './deployments.json'

// Configuration Schema - RPC URLs via config.getRpcUrl()
const ConfigSchema = z.object({
  PRIVATE_KEYS: z.string().transform((val) => val.split(',').map((k) => k.trim()) as Hex[]),
})

const env = ConfigSchema.parse(process.env)

const deployments = DeploymentFileSchema.parse(deploymentsData)

const program = new Command()

const publicClient = createPublicClient({
  chain: base,
  transport: http(getRpcUrl('base')),
})

async function getRegistryAddress() {
  const chainId = await publicClient.getChainId()
  const entry = Object.values(deployments).find((d) => d.chainId === chainId)
  if (!entry) {
    throw new Error(`No registry found for chainId ${chainId} in deployments.json`)
  }
  return entry.oracleRegistry as Address
}

program.name('oracle-cli').description('CLI to update RWA Oracle prices').version('0.1.0')

program
  .command('update')
  .description('Update price for a given ticker')
  .argument('<ticker>', 'Ticker to update (e.g. CRDYX)')
  .action(async (ticker) => {
    try {
      console.log(`Fetching data for ${ticker}...`)
      const data = await fetchOracleData(ticker)

      // Convert NAV to 8 decimal bigint
      // nav is like 8.7423
      const price = BigInt(Math.round(data.nav * 10 ** 8))
      const timestamp = BigInt(data.timestamp)

      console.log(
        `Ticker: ${data.ticker}, NAV: ${data.nav}, Price (8 dec): ${price}, TS: ${timestamp}`,
      )

      const registryAddress = await getRegistryAddress()
      // Get oracle address from registry
      const oracleAddress = await publicClient.readContract({
        address: registryAddress,
        abi: ORACLE_REGISTRY_ABI,
        functionName: 'getOracleByTicker',
        args: [ticker],
      })

      if (oracleAddress === '0x0000000000000000000000000000000000000000') {
        throw new Error(`No oracle found for ticker ${ticker}`)
      }

      console.log(`Oracle Address: ${oracleAddress}`)

      // Get current nonce
      const nonce = await publicClient.readContract({
        address: oracleAddress,
        abi: RWA_ORACLE_ABI,
        functionName: 'nonce',
      })

      const chainId = await publicClient.getChainId()

      console.log(`Signing data with nonce ${nonce}...`)
      const signatures = await signPriceData(
        price,
        timestamp,
        nonce,
        oracleAddress,
        chainId,
        env.PRIVATE_KEYS,
      )

      console.log(`Submitting update transaction...`)
      const account = privateKeyToAccount(env.PRIVATE_KEYS[0])
      const walletClient = createWalletClient({
        account,
        chain: base,
        transport: http(getRpcUrl('base')),
      })

      const { request } = await publicClient.simulateContract({
        account,
        address: oracleAddress,
        abi: RWA_ORACLE_ABI,
        functionName: 'updatePrice',
        args: [price, timestamp, signatures],
      })

      const hash = await walletClient.writeContract(request)
      console.log(`Transaction submitted: ${hash}`)
    } catch (error) {
      console.error('Error:', error)
    }
  })

program
  .command('registry-set')
  .description('Set oracle address for a ticker')
  .argument('<ticker>', 'Ticker')
  .argument('<asset>', 'Asset address')
  .argument('<oracle>', 'Oracle address')
  .action(async (ticker, asset, oracle) => {
    try {
      const account = privateKeyToAccount(env.PRIVATE_KEYS[0])
      const walletClient = createWalletClient({
        account,
        chain: base,
        transport: http(getRpcUrl('base')),
      })

      const registryAddress = await getRegistryAddress()
      const { request } = await publicClient.simulateContract({
        account,
        address: registryAddress,
        abi: ORACLE_REGISTRY_ABI,
        functionName: 'setOracle',
        args: [ticker, asset as Address, oracle as Address],
      })

      const hash = await walletClient.writeContract(request)
      console.log(`Registry updated: ${hash}`)
    } catch (error) {
      console.error('Error:', error)
    }
  })

program
  .command('add-signer')
  .description('Add a signer to an oracle')
  .argument('<oracle>', 'Oracle address')
  .argument('<signer>', 'Signer address')
  .action(async (oracle, signer) => {
    try {
      const account = privateKeyToAccount(env.PRIVATE_KEYS[0])
      const walletClient = createWalletClient({
        account,
        chain: base,
        transport: http(getRpcUrl('base')),
      })

      const { request } = await publicClient.simulateContract({
        account,
        address: oracle as Address,
        abi: [
          {
            inputs: [{ internalType: 'address', name: 'signer', type: 'address' }],
            name: 'addSigner',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ],
        functionName: 'addSigner',
        args: [signer as Address],
      })

      const hash = await walletClient.writeContract(request)
      console.log(`Signer added: ${hash}`)
    } catch (error) {
      console.error('Error:', error)
    }
  })

program
  .command('set-threshold')
  .description('Set threshold for an oracle')
  .argument('<oracle>', 'Oracle address')
  .argument('<threshold>', 'New threshold')
  .action(async (oracle, threshold) => {
    try {
      const account = privateKeyToAccount(env.PRIVATE_KEYS[0])
      const walletClient = createWalletClient({
        account,
        chain: base,
        transport: http(getRpcUrl('base')),
      })

      const { request } = await publicClient.simulateContract({
        account,
        address: oracle as Address,
        abi: [
          {
            inputs: [{ internalType: 'uint256', name: 'threshold', type: 'uint256' }],
            name: 'setThreshold',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ],
        functionName: 'setThreshold',
        args: [BigInt(threshold)],
      })

      const hash = await walletClient.writeContract(request)
      console.log(`Threshold updated: ${hash}`)
    } catch (error) {
      console.error('Error:', error)
    }
  })

program
  .command('start')
  .description('Run oracle node daemon')
  .argument('<ticker>', 'Ticker to monitor')
  .option('-h, --heartbeat <seconds>', 'Heartbeat threshold in seconds', '86400')
  .option('-d, --deviation <percent>', 'Deviation threshold percentage (e.g. 1 for 1%)', '1')
  .option('-i, --interval <seconds>', 'Polling interval in seconds', '60')
  .action(async (ticker, options) => {
    console.log(`Starting Oracle Node for ${ticker}`)
    console.log(
      `Config: Heartbeat=${options.heartbeat}s, Deviation=${options.deviation}%, Poll=${options.interval}s`,
    )

    const runLoop = async () => {
      try {
        // 1. Fetch Off-Chain Data
        const offChainData = await fetchOracleData(ticker)
        const newPrice = BigInt(Math.round(offChainData.nav * 10 ** 8))
        const newTimestamp = BigInt(offChainData.timestamp)

        // 2. Fetch On-Chain Data
        const registryAddress = await getRegistryAddress()
        const oracleAddress = await publicClient.readContract({
          address: registryAddress,
          abi: ORACLE_REGISTRY_ABI,
          functionName: 'getOracleByTicker',
          args: [ticker],
        })

        if (oracleAddress === '0x0000000000000000000000000000000000000000') {
          console.error(`No oracle found for ${ticker}`)
          return
        }

        const currentData = await publicClient.readContract({
          address: oracleAddress,
          abi: RWA_ORACLE_ABI,
          functionName: 'latestRoundData',
        })

        const lastPrice = currentData[1]
        const lastTimestamp = currentData[2]

        // 3. Evaluate Triggers
        const timeDiff = BigInt(Math.floor(Date.now() / 1000)) - lastTimestamp

        const priceDiff = newPrice > lastPrice ? newPrice - lastPrice : lastPrice - newPrice
        const deviationBp = (priceDiff * 10000n) / lastPrice // Basis points
        const thresholdBp = BigInt(Number(options.deviation) * 100)

        const isHeartbeat = timeDiff >= BigInt(options.heartbeat)
        const isDeviation = deviationBp >= thresholdBp

        console.log(
          `[${new Date().toISOString()}] OnChain: $${Number(lastPrice) / 1e8} (${timeDiff}s ago) | ` +
            `OffChain: $${Number(newPrice) / 1e8} | ` +
            `Diff: ${Number(deviationBp) / 100}%`,
        )

        if (isHeartbeat || isDeviation) {
          console.log(`>>> Triggering Update: Heartbeat=${isHeartbeat}, Deviation=${isDeviation}`)

          // Execute Update
          const nonce = await publicClient.readContract({
            address: oracleAddress,
            abi: RWA_ORACLE_ABI,
            functionName: 'nonce',
          })

          const chainId = await publicClient.getChainId()

          const signatures = await signPriceData(
            newPrice,
            newTimestamp,
            nonce,
            oracleAddress,
            chainId,
            env.PRIVATE_KEYS,
          )

          const account = privateKeyToAccount(env.PRIVATE_KEYS[0])
          const walletClient = createWalletClient({
            account,
            chain: base,
            transport: http(getRpcUrl('base')),
          })

          const { request } = await publicClient.simulateContract({
            account,
            address: oracleAddress,
            abi: RWA_ORACLE_ABI,
            functionName: 'updatePrice',
            args: [newPrice, newTimestamp, signatures],
          })

          const hash = await walletClient.writeContract(request)
          console.log(`>>> Update Sent: ${hash}`)
        } else {
          console.log(`... Skipping update (No trigger condition met)`)
        }
      } catch (error) {
        console.error('Error in poll loop:', error)
      }
    }

    // Run immediately then loop
    await runLoop()
    setInterval(runLoop, Number(options.interval) * 1000)
  })

program.parse()
