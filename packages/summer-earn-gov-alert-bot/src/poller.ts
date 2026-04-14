import { PublicClient } from 'viem'
import { SupportedNetworks } from './services/validation'
import { getPublicClient } from './config/rpc'
import { getGovernorAddresses, getTimelockAddress, viemChains } from './config'
import { EventProcessor } from './processor'
import { TelegramNotifier } from './telegram'

export class Poller {
  constructor(
    private notifier: TelegramNotifier,
    private state: Record<string, bigint>,
  ) {}

  async poll(targetChatId?: string | number) {
    for (const network of Object.values(SupportedNetworks) as SupportedNetworks[]) {
      try {
        const chain = viemChains[network]
        const client = getPublicClient(chain.id)

        const latestBlock = await client.getBlockNumber()
        const fromBlock = this.state[network] ? this.state[network] + 1n : latestBlock - 100n // Default to last 100 blocks

        if (fromBlock > latestBlock) {
          console.log(`[${network}] No new blocks.`)
          continue
        }

        console.log(`[${network}] Polling logs from ${fromBlock} to ${latestBlock}...`)

        const processor = new EventProcessor(this.notifier, network, client as any, targetChatId)

        const governorAddresses = getGovernorAddresses(network)
        const timelockAddress = getTimelockAddress(network)

        // Poll Governor Events
        if (governorAddresses.length > 0) {
          const govLogs = await client.getLogs({
            address: governorAddresses,
            fromBlock,
            toBlock: latestBlock,
          })
          await processor.processGovernorLogs(govLogs)
        }

        // Poll Timelock Events
        if (timelockAddress) {
          const timelockLogs = await client.getLogs({
            address: timelockAddress,
            fromBlock,
            toBlock: latestBlock,
          })
          await processor.processTimelockLogs(timelockLogs)
        }

        if (!targetChatId) {
          this.state[network] = latestBlock
        }
      } catch (error) {
        console.error(`Error polling ${network}:`, error)
      }
    }
  }

  async processSingleTransaction(
    network: SupportedNetworks,
    txHash: `0x${string}`,
    targetChatId?: string | number,
  ) {
    try {
      const chain = viemChains[network]
      const client = getPublicClient(chain.id)
      const tx = await client.getTransaction({ hash: txHash })
      const receipt = await client.getTransactionReceipt({ hash: txHash })

      const processor = new EventProcessor(this.notifier, network, client as any, targetChatId)

      console.log(`[${network}] Manually processing transaction ${txHash}...`)

      // Get logs for this specific transaction
      const txLogs = receipt.logs

      // Process all logs against both Governor and Timelock event sets
      // This is more robust for complex transactions (e.g. Safe multisig executing a Timelock)
      await processor.processGovernorLogs(txLogs)
      await processor.processTimelockLogs(txLogs)

      return true
    } catch (error) {
      console.error(`Error processing single tx on ${network}:`, error)
      return false
    }
  }

  getState() {
    return this.state
  }
}
