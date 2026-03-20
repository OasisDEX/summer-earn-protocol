'use client'

import { useMemo, useState } from 'react'

import { RoundsVaultInputABI } from '@/abis/RoundsVaultInput'
import { RoundsVaultOutputABI } from '@/abis/RoundsVaultOutput'
import arbitrumConfig from '@/config/deployment/deployed/arbitrum.json'
import baseConfig from '@/config/deployment/deployed/base.json'
import hyperliquidConfig from '@/config/deployment/deployed/hyperliquid.json'
import mainnetConfig from '@/config/deployment/deployed/mainnet.json'
import sonicConfig from '@/config/deployment/deployed/sonic.json'
import deploymentIndex from '@/config/deployment/index.json'
import type { ChainId } from '@/types'

import { VaultInteractionForm } from './VaultInteractionForm'

interface RoundsVaultDashboardProps {
  chainId: ChainId
}

const configs: Record<string, any> = {
  '8453': baseConfig,
  '42161': arbitrumConfig,
  '1': mainnetConfig,
  '146': sonicConfig,
  '999': hyperliquidConfig,
}

const chainIdToName: Record<string, string> = {
  '1': 'mainnet',
  '8453': 'base',
  '42161': 'arbitrum',
  '146': 'sonic',
  '999': 'hyperliquid',
}

interface VaultPair {
  id: string
  name: string
  inputAddress: `0x${string}`
  outputAddress: `0x${string}`
  tokenSymbol: string
  tokenAddress: `0x${string}`
}

export function RoundsVaultDashboard({ chainId }: RoundsVaultDashboardProps) {
  const config = configs[chainId]
  const chainName = chainIdToName[chainId]

  const vaultPairs = useMemo(() => {
    if (!config || !chainName) return []

    const pairs: VaultPair[] = []
    const keys = Object.keys(config)

    // Find all RoundsVaultInput contracts
    const inputRegex = /^staging_RoundsVaultInput_(.*)#RoundsVaultInput$/
    
    keys.forEach((key) => {
      const match = key.match(inputRegex)

      if (match) {
        const identifier = match[1]
        const outputKey = `staging_RoundsVaultOutput_${identifier}#RoundsVaultOutput`
        
        if (config[outputKey]) {
          // Extract token symbol from identifier (e.g., extDemo_USDC_mainnet -> USDC)
          // We can try to match against known tokens in the index
          const tokens = (deploymentIndex as any)[chainName]?.tokens || {}
          const tokenSymbol = identifier.split('_').find(part => 
            tokens[part.toLowerCase()]
          ) || 'USDC'
          
          const tokenAddress = tokens[tokenSymbol.toLowerCase()] as `0x${string}`

          pairs.push({
            id: identifier,
            name: identifier.replace(/_/g, ' '),
            inputAddress: config[key] as `0x${string}`,
            outputAddress: config[outputKey] as `0x${string}`,
            tokenSymbol: tokenSymbol.toUpperCase(),
            tokenAddress,
          })
        }
      }
    })

    return pairs
  }, [config, chainName])

  const [selectedPairId, setSelectedPairId] = useState<string | null>(
    vaultPairs.length > 0 ? vaultPairs[0].id : null
  )

  const selectedPair = useMemo(
    () => vaultPairs.find((p) => p.id === selectedPairId) || vaultPairs[0],
    [vaultPairs, selectedPairId]
  )

  if (vaultPairs.length === 0) {
    return (
      <div className="bg-charcoal-800/60 p-6 rounded-2xl border border-white/5 backdrop-blur-xl">
        <p className="text-white text-center">
          No Rounds Vault pairs found on this chain ({chainId}).
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-8">
      {vaultPairs.length > 1 && (
        <div className="flex flex-col sm:flex-row items-center gap-4 bg-gray-900/40 p-4 rounded-xl border border-white/5">
          <label className="text-gray-400 text-sm font-medium">Select Vault Pair:</label>
          <select
            value={selectedPairId || ''}
            onChange={(e) => setSelectedPairId(e.target.value)}
            className="bg-gray-800 border border-white/10 rounded-lg px-4 py-2 text-white focus:outline-none focus:ring-2 focus:ring-blue-500/50 transition-all min-w-[200px]"
          >
            {vaultPairs.map((pair) => (
              <option key={pair.id} value={pair.id}>
                {pair.name}
              </option>
            ))}
          </select>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Input Vault Module */}
        <VaultInteractionForm
          title="Input Vault"
          description={`Deposit your ${selectedPair.tokenSymbol} to receive shares automatically at the end of the round.`}
          vaultAddress={selectedPair.inputAddress}
          vaultAbi={RoundsVaultInputABI}
          depositAsset={selectedPair.tokenAddress}
          underlyingAsset={selectedPair.tokenAddress}
          // The form component handles exchangeAsset internally
          sharesAsset="0x0" // Placeholder as it's not used in body
          receiveAsset="0x0" // Placeholder
          decimals={selectedPair.tokenSymbol === 'USDC' || selectedPair.tokenSymbol === 'USDT' || selectedPair.tokenSymbol === 'EURC' ? 6 : 18}
          symbol={selectedPair.tokenSymbol}
          receiptSymbol="rInput"
        />

        {/* Output Vault Module */}
        <VaultInteractionForm
          title="Output Vault"
          description={`Exchange your shares to receive ${selectedPair.tokenSymbol} automatically at the end of the round.`}
          vaultAddress={selectedPair.outputAddress}
          vaultAbi={RoundsVaultOutputABI}
          depositAsset={selectedPair.tokenAddress} // This will be the shares asset in reality, but UI expects depositAsset label
          underlyingAsset={selectedPair.tokenAddress}
          sharesAsset={selectedPair.tokenAddress}
          receiveAsset={selectedPair.tokenAddress}
          decimals={selectedPair.tokenSymbol === 'USDC' || selectedPair.tokenSymbol === 'USDT' || selectedPair.tokenSymbol === 'EURC' ? 6 : 18}
          symbol={`${selectedPair.tokenSymbol} Shares`}
          receiptSymbol="rOutput"
        />
      </div>
    </div>
  )
}
