'use client'

import React from 'react'
import baseConfig from '@/config/deployment/deployed/base.json'
import arbitrumConfig from '@/config/deployment/deployed/arbitrum.json'
import mainnetConfig from '@/config/deployment/deployed/mainnet.json'
import sonicConfig from '@/config/deployment/deployed/sonic.json'
import hyperliquidConfig from '@/config/deployment/deployed/hyperliquid.json'

import { RoundsVaultInputABI } from '@/abis/RoundsVaultInput'
import { RoundsVaultOutputABI } from '@/abis/RoundsVaultOutput'
import { VaultInteractionForm } from './VaultInteractionForm'
import type { ChainId } from '@/types'

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

export function RoundsVaultDashboard({ chainId }: RoundsVaultDashboardProps) {
  const config = configs[chainId] || baseConfig

  // Addresses configuration mapped from deployment files
  const ROUNDS_VAULT_INPUT = config['staging_RoundsVaultInput_WisdomTree_USDC_Base#RoundsVaultInput'] as `0x${string}`
  const ROUNDS_VAULT_OUTPUT = config['staging_RoundsVaultOutput_WisdomTree_USDC_Base#RoundsVaultOutput'] as `0x${string}`
  // USDC Base mock / standard address. 
  // TODO: Make this dynamic based on the vault's asset() call or from config
  const USDC_ADDRESS = '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913' 
  const WT_ARK_ADDRESS = config['staging_WisdomTreeArk_WisdomTree_USDC_Base#WisdomTreeArk'] as `0x${string}`

  if (!ROUNDS_VAULT_INPUT || !ROUNDS_VAULT_OUTPUT) {
    return (
      <div className="bg-charcoal-800/60 p-6 rounded-2xl border border-white/5 backdrop-blur-xl">
        <p className="text-white text-center">Rounds Vault not deployed on this chain ({chainId}).</p>
      </div>
    )
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
      {/* Input Vault Module */}
      <VaultInteractionForm
        title="Input Vault"
        description="Deposit your USDC to receive WisdomTree Shares automatically at the end of the round."
        vaultAddress={ROUNDS_VAULT_INPUT}
        vaultAbi={RoundsVaultInputABI}
        depositAsset={USDC_ADDRESS}
        receiveAsset={WT_ARK_ADDRESS}
        underlyingAsset={USDC_ADDRESS}
        sharesAsset={WT_ARK_ADDRESS}
        decimals={6}
        symbol="USDC"
        receiptSymbol="rInput"
      />

      {/* Output Vault Module */}
      <VaultInteractionForm
        title="Output Vault"
        description="Deposit your WisdomTree Shares to receive USDC automatically at the end of the round."
        vaultAddress={ROUNDS_VAULT_OUTPUT}
        vaultAbi={RoundsVaultOutputABI}
        depositAsset={WT_ARK_ADDRESS}
        receiveAsset={USDC_ADDRESS}
        underlyingAsset={WT_ARK_ADDRESS}
        sharesAsset={USDC_ADDRESS}
        decimals={6}
        symbol="WT-Shares"
        receiptSymbol="rOutput"
      />
    </div>
  )
}
