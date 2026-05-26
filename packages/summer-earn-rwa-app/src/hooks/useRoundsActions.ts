'use client'

import { useQueryClient } from '@tanstack/react-query'

import { erc1155Abi } from '@/abis/ERC1155'
import { roundsVaultInputAbi } from '@/abis/RoundsVaultInput'
import { useTxToast } from '@/hooks/useTxToast'
import type { ChainId } from '@/types/chain'

interface UseRoundsActionsProps {
  roundsVaultAddress: `0x${string}`
  chainId: ChainId
  owner?: `0x${string}`
}

// Wraps deposit / cancel (redeem current round) / claim (redeemExchangeAsset)
// + ERC-1155 approval. Input + Output vaults share the same surface, so the
// Input ABI is enough for the wagmi function descriptors.
export function useRoundsActions({ roundsVaultAddress, chainId, owner }: UseRoundsActionsProps) {
  const queryClient = useQueryClient()

  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ['rounds', chainId, roundsVaultAddress] })
    queryClient.invalidateQueries({
      queryKey: ['rounds-vault-current', chainId, roundsVaultAddress],
    })
    queryClient.invalidateQueries({ queryKey: ['user-receipts', chainId] })
    queryClient.invalidateQueries({ queryKey: ['fleetInfo', chainId] })
  }

  const deposit = useTxToast({
    chainId,
    labels: {
      pending: 'Depositing into queue…',
      success: 'Deposited — receipt minted',
      error: 'Deposit failed',
    },
    onSuccess: invalidate,
  })

  const redeem = useTxToast({
    chainId,
    labels: {
      pending: 'Cancelling current-round deposit…',
      success: 'Receipt redeemed for deposit asset',
      error: 'Cancel failed',
    },
    onSuccess: invalidate,
  })

  const claim = useTxToast({
    chainId,
    labels: {
      pending: 'Claiming settled exchange asset…',
      success: 'Settled funds claimed',
      error: 'Claim failed',
    },
    onSuccess: invalidate,
  })

  const approveAll = useTxToast({
    chainId,
    labels: {
      pending: 'Approving receipt operator…',
      success: 'Receipt operator approved',
      error: 'Approval failed',
    },
    onSuccess: invalidate,
  })

  return {
    deposit: (assets: bigint, receiver: `0x${string}`) => {
      deposit.beginToast()
      return deposit.writeContractAsync({
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'deposit',
        args: [assets, receiver],
      })
    },
    redeemCurrent: (
      roundId: bigint,
      amount: bigint,
      receiver: `0x${string}`,
      ownerArg?: `0x${string}`,
    ) => {
      redeem.beginToast()
      return redeem.writeContractAsync({
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'redeem',
        args: [roundId, amount, receiver, (ownerArg ?? owner) as `0x${string}`],
      })
    },
    redeemCurrentBatch: (
      ids: bigint[],
      amounts: bigint[],
      receiver: `0x${string}`,
      ownerArg?: `0x${string}`,
    ) => {
      redeem.beginToast()
      return redeem.writeContractAsync({
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'redeemBatch',
        args: [ids, amounts, receiver, (ownerArg ?? owner) as `0x${string}`],
      })
    },
    claimSettled: (
      roundId: bigint,
      amount: bigint,
      receiver: `0x${string}`,
      ownerArg?: `0x${string}`,
    ) => {
      claim.beginToast()
      return claim.writeContractAsync({
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'redeemExchangeAsset',
        args: [roundId, amount, receiver, (ownerArg ?? owner) as `0x${string}`],
      })
    },
    claimSettledBatch: (
      ids: bigint[],
      amounts: bigint[],
      receiver: `0x${string}`,
      ownerArg?: `0x${string}`,
    ) => {
      claim.beginToast()
      return claim.writeContractAsync({
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'redeemExchangeAssetBatch',
        args: [ids, amounts, receiver, (ownerArg ?? owner) as `0x${string}`],
      })
    },
    setApprovalForAll: (operator: `0x${string}`, approved: boolean) => {
      approveAll.beginToast()
      return approveAll.writeContractAsync({
        address: roundsVaultAddress,
        abi: erc1155Abi,
        functionName: 'setApprovalForAll',
        args: [operator, approved],
      })
    },
    pending: {
      deposit: deposit.isWriting || deposit.isMining,
      redeem: redeem.isWriting || redeem.isMining,
      claim: claim.isWriting || claim.isMining,
      approveAll: approveAll.isWriting || approveAll.isMining,
    },
  }
}
