import { Command } from 'commander'
import {
  createWalletClient,
  createPublicClient,
  http,
  type Address,
  type Hex,
  parseUnits,
  ContractFunctionRevertedError,
  BaseError,
  AbiErrorSignatureNotFoundError,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { base } from 'viem/chains'
import { getRpcUrl, getChain, type DeployNetwork } from './config'
import 'dotenv/config'

import { z } from 'zod'
import { execSync } from 'child_process'
import { fetchOracleData } from './fetcher'
import { signPriceData } from './signer'
import { deployYieldSystem } from './deploy-yield'
import { RWA_ORACLE_ABI, ORACLE_REGISTRY_ABI } from './constants'
import { DeploymentFileSchema } from './schemas'
import deploymentsData from './deployments.json'
import { encodeFunctionData } from 'viem'
import { WisdomTreeConnect } from './fetchers/wisdomtree-connect'
import { fetchNAV, fetchBlockchainAddresses } from './fetchers/wisdomtree-dataspan'
import fs from 'fs'
import path from 'path'

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

function getNetworkClients(network: DeployNetwork) {
  const chain = getChain(network)
  const rpcUrl = getRpcUrl(network)

  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  })

  const account = privateKeyToAccount(env.PRIVATE_KEYS[0])
  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(rpcUrl),
  })

  return { publicClient, walletClient, account, chainId: chain.id }
}

async function getRegistryAddress(publicClient: any) {
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
  .option('-n, --network <network>', 'Network to update on', 'base')
  .action(async (ticker, options) => {
    try {
      const network = options.network as DeployNetwork
      console.log(`Fetching data for ${ticker} on ${network}...`)
      const { publicClient, walletClient, account, chainId } = getNetworkClients(network)

      const data = await fetchOracleData(ticker)

      // Convert NAV to 8 decimal bigint
      const price = BigInt(Math.round(data.nav * 10 ** 8))
      const timestamp = BigInt(data.timestamp)

      console.log(
        `Ticker: ${data.ticker}, NAV: ${data.nav}, Price (8 dec): ${price}, TS: ${timestamp}`,
      )

      const registryAddress = await getRegistryAddress(publicClient)
      // Get oracle address from registry
      const oracleAddress = await publicClient.readContract({
        address: registryAddress,
        abi: ORACLE_REGISTRY_ABI,
        functionName: 'getOracleByTicker',
        args: [ticker],
      })

      if (oracleAddress === '0x0000000000000000000000000000000000000000') {
        throw new Error(`No oracle found for ticker ${ticker} on ${network}`)
      }

      console.log(`Oracle Address: ${oracleAddress} (ChainId: ${chainId})`)

      // Get current nonce
      const nonce = await publicClient.readContract({
        address: oracleAddress,
        abi: RWA_ORACLE_ABI,
        functionName: 'nonce',
      })

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
  .option('-n, --network <network>', 'Network', 'base')
  .action(async (ticker, asset, oracle, options) => {
    try {
      const network = options.network as DeployNetwork
      const { publicClient, walletClient, account } = getNetworkClients(network)

      const registryAddress = await getRegistryAddress(publicClient)
      const { request } = await publicClient.simulateContract({
        account,
        address: registryAddress,
        abi: ORACLE_REGISTRY_ABI,
        functionName: 'setOracle',
        args: [ticker, asset as Address, oracle as Address],
      })

      const hash = await walletClient.writeContract(request)
      console.log(`Registry updated on ${network}: ${hash}`)
    } catch (error) {
      console.error('Error:', error)
    }
  })

program
  .command('add-signer')
  .description('Add a signer to an oracle')
  .argument('<oracle>', 'Oracle address')
  .argument('<signer>', 'Signer address')
  .option('-n, --network <network>', 'Network', 'base')
  .action(async (oracle, signer, options) => {
    try {
      const network = options.network as DeployNetwork
      const { publicClient, walletClient, account } = getNetworkClients(network)

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
      console.log(`Signer added on ${network}: ${hash}`)
    } catch (error) {
      console.error('Error:', error)
    }
  })

program
  .command('set-threshold')
  .description('Set threshold for an oracle')
  .argument('<oracle>', 'Oracle address')
  .argument('<threshold>', 'New threshold')
  .option('-n, --network <network>', 'Network', 'base')
  .action(async (oracle, threshold, options) => {
    try {
      const network = options.network as DeployNetwork
      const { publicClient, walletClient, account } = getNetworkClients(network)

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
      console.log(`Threshold updated on ${network}: ${hash}`)
    } catch (error) {
      console.error('Error:', error)
    }
  })

program
  .command('start')
  .description('Run oracle node daemon')
  .argument('[ticker]', 'Ticker to monitor (omit to monitor all from deployments.json)')
  .option('-n, --network <network>', 'Specific network to monitor')
  .option('-d, --deviation <percent>', 'Deviation threshold percentage (e.g. 1 for 1%)', '0.01')
  .option('-i, --interval <seconds>', 'Polling interval in seconds', '60')
  .action(async (tickerArg, options) => {
    const networkArg = options.network as DeployNetwork | undefined

    console.log(`Starting Oracle Node...`)
    console.log(`Config: Deviation=${options.deviation}%, Poll=${options.interval}s`)

    const processTickerOnNetwork = async (
      ticker: string,
      network: DeployNetwork,
      publicClient: any,
    ) => {
      try {
        // 1. Fetch Off-Chain Data
        const offChainData = await fetchOracleData(ticker)
        const newPrice = BigInt(Math.round(offChainData.nav * 10 ** 8))
        const newTimestamp = BigInt(offChainData.timestamp)

        // 2. Fetch On-Chain Data
        const registryAddress = await getRegistryAddress(publicClient)
        const oracleAddress = await publicClient.readContract({
          address: registryAddress,
          abi: ORACLE_REGISTRY_ABI,
          functionName: 'getOracleByTicker',
          args: [ticker],
        })

        if (oracleAddress === '0x0000000000000000000000000000000000000000') {
          console.error(`[${network}:${ticker}] No oracle found in registry`)
          return null
        }

        let lastPrice = 0n
        let lastTimestamp = 0n

        try {
          const currentData = await publicClient.readContract({
            address: oracleAddress,
            abi: RWA_ORACLE_ABI,
            functionName: 'latestRoundData',
          })

          lastPrice = currentData[1]
          lastTimestamp = currentData[2]
        } catch (error: any) {
          const isNoData =
            // 0xbb258700 is the signature for NoData
            error.signature === '0xbb258700' ||
            error.data === '0xbb258700' ||
            (error.cause &&
              (error.cause.signature === '0xbb258700' || error.cause.data === '0xbb258700'))

          if (isNoData) {
            console.log(`[${network}:${ticker}] No data available yet - first update`)
          } else if (error instanceof BaseError) {
            console.error(
              `[${network}:${ticker}] Error fetching on-chain data:`,
              error.shortMessage || error.message,
            )
            return null
          } else {
            console.error(`[${network}:${ticker}] Unknown error fetching on-chain data:`, error)
            return null
          }
        }

        // 3. Evaluate Triggers
        const now = BigInt(Math.floor(Date.now() / 1000))
        const timeDiff = now - lastTimestamp

        const priceDiff = newPrice > lastPrice ? newPrice - lastPrice : lastPrice - newPrice
        const deviationBp = lastPrice > 0n ? (priceDiff * 10000n) / lastPrice : 10000n
        const thresholdBp = BigInt(Number(options.deviation) * 100)

        const isDeviation = deviationBp >= thresholdBp

        console.log(
          `[${network}:${ticker}] [${new Date().toISOString()}] OnChain: $${Number(lastPrice) / 1e8} (${timeDiff}s ago) | ` +
            `OffChain: $${Number(newPrice) / 1e8} | ` +
            `Diff: ${Number(deviationBp) / 100}%`,
        )

        if (isDeviation) {
          console.log(`[${network}:${ticker}] >>> Triggering Update due to price deviation`)

          const nonce = await publicClient.readContract({
            address: oracleAddress,
            abi: RWA_ORACLE_ABI,
            functionName: 'nonce',
          })

          const { chainId } = getNetworkClients(network)

          const signatures = await signPriceData(
            newPrice,
            newTimestamp,
            nonce,
            oracleAddress,
            chainId,
            env.PRIVATE_KEYS,
          )

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
        console.error(`[${network}:${ticker}] Error in process loop:`, error)
        return null
      }
    }

    let isProcessing = false

    const runLoop = async () => {
      if (isProcessing) return
      isProcessing = true

      try {
        const networksToProcess = networkArg
          ? [networkArg]
          : (Object.keys(deployments) as DeployNetwork[])

        for (const network of networksToProcess) {
          const deployEntry = deployments[network]
          if (!deployEntry || !deployEntry.oracles || deployEntry.oracles.length === 0) continue

          const { publicClient, walletClient, account } = getNetworkClients(network)
          const tickersToMonitor = tickerArg
            ? deployEntry.oracles.some((o) => o.ticker === tickerArg)
              ? [tickerArg]
              : []
            : deployEntry.oracles.map((o) => o.ticker)

          if (tickersToMonitor.length === 0) continue

          const results = await Promise.allSettled(
            tickersToMonitor.map((t) => processTickerOnNetwork(t, network, publicClient)),
          )

          const updatesToExecute = results
            .filter(
              (r): r is PromiseFulfilledResult<any> => r.status === 'fulfilled' && r.value !== null,
            )
            .map((r) => r.value)

          if (updatesToExecute.length > 0) {
            console.log(
              `\n>>> [${network}] Batching ${updatesToExecute.length} updates via Multicall3...`,
            )

            const calls = updatesToExecute.map((u) => ({
              target: u.oracleAddress,
              allowFailure: true,
              callData: encodeFunctionData({
                abi: RWA_ORACLE_ABI,
                functionName: 'updatePrice',
                args: [u.newPrice, u.newTimestamp, u.signatures],
              }),
            }))

            const { request } = await publicClient.simulateContract({
              account,
              address: MULTICALL3_ADDRESS,
              abi: MULTICALL3_ABI,
              functionName: 'aggregate3',
              args: [calls],
            })

            const hash = await walletClient.writeContract(request)
            console.log(`>>> [${network}] Batch Multicall Transaction Submitted: ${hash}`)

            await publicClient.waitForTransactionReceipt({ hash })
            console.log(`>>> [${network}] Batch Transaction Confirmed!`)
          }
        }
      } catch (err) {
        console.error('Error in runLoop multichain:', err)
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

      for (const [networkKey, data] of Object.entries(deployments)) {
        const network = networkKey as DeployNetwork
        if (!data.oracles) continue
        const blockchainMap: Record<string, string> = {
          base: 'Base Mainnet',
          arbitrum: 'Arbitrum Mainnet',
          mainnet: 'Ethereum Mainnet',
          ethereum: 'Ethereum Mainnet',
        }
        const blockchain = blockchainMap[network] || network

        for (const oracle of data.oracles) {
          if (tickerArg && oracle.ticker.toLowerCase() !== tickerArg.toLowerCase()) continue

          let ticker = oracle.ticker
          if (ticker === 'CRDT') ticker = 'CRDYX'
          if (ticker === 'EPXC') ticker = 'WTPIX'

          walletPromises.push(
            (async () => {
              try {
                const startTime = Date.now()
                const wallet = await wt.getOnReceiptWallet({
                  blockchain,
                  currency: 'USDC',
                  fund: ticker,
                  trade_type: 'Purchase',
                })
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

      console.log(`Downloading/Loading ${dates.length} days of data (in chunks of 10)...`)

      const navData: any[] = []
      const CHUNK_SIZE = 10
      for (let i = 0; i < dates.length; i += CHUNK_SIZE) {
        const chunk = dates.slice(i, i + CHUNK_SIZE)
        const chunkResults = await Promise.all(
          chunk.map(async (d) => {
            try {
              const data = await fetchNAV(ticker, d)
              return data.dt === d ? data : null
            } catch (e) {
              return null
            }
          }),
        )
        navData.push(...chunkResults.filter((d): d is any => d !== null))
      }

      if (navData.length === 0) {
        console.log('No data found for the specified range.')
        return
      }

      console.log(`Successfully retrieved ${navData.length} data points.`)

      // Beautiful High-Res Line ASCII Chart
      const values = navData.map((d) => d.nav)
      const min = Math.min(...values)
      const max = Math.max(...values)
      const range = max - min || 1
      const height = 12
      const pointSpacing = 3
      const width = navData.length * pointSpacing

      const grid: string[][] = Array.from({ length: height + 1 }, () => Array(width).fill(' '))

      for (let i = 0; i < navData.length; i++) {
        const col = i * pointSpacing
        const h = Math.round(((values[i] - min) / range) * height)
        const row = height - h

        let char = '-'
        if (i > 0) {
          if (values[i] > values[i - 1]) char = '/'
          else if (values[i] < values[i - 1]) char = '\\'
          else char = '_'
        }

        // Peaks and Valleys
        if (i > 0 && i < navData.length - 1) {
          if (values[i] > values[i - 1] && values[i] > values[i + 1]) char = '^'
          if (values[i] < values[i - 1] && values[i] < values[i + 1]) char = 'v'
        }

        grid[row][col] = char

        // Simple interpolation between points
        if (i > 0) {
          const prevH = Math.round(((values[i - 1] - min) / range) * height)
          const prevRow = height - prevH
          const midCol = col - 1

          if (row < prevRow) grid[row + 1][midCol] = '/'
          else if (row > prevRow) grid[row - 1][midCol] = '\\'
          else grid[row][midCol] = '_'
        }
      }

      console.log('\n--- NAV Trend Chart ---')
      for (let h = 0; h <= height; h++) {
        const threshold = max - (range * h) / height
        console.log(`${threshold.toFixed(4)} | ${grid[h].join('')}`)
      }
      console.log(''.padEnd(width + 10, '-'))
      console.log(`       | ${navData[0].dt} ... ${navData[navData.length - 1].dt}\n`)

      console.table(navData.map((d) => ({ date: d.dt, nav: d.nav })))
    } catch (error) {
      console.error('Error fetching NAV range:', error)
    }
  })

program
  .command('wt-assets')
  .description('Fetch fund asset addresses from DataSpan API across all blockchains')
  .argument('<ticker>', 'Fund ticker')
  .action(async (ticker) => {
    try {
      console.log(`Fetching blockchain addresses for ${ticker}...`)
      const addresses = await fetchBlockchainAddresses(ticker)
      console.table(
        addresses.map((a) => ({
          blockchain: a.blockchainName,
          symbol: a.tokenSymbol,
          address: a.contractAddress,
        })),
      )
    } catch (error) {
      console.error('Error fetching blockchain addresses:', error)
    }
  })

program
  .command('generate-deploy-input')
  .description('Generate deploy-input.json for a list of tickers across supported blockchains')
  .argument('<tickers...>', 'List of tickers')
  .option('-o, --output <path>', 'Output file path', 'deploy-input.json')
  .action(async (tickers, options) => {
    try {
      const results: any[] = []
      const networksMapping: Record<string, string> = {
        Base: 'base',
        Arbitrum: 'arbitrum',
        Ethereum: 'mainnet',
        Sonic: 'sonic',
        // Add more as supported
      }

      for (let ticker of tickers) {
        if (ticker === 'CRDT') ticker = 'CRDYX'
        if (ticker === 'EPXC') ticker = 'WTPIX'
        console.log(`Processing ticker: ${ticker}...`)
        const addresses = await fetchBlockchainAddresses(ticker)

        for (const addr of addresses) {
          const network = networksMapping[addr.blockchainName]
          if (network) {
            results.push({
              network,
              assetAddress: addr.contractAddress,
              description: `Oracle for ${ticker} on ${addr.blockchainName}`,
              signers: [], // User needs to fill this
              threshold: 1, // Default threshold
              type: 'WisdomTree',
              subtype: 'variableNav',
            })
          }
        }
      }

      const outputPath = path.resolve(process.cwd(), options.output)
      fs.writeFileSync(outputPath, JSON.stringify(results, null, 2))
      console.log(`Generated ${results.length} deployment configs in ${options.output}`)
      console.log('NOTE: You still need to fill in the "signers" array for each config!')
    } catch (error) {
      console.error('Error generating deploy-input:', error)
    }
  })

program
  .command('sync-config')
  .description('Sync deployments.json and WT wallets to packages/deployment/config/index.test.json')
  .action(async () => {
    try {
      console.log('Starting sync-config...')
      const configPath = path.resolve(__dirname, '../../deployment/config/index.test.json')
      console.log(`Target config path: ${configPath}`)
      if (!fs.existsSync(configPath)) {
        console.error(`Config file not found at ${configPath}`)
        return
      }

      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'))
      let updated = false

      for (const [networkKey, data] of Object.entries(deployments)) {
        const network = networkKey as DeployNetwork
        console.log(`Processing network: ${network}...`)
        if (!data.oracles || data.oracles.length === 0) {
          console.log(`No oracles for ${network}, skipping.`)
          continue
        }

        // Ensure network exists in config
        if (!config[network]) {
          console.warn(`Network ${network} not found in index.test.json, skipping...`)
          continue
        }

        if (!config[network].protocolSpecific) config[network].protocolSpecific = {}
        if (!config[network].protocolSpecific.wisdomtree)
          config[network].protocolSpecific.wisdomtree = {}
        if (!config[network].protocolSpecific.wisdomtree.usdc)
          config[network].protocolSpecific.wisdomtree.usdc = {}

        const wtConfig = config[network].protocolSpecific.wisdomtree.usdc
        const blockchainMap: Record<string, string> = {
          base: 'Base Mainnet',
          arbitrum: 'Arbitrum Mainnet',
          mainnet: 'Ethereum',
        }
        if (network !== 'mainnet') {
          continue
        }
        const blockchain = blockchainMap[network] || network

        console.log(`[${network}] Fetching wallets for ${data.oracles.length} oracles...`)

        const walletResults = await Promise.allSettled(
          data.oracles.map(async (oracle) => {
            let ticker = oracle.ticker
            if (ticker === 'CRDT') ticker = 'CRDYX'
            if (ticker === 'EPXC') ticker = 'WTPIX'

            const wallet = await wt.getOnReceiptWallet({
              blockchain,
              currency: 'USDC',
              fund: ticker,
              trade_type: 'Purchase',
            })

            return {
              ticker: oracle.ticker,
              oracleAddress: oracle.oracleAddress,
              assetAddress: oracle.assetAddress,
              walletAddress: wallet.wallet_address,
            }
          }),
        )

        for (const result of walletResults) {
          if (result.status === 'fulfilled') {
            const val = result.value
            wtConfig[val.ticker] = {
              oracle: val.oracleAddress,
              shareToken: val.assetAddress,
              targetWallet: val.walletAddress,
            }
            updated = true
          } else {
            console.error(`[${network}] Failed to fetch a wallet:`, result.reason.message)
          }
        }
      }

      if (updated) {
        fs.writeFileSync(configPath, JSON.stringify(config, null, 2))
        console.log(`\nSuccessfully updated ${configPath}`)
      } else {
        console.log('\nNo updates made to config.')
      }
    } catch (error) {
      console.error('Error syncing config:', error)
    }
  })

program
  .command('verify')
  .description('Verify deployed contracts on Etherscan/Arbiscan/Basescan/Sonicscan')
  .action(async () => {
    try {
      const scriptPath = path.resolve(__dirname, 'scripts/verify-contracts.ts')
      console.log('Starting contract verification...')
      execSync(`pnpx ts-node ${scriptPath}`, { stdio: 'inherit' })
    } catch (error) {
      console.error('Error during verification:', error)
    }
  })

program.parse()
