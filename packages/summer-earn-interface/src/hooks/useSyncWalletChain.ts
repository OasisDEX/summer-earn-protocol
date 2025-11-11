'use client'

import { useEffect } from 'react'
import { useAccount, useChainId, useSwitchChain } from 'wagmi'

import type { ChainId } from '@/types'

/**
 * Keeps the connected wallet network in sync with the selected app chain.
 * If a user is connected and selects a different chain, it triggers a wallet network switch.
 */
export function useSyncWalletChain(selectedChainId: ChainId | undefined) {
  const currentWalletChainId = useChainId()
  const { isConnected } = useAccount()
  const { switchChain } = useSwitchChain()

  useEffect(() => {
    if (!isConnected) return
    if (!selectedChainId) return

    const desired = Number(selectedChainId)
    if (!Number.isFinite(desired)) return

    if (currentWalletChainId !== desired) {
      try {
        switchChain({ chainId: desired })
      } catch (err) {
        // Non-fatal: user can decline; UI should still function for read-only

        console.warn('Failed to switch chain:', err)
      }
    }
  }, [isConnected, selectedChainId, currentWalletChainId, switchChain])
}
