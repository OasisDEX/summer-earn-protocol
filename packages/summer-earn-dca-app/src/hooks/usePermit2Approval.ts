'use client'

import { useEffect, useMemo, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { Address } from 'viem'
import { useAccount, useChainId, usePublicClient, useWalletClient } from 'wagmi'

import { erc20Abi } from '@/abis/ERC20'
import { permit2Abi } from '@/abis/Permit2'
import { DCA_STRATEGY_MANAGER_ADDRESSES, PERMIT2_ADDRESS } from '@/config/addresses'
import { VIEM_CHAIN_ENTITIES } from '@/config/chains'
import { useTxToast } from '@/hooks/useTxToast'
import { MAX_UINT160, MAX_UINT256 } from '@/lib/format'
import { isPermit2AllowanceSufficient, readPermit2Allowance } from '@/lib/permit2/allowance'
import { buildPermitSingleTypedData } from '@/lib/permit2/typedData'
import type { ChainId } from '@/types/chain'

export type Permit2Step = 'idle' | 'needs-erc20' | 'needs-permit2' | 'ready'

interface UsePermit2ApprovalArgs {
  chainId: ChainId
  /** The token Permit2 will pull from — for DCA this is the FleetCommander source-vault share token. */
  sourceVault?: Address
  requiredShares?: bigint
}

// 30-day Permit2 expiration on direct approve; matches the default Uniswap UI uses.
const PERMIT2_EXPIRATION_SECONDS = 30 * 24 * 60 * 60

export function usePermit2Approval({
  chainId,
  sourceVault,
  requiredShares,
}: UsePermit2ApprovalArgs) {
  const queryClient = useQueryClient()
  const { address: owner } = useAccount()
  const walletChainId = useChainId()
  const publicClient = usePublicClient({ chainId: Number(chainId) })
  const { data: walletClient } = useWalletClient({ chainId: Number(chainId) })
  const spender = DCA_STRATEGY_MANAGER_ADDRESSES[chainId]

  const enabled = Boolean(owner && sourceVault && publicClient && requiredShares !== undefined)

  const erc20AllowanceQuery = useQuery({
    queryKey: ['dca', 'erc20-allowance', chainId, owner, sourceVault],
    enabled,
    refetchInterval: 15_000,
    queryFn: async () => {
      if (!publicClient || !owner || !sourceVault) throw new Error('not ready')
      return publicClient.readContract({
        address: sourceVault,
        abi: erc20Abi,
        functionName: 'allowance',
        args: [owner, PERMIT2_ADDRESS],
      })
    },
  })

  const permit2AllowanceQuery = useQuery({
    queryKey: ['dca', 'permit2-allowance', chainId, owner, sourceVault, spender],
    enabled,
    refetchInterval: 15_000,
    queryFn: async () => {
      if (!publicClient || !owner || !sourceVault) throw new Error('not ready')
      return readPermit2Allowance(publicClient, owner, sourceVault, spender)
    },
  })

  const step: Permit2Step = useMemo(() => {
    if (!enabled || requiredShares === undefined) return 'idle'
    if (erc20AllowanceQuery.data === undefined || permit2AllowanceQuery.data === undefined)
      return 'idle'
    if (erc20AllowanceQuery.data < requiredShares) return 'needs-erc20'
    if (!isPermit2AllowanceSufficient(permit2AllowanceQuery.data, requiredShares))
      return 'needs-permit2'
    return 'ready'
  }, [enabled, erc20AllowanceQuery.data, permit2AllowanceQuery.data, requiredShares])

  const approveErc20Tx = useTxToast({
    chainId,
    labels: {
      pending: 'Approving Permit2 to spend vault shares…',
      success: 'Permit2 approval confirmed',
      error: 'Permit2 approval failed',
    },
    onSuccess: () => erc20AllowanceQuery.refetch(),
  })

  const approvePermit2DirectTx = useTxToast({
    chainId,
    labels: {
      pending: 'Approving DCA manager via Permit2…',
      success: 'Permit2 allowance set',
      error: 'Permit2 allowance failed',
    },
    onSuccess: () => permit2AllowanceQuery.refetch(),
  })

  const approvePermit2SigTx = useTxToast({
    chainId,
    labels: {
      pending: 'Submitting Permit2 signature…',
      success: 'Permit2 allowance set (via signature)',
      error: 'Permit2 signature submission failed',
    },
    onSuccess: () => permit2AllowanceQuery.refetch(),
  })

  const [isSigning, setIsSigning] = useState(false)

  async function approveErc20() {
    if (!owner || !sourceVault) return
    approveErc20Tx.beginToast()
    try {
      await approveErc20Tx.writeContractAsync({
        address: sourceVault,
        abi: erc20Abi,
        functionName: 'approve',
        args: [PERMIT2_ADDRESS, MAX_UINT256],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: owner,
      })
    } catch (e) {
      approveErc20Tx.endToastOnError(e)
    }
  }

  async function approvePermit2Direct() {
    if (!owner || !sourceVault) return
    const expiration = Math.floor(Date.now() / 1000) + PERMIT2_EXPIRATION_SECONDS
    approvePermit2DirectTx.beginToast()
    try {
      await approvePermit2DirectTx.writeContractAsync({
        address: PERMIT2_ADDRESS,
        abi: permit2Abi,
        functionName: 'approve',
        args: [sourceVault, spender, MAX_UINT160, expiration],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: owner,
      })
    } catch (e) {
      approvePermit2DirectTx.endToastOnError(e)
    }
  }

  async function approvePermit2Sig() {
    if (!owner || !sourceVault || !walletClient || !publicClient) return
    if (!permit2AllowanceQuery.data) return
    setIsSigning(true)
    approvePermit2SigTx.beginToast()
    try {
      const expiration = Math.floor(Date.now() / 1000) + PERMIT2_EXPIRATION_SECONDS
      const sigDeadline = BigInt(expiration)
      const typedData = buildPermitSingleTypedData({
        chainId: Number(chainId),
        permitSingle: {
          details: {
            token: sourceVault,
            amount: MAX_UINT160,
            expiration,
            nonce: permit2AllowanceQuery.data.nonce,
          },
          spender,
          sigDeadline,
        },
      })
      const signature = await walletClient.signTypedData({
        account: owner,
        domain: typedData.domain,
        types: typedData.types,
        primaryType: typedData.primaryType,
        message: typedData.message,
      })
      await approvePermit2SigTx.writeContractAsync({
        address: PERMIT2_ADDRESS,
        abi: permit2Abi,
        functionName: 'permit',
        args: [
          owner,
          {
            details: {
              token: sourceVault,
              amount: MAX_UINT160,
              expiration,
              nonce: permit2AllowanceQuery.data.nonce,
            },
            spender,
            sigDeadline,
          },
          signature,
        ],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: owner,
      })
    } catch (e) {
      approvePermit2SigTx.endToastOnError(e)
    } finally {
      setIsSigning(false)
    }
  }

  // Refetch on tx success — the useTxToast callbacks already trigger this,
  // but a belt-and-braces invalidation here makes the UI snap to ready faster.
  useEffect(() => {
    if (
      approveErc20Tx.isSuccess ||
      approvePermit2DirectTx.isSuccess ||
      approvePermit2SigTx.isSuccess
    ) {
      queryClient.invalidateQueries({ queryKey: ['dca', 'erc20-allowance'] })
      queryClient.invalidateQueries({ queryKey: ['dca', 'permit2-allowance'] })
    }
  }, [
    approveErc20Tx.isSuccess,
    approvePermit2DirectTx.isSuccess,
    approvePermit2SigTx.isSuccess,
    queryClient,
  ])

  return {
    step,
    isLoading: erc20AllowanceQuery.isLoading || permit2AllowanceQuery.isLoading,
    isWrongChain: walletChainId !== Number(chainId),
    erc20Allowance: erc20AllowanceQuery.data,
    permit2Allowance: permit2AllowanceQuery.data,
    approveErc20,
    approvePermit2Direct,
    approvePermit2Sig,
    isSigning,
    approveErc20Tx,
    approvePermit2DirectTx,
    approvePermit2SigTx,
  }
}
