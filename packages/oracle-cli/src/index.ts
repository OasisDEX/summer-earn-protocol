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
import { deployYieldSystem } from './deploy-yield'
import { RWA_ORACLE_ABI, ORACLE_REGISTRY_ABI } from './constants'
import { DeploymentFileSchema } from './schemas'
import deploymentsData from './deployments.json'
import { encodeFunctionData } from 'viem'
import { WisdomTreeConnect } from './fetchers/wisdomtree-connect'
import { fetchNAV } from './fetchers/wisdomtree-dataspan'

const MULTICALL3_ADDRESS = '0xcA11bde05977b3631167028862bE2a173976CA11' as Address
const MULTICALL3_ABI = [
  {
    inputs: [
      {
        components: [
          { name: 'target', type: 'address' },
          { name: 'allowFailure', type: 'bool' },
          { name: 'callData', type: 'bytes' },
        ],
        name: 'calls',
        type: 'tuple[]',
      },
    ],
    name: 'aggregate3',
    outputs: [
      {
        components: [
          { name: 'success', type: 'bool' },
          { name: 'returnData', type: 'bytes' },
        ],
        name: 'returnData',
        type: 'tuple[]',
      },
    ],
    stateMutability: 'payable',
    type: 'function',
  },
] as const

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
  .argument('[ticker]', 'Ticker to monitor (omit to monitor all from deployments.json)')
  .option('-h, --heartbeat <seconds>', 'Heartbeat threshold in seconds', '86400')
  .option('-d, --deviation <percent>', 'Deviation threshold percentage (e.g. 1 for 1%)', '1')
  .option('-i, --interval <seconds>', 'Polling interval in seconds', '60')
  .action(async (tickerArg, options) => {
    const chainId = await publicClient.getChainId()
    const deploymentEntry = Object.values(deployments).find((d) => d.chainId === chainId)
    const activeOracles = deploymentEntry?.oracles ?? []

    const tickersToMonitor = tickerArg ? [tickerArg] : activeOracles.map((o) => o.ticker)

    if (tickersToMonitor.length === 0) {
      console.error('No oracles found to monitor.')
      return
    }

    console.log(`Starting Oracle Node for: ${tickersToMonitor.join(', ')}`)
    console.log(
      `Config: Heartbeat=${options.heartbeat}s, Deviation=${options.deviation}%, Poll=${options.interval}s`,
    )

    const processTicker = async (ticker: string) => {
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
          console.error(`[${ticker}] No oracle found in registry`)
          return null
        }

        const currentData = await publicClient.readContract({
          address: oracleAddress,
          abi: RWA_ORACLE_ABI,
          functionName: 'latestRoundData',
        })

        const lastPrice = currentData[1]
        const lastTimestamp = currentData[2]

        // 3. Evaluate Triggers
        const now = BigInt(Math.floor(Date.now() / 1000))
        const timeDiff = now - lastTimestamp

        const priceDiff = newPrice > lastPrice ? newPrice - lastPrice : lastPrice - newPrice
        const deviationBp = lastPrice > 0n ? (priceDiff * 10000n) / lastPrice : 10000n // 100% if lastPrice is 0
        const thresholdBp = BigInt(Number(options.deviation) * 100)

        const isHeartbeat = timeDiff >= BigInt(options.heartbeat)
        const isDeviation = deviationBp >= thresholdBp

        console.log(
          `[${ticker}] [${new Date().toISOString()}] OnChain: $${Number(lastPrice) / 1e8} (${timeDiff}s ago) | ` +
            `OffChain: $${Number(newPrice) / 1e8} | ` +
            `Diff: ${Number(deviationBp) / 100}%`,
        )

        if (isHeartbeat || isDeviation) {
          console.log(
            `[${ticker}] >>> Triggering Update: Heartbeat=${isHeartbeat}, Deviation=${isDeviation}`,
          )

          const nonce = await publicClient.readContract({
            address: oracleAddress,
            abi: RWA_ORACLE_ABI,
            functionName: 'nonce',
          })

          const signatures = await signPriceData(
            newPrice,
            newTimestamp,
            nonce,
            oracleAddress,
            chainId,
            env.PRIVATE_KEYS,
          )

          // Return instead of sending immediately
          return {
            ticker,
            oracleAddress,
            newPrice,
            newTimestamp,
            signatures,
          }
        }
        return null
      } catch (error) {
        console.error(`[${ticker}] Error in process loop:`, error)
        return null
      }
    }

    let isProcessing = false

    const runLoop = async () => {
      if (isProcessing) return
      isProcessing = true

      try {
        const results = await Promise.allSettled(tickersToMonitor.map(processTicker))

        const updatesToExecute = results
          .filter(
            (r): r is PromiseFulfilledResult<any> => r.status === 'fulfilled' && r.value !== null,
          )
          .map((r) => r.value)

        if (updatesToExecute.length > 0) {
          console.log(`\n>>> Batching ${updatesToExecute.length} updates via Multicall3...`)

          const calls = updatesToExecute.map((u) => ({
            target: u.oracleAddress,
            allowFailure: true,
            callData: encodeFunctionData({
              abi: RWA_ORACLE_ABI,
              functionName: 'updatePrice',
              args: [u.newPrice, u.newTimestamp, u.signatures],
            }),
          }))

          const account = privateKeyToAccount(env.PRIVATE_KEYS[0])
          const walletClient = createWalletClient({
            account,
            chain: base,
            transport: http(getRpcUrl('base')),
          })

          const { request } = await publicClient.simulateContract({
            account,
            address: MULTICALL3_ADDRESS,
            abi: MULTICALL3_ABI,
            functionName: 'aggregate3',
            args: [calls],
          })

          const hash = await walletClient.writeContract(request)
          console.log(`>>> Batch Multicall Transaction Submitted: ${hash}`)

          await publicClient.waitForTransactionReceipt({ hash })
          console.log(`>>> Batch Transaction Confirmed!`)
        }
      } catch (err) {
        console.error('Error in runLoop multicall batch:', err)
      } finally {
        isProcessing = false
      }
    }

    // Run immediately then loop
    await runLoop()
    setInterval(runLoop, Number(options.interval) * 1000)
  })

program
  .command('deploy-yield-system')
  .description('Deploy Test Yield System based on deployed oracles')
  .option('-f, --factory <address>', 'Force specific factory address')
  .action(async (options) => {
    try {
      await deployYieldSystem(options.factory as Address)
    } catch (e) {
      console.error(e)
    }
  })

const wt = new WisdomTreeConnect()

program
  .command('wt-accruals')
  .description('Fetch WisdomTree open accruals')
  .argument('[guid]', 'Optional organization GUID')
  .action(async (guid) => {
    try {
      console.log('Fetching WisdomTree accruals...')
      const accruals = await wt.getAccruals(guid)
      console.table(
        accruals.map((a) => ({
          ticker: a.ticker,
          blockchain: a.blockchain,
          wallet_address: a.wallet_address,
          pending_value: a.pending_value,
          pending_since: a.pending_since,
        })),
      )
    } catch (error) {
      console.error('Error fetching accruals:', error)
    }
  })

program
  .command('wt-orders')
  .description('Fetch all WisdomTree orders')
  .action(async () => {
    try {
      console.log('Fetching WisdomTree orders...')
      const orders = await wt.getAllOrders()
      console.table(
        orders.map((o) => ({
          trade_type: o.trade_type,
          user: o.user,
          org: o.org,
          status: o.status,
          expected_settlement_date: o.expected_settlement_date,
          exchange_code: o.exchange_code,
          order_reference: o.order_reference,
          order_date: o.order_date,
        })),
      )
    } catch (error) {
      console.error('Error fetching orders:', error)
    }
  })

program
  .command('wt-order')
  .description('Fetch details for a single WisdomTree order')
  .argument('<order_reference>', 'Order reference')
  .action(async (orderReference) => {
    try {
      console.log(`Fetching detail for order ${orderReference}...`)
      const o = await wt.getOrder(orderReference)
      const details = {
        order_reference: o.order_reference,
        order_date: o.order_date,
        exchange_code: o.exchange_code,
        quantity: o.quantity,
        expected_settlement_date: o.expected_settlement_date,
        trade_type: o.trade_type,
        settlement_currency: o.settlement_currency,
        token_contract_address: o.token_contract_address,
        blockchain: o.blockchain,
        settlement_wallet_address: o.settlement_wallet_address,
        wisdomtree_deposit_wallet_address: o.wisdomtree_deposit_wallet_address,
        gross_value: o.gross_value,
        net_value: o.net_value,
        transaction_fee: o.transaction_fee,
        network_fee: o.network_fee,
        rate: o.rate,
        user: o.user,
        org: o.org,
        status: o.status,
      }
      console.log(JSON.stringify(details, null, 2))
    } catch (error) {
      console.error('Error fetching order detail:', error)
    }
  })

program
  .command('wt-me')
  .description('Fetch WisdomTree current organization details')
  .action(async () => {
    try {
      const me = await wt.getMe()
      console.log(JSON.stringify(me, null, 2))
    } catch (error) {
      console.error('Error fetching organization details:', error)
    }
  })

program
  .command('wt-wallets')
  .description('Fetch On-Receipt wallets for all or a specific deployed oracle')
  .argument('[ticker]', 'Optional ticker to fetch only one')
  .action(async (tickerArg) => {
    try {
      console.log(
        tickerArg
          ? `Fetching On-Receipt wallet for ${tickerArg}...`
          : 'Fetching On-Receipt wallets for all deployed oracles...',
      )
      const walletPromises: Promise<any>[] = []

      for (const [network, data] of Object.entries(deployments)) {
        if (!data.oracles) continue
        const blockchain = network === 'base' ? 'Base Mainnet' : network

        for (const oracle of data.oracles) {
          if (tickerArg && oracle.ticker.toLowerCase() !== tickerArg.toLowerCase()) continue

          let ticker = oracle.ticker
          if (ticker === 'CRDT') ticker = 'CRDYX'
          if (ticker === 'EPXC') ticker = 'WTPIX'

          walletPromises.push(
            (async () => {
              try {
                const startTime = Date.now()
                // console.log(`fetching wallet for ${ticker}...`)
                const wallet = await wt.getOnReceiptWallet({
                  blockchain,
                  currency: 'USDC',
                  fund: ticker,
                  trade_type: 'Purchase',
                })
                // console.log(`finished ${ticker} in ${Date.now() - startTime}ms`)
                return {
                  network,
                  ticker: oracle.ticker,
                  mappedFund: ticker,
                  wallet: wallet.wallet_address,
                  latency: `${Date.now() - startTime}ms`,
                }
              } catch (e) {
                return {
                  network,
                  ticker: oracle.ticker,
                  mappedFund: ticker,
                  wallet: 'Error/Not Found',
                }
              }
            })(),
          )
        }
      }

      const results = await Promise.all(walletPromises)

      if (results.length === 0 && tickerArg) {
        console.error(`Ticker "${tickerArg}" not found in deployments.json.`)
        const available = Object.values(deployments).flatMap(
          (d: any) => d.oracles?.map((o: any) => o.ticker) || [],
        )
        console.log('Available tickers:', [...new Set(available)].join(', '))
        return
      }

      console.table(results)
    } catch (error) {
      console.error('Error fetching wallets:', error)
    }
  })

program
  .command('wt-tickers')
  .description('List all documented tickers and their off-chain mappings')
  .action(async () => {
    const tickers: any[] = []
    for (const [network, data] of Object.entries(deployments)) {
      if (!data.oracles) continue
      for (const oracle of data.oracles) {
        let mapped = oracle.ticker
        if (mapped === 'CRDT') mapped = 'CRDYX'
        if (mapped === 'EPXC') mapped = 'WTPIX'
        tickers.push({
          network,
          ticker: oracle.ticker,
          offchainTicker: mapped,
          type: oracle.type,
          subtype: oracle.subtype,
        })
      }
    }
    console.table(tickers)
  })

program
  .command('wt-data')
  .description('Fetch fund NAV data from DataSpan API')
  .argument('<ticker>', 'Fund ticker')
  .argument('[date]', 'Optional date (YYYY-MM-DD)')
  .action(async (ticker, date) => {
    try {
      console.log(`Fetching NAV data for ${ticker}${date ? ` on ${date}` : ''}...`)
      const data = await fetchNAV(ticker, date)
      console.log(JSON.stringify(data, null, 2))
    } catch (error) {
      console.error('Error fetching NAV data:', error)
    }
  })

program
  .command('wt-data-range')
  .description('Fetch fund NAV data over a date range and display a chart')
  .argument('<ticker>', 'Fund ticker')
  .argument('<startDate>', 'Start date (YYYY-MM-DD)')
  .argument('<endDate>', 'End date (YYYY-MM-DD)')
  .action(async (ticker, startDate, endDate) => {
    try {
      console.log(`Fetching NAV data for ${ticker} from ${startDate} to ${endDate}...`)

      const start = new Date(startDate)
      const end = new Date(endDate)
      const dates: string[] = []

      let current = new Date(start)
      while (current <= end) {
        dates.push(current.toISOString().split('T')[0])
        current.setDate(current.getDate() + 1)
      }

      console.log(`Downloading/Loading ${dates.length} days of data...`)

      const navData: any[] = []
      for (const d of dates) {
        try {
          const data = await fetchNAV(ticker, d)
          // Only add if the date matches (avoid duplicates from 'latest' fallback)
          if (data.dt === d) {
            navData.push(data)
          }
        } catch (e) {
          // Missing dates are fine
        }
      }

      if (navData.length === 0) {
        console.log('No data found for the specified range.')
        return
      }

      console.log(`Successfully retrieved ${navData.length} data points.`)

      // Beautiful ASCII Chart
      const values = navData.map((d) => d.nav)
      const min = Math.min(...values)
      const max = Math.max(...values)
      const range = max - min || 1
      const height = 10
      const width = navData.length

      console.log('\n--- NAV Trend Chart ---')
      for (let h = height; h >= 0; h--) {
        let line = ''
        const threshold = min + (range * h) / height
        for (const v of values) {
          if (v >= threshold) {
            line += '█'
          } else {
            line += ' '
          }
        }
        console.log(`${threshold.toFixed(4)} | ${line}`)
      }
      console.log(''.padEnd(width + 10, '-'))
      console.log(`       | ${navData[0].dt} ... ${navData[navData.length - 1].dt}\n`)

      console.table(navData.map((d) => ({ date: d.dt, nav: d.nav })))
    } catch (error) {
      console.error('Error fetching NAV range:', error)
    }
  })

program.parse()
