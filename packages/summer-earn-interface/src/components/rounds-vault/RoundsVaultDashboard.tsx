'use client'

import { useMemo, useState } from 'react'

import { RoundsVaultInputABI } from '@/abis/RoundsVaultInput'
import { RoundsVaultOutputABI } from '@/abis/RoundsVaultOutput'
import { AddressDisplay, EmptyState, selectBase } from '@/components/ui'
import arbitrumConfig from '@/config/deployment/deployed/arbitrum.json'
import baseConfig from '@/config/deployment/deployed/base.json'
import hyperliquidConfig from '@/config/deployment/deployed/hyperliquid.json'
import mainnetConfig from '@/config/deployment/deployed/mainnet.json'
import sepoliaConfig from '@/config/deployment/deployed/sepolia.json'
import sonicConfig from '@/config/deployment/deployed/sonic.json'
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
  '11155111': sepoliaConfig,
}

const chainIdToName: Record<string, string> = {
  '1': 'mainnet',
  '8453': 'base',
  '42161': 'arbitrum',
  '146': 'sonic',
  '999': 'hyperliquid',
  '11155111': 'sepolia',
}

interface VaultPair {
  id: string
  name: string
  inputAddress: `0x${string}`
  outputAddress: `0x${string}`
  accessManagerAddress?: `0x${string}`
}

export function RoundsVaultDashboard({ chainId }: RoundsVaultDashboardProps) {
  const config = configs[chainId]
  const chainName = chainIdToName[chainId]

  // ── Discover vault pairs from deployment config ──
  const vaultPairs = useMemo(() => {
    if (!config || !chainName) return []

    const pairs: VaultPair[] = []
    const keys = Object.keys(config)
    const inputRegex = /^(.*?)_RoundsVaultInput_(.*)#RoundsVaultInput$/

    keys.forEach((key) => {
      const match = key.match(inputRegex)
      if (match) {
        const prefix = match[1] // e.g., "ExtDemoCorp_3" or "staging"
        const identifier = match[2] // e.g., "extDemo_USDC_base"

        const outputKey = `${prefix}_RoundsVaultOutput_${identifier}#RoundsVaultOutput`
        if (config[outputKey]) {
          const possibleInstitution = identifier.split('_')[0]
          const pamKey = keys.find(
            (k) =>
              (k.includes('ProtocolAccessManagerV2') || k.includes('ProtocolAccessManager')) &&
              (k.includes(prefix) || k.includes(possibleInstitution)),
          )

          pairs.push({
            id: identifier,
            name: identifier.replace(/_/g, ' '),
            inputAddress: config[key] as `0x${string}`,
            outputAddress: config[outputKey] as `0x${string}`,
            accessManagerAddress: pamKey ? (config[pamKey] as `0x${string}`) : undefined,
          })
        }
      }
    })

    return pairs
  }, [config, chainName])

  const [selectedPairId, setSelectedPairId] = useState<string | null>(
    vaultPairs.length > 0 ? vaultPairs[0].id : null,
  )

  const selectedPair = useMemo(
    () => vaultPairs.find((p) => p.id === selectedPairId) || vaultPairs[0],
    [vaultPairs, selectedPairId],
  )

  if (vaultPairs.length === 0) {
    return (
      <EmptyState
        title="No Rounds Vault pairs found"
        description={`No Rounds Vault pairs found on this chain (${chainId}).`}
      />
    )
  }

  return (
    <div className="space-y-8">
      {vaultPairs.length > 1 && (
        <div className="flex flex-col sm:flex-row items-center gap-4 bg-surface-container-high/40 p-4 rounded-xl border border-white/5">
          <label className="text-on-surface-variant text-sm font-medium">Select Vault Pair:</label>
          <select
            value={selectedPairId || ''}
            onChange={(e) => setSelectedPairId(e.target.value)}
            className={`${selectBase} w-full max-w-xs`}
          >
            {vaultPairs.map((pair) => (
              <option key={pair.id} value={pair.id}>
                {pair.name}
              </option>
            ))}
          </select>
        </div>
      )}

      {selectedPair && (
        <div className="flex flex-col lg:flex-row gap-4 text-sm">
          <div className="flex-1 bg-surface-container-high/40 p-4 rounded-xl border border-white/5 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <div className="font-medium text-on-surface-variant mb-1">Input Vault Address</div>
              <code className="text-info bg-info/10 border border-info/20 px-2 py-1 rounded select-all">
                <AddressDisplay value={selectedPair.inputAddress} full />
              </code>
            </div>
          </div>
          <div className="flex-1 bg-surface-container-high/40 p-4 rounded-xl border border-white/5 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <div className="font-medium text-on-surface-variant mb-1">Output Vault Address</div>
              <code className="text-info bg-info/10 border border-info/20 px-2 py-1 rounded select-all">
                <AddressDisplay value={selectedPair.outputAddress} full />
              </code>
            </div>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Input Vault: deposit underlying (USDC) → receipts → exchange for Fleet shares */}
        <VaultInteractionForm
          title="Input Vault (Deposit)"
          description="Deposit your tokens to receive shares automatically at the end of the round."
          vaultAddress={selectedPair.inputAddress}
          vaultAbi={RoundsVaultInputABI}
          accessManagerAddress={selectedPair.accessManagerAddress}
          showFleetURL={true}
        />

        {/* Output Vault: deposit Fleet shares → receipts → exchange for underlying (USDC) */}
        <VaultInteractionForm
          title="Output Vault (Withdraw)"
          description="Deposit your Fleet shares to receive the underlying asset at the end of the round."
          vaultAddress={selectedPair.outputAddress}
          vaultAbi={RoundsVaultOutputABI}
          accessManagerAddress={selectedPair.accessManagerAddress}
        />
      </div>
    </div>
  )
}
