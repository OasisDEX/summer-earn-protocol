'use client'

import { useState } from 'react'
import { useAccount, useChainId, useReadContract, useSwitchChain, useWriteContract } from 'wagmi'

import { HUB_CHAIN_ID, HUB_TOKEN_ADDRESS } from '@/config/chains'
import { Delegate } from '@/types/governance'

interface DelegatesListProps {
  initialDelegates: Delegate[]
}

export function DelegatesList({ initialDelegates }: DelegatesListProps) {
  const [searchTerm, setSearchTerm] = useState('')
  const [visibleCount, setVisibleCount] = useState(6)
  const { address, isConnected } = useAccount()
  const currentChainId = useChainId()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync, isPending } = useWriteContract()

  const { data: currentDelegate } = useReadContract({
    address: HUB_TOKEN_ADDRESS,
    abi: [
      {
        type: 'function',
        name: 'delegates',
        inputs: [{ name: 'account', type: 'address' }],
        outputs: [{ name: '', type: 'address' }],
        stateMutability: 'view',
      },
    ] as const,
    functionName: 'delegates',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  })

  const handleDelegate = async (delegatee: string) => {
    if (!isConnected) {
      ;(window as any).appKit?.open?.()
      return
    }

    if (currentChainId.toString() !== HUB_CHAIN_ID) {
      try {
        await switchChainAsync({ chainId: parseInt(HUB_CHAIN_ID) })
      } catch (error) {
        console.error('Failed to switch chain', error)
        return
      }
    }

    try {
      await writeContractAsync({
        address: HUB_TOKEN_ADDRESS,
        abi: [
          {
            type: 'function',
            name: 'delegate',
            inputs: [{ name: 'delegatee', type: 'address' }],
            outputs: [],
            stateMutability: 'nonpayable',
          },
        ] as const,
        functionName: 'delegate',
        args: [delegatee as `0x${string}`],
      })
      alert('Delegation transaction submitted!')
    } catch (error) {
      console.error('Delegation failed', error)
      alert('Delegation failed. Please try again.')
    }
  }

  const sortedDelegates = [...initialDelegates].sort((a, b) => {
    const aIsCurrent = currentDelegate?.toString().toLowerCase() === a.address.toLowerCase()
    const bIsCurrent = currentDelegate?.toString().toLowerCase() === b.address.toLowerCase()
    if (aIsCurrent) return -1
    if (bIsCurrent) return 1
    return 0
  })

  const filteredDelegates = sortedDelegates.filter(
    (d) =>
      d.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      d.address.toLowerCase().includes(searchTerm.toLowerCase()),
  )

  const visibleDelegates = filteredDelegates.slice(0, visibleCount)
  const hasMore = visibleCount < filteredDelegates.length

  const maxVotingPower = Math.max(
    ...initialDelegates.map((d) => parseFloat(d.votingPower.replace(/,/g, '')) || 0),
    1,
  )

  const topPower = initialDelegates[0]?.votingPower || '—'
  const topDelegator = initialDelegates[0]?.name || '—'

  return (
    <div className="space-y-6 max-w-[1240px] mx-auto w-full">
      <div className="flex items-end justify-between gap-4 flex-wrap">
        <div>
          <h1 className="m-0 text-[26px] font-semibold tracking-[-0.03em] text-fg">Delegates</h1>
          <p className="mt-1 text-fg2 text-xs">
            Voting power is stSUMR. Delegate to keep your weight active without unstaking.
          </p>
        </div>

        <div className="flex items-center gap-2 h-[36px] px-3 border border-line rounded-lg bg-field min-w-[240px]">
          <span className="text-fg3 text-xs">⌕</span>
          <input
            type="text"
            placeholder="Search delegates"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="flex-1 min-w-0 border-0 bg-transparent text-xs text-fg focus:outline-none"
          />
        </div>
      </div>

      {/* KPI Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-px bg-line border border-line rounded-xl overflow-hidden">
        <div className="bg-console-surface p-3.5">
          <div className="text-[11px] font-semibold tracking-wider uppercase text-fg3">
            Active Delegates
          </div>
          <div className="font-mono text-xl font-medium tracking-tight text-fg mt-1">
            {initialDelegates.length}
          </div>
        </div>

        <div className="bg-console-surface p-3.5">
          <div className="text-[11px] font-semibold tracking-wider uppercase text-fg3">
            Largest Voting Power
          </div>
          <div className="font-mono text-xl font-medium tracking-tight text-fg mt-1">
            {topPower}
          </div>
        </div>

        <div className="bg-console-surface p-3.5">
          <div className="text-[11px] font-semibold tracking-wider uppercase text-fg3">
            Top Delegate
          </div>
          <div className="font-mono text-xl font-medium tracking-tight text-fg mt-1">
            {topDelegator}
          </div>
        </div>
      </div>

      {/* Delegates Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        {visibleDelegates.map((delegate, rankIndex) => {
          const isCurrentDelegate =
            currentDelegate?.toString().toLowerCase() === delegate.address.toLowerCase()
          const numericPower = parseFloat(delegate.votingPower.replace(/,/g, '')) || 0
          const sharePercent = Math.min((numericPower / maxVotingPower) * 100, 100)

          return (
            <article
              key={delegate.address}
              className="flex flex-col border border-line rounded-xl bg-console-surface p-4"
            >
              <div className="flex items-start gap-3">
                <div className="w-8 h-8 rounded-full overflow-hidden flex items-center justify-center bg-surface3 flex-shrink-0 font-mono text-xs font-semibold text-fg">
                  {delegate.picture ? (
                    <img src={delegate.picture} alt={delegate.name} className="w-full h-full object-cover" />
                  ) : (
                    delegate.name.slice(0, 2)
                  )}
                </div>

                <div className="min-w-0 flex-1">
                  <div className="text-sm font-semibold text-fg truncate flex items-center gap-2">
                    <span>{delegate.name}</span>
                    {isCurrentDelegate && (
                      <span className="px-1.5 py-0.2 rounded bg-ok-bg text-ok text-[10px]">
                        Current
                      </span>
                    )}
                  </div>
                  <div className="font-mono text-[11px] text-fg3 truncate mt-0.5">
                    {delegate.address}
                  </div>
                </div>

                <span className="font-mono text-[11px] text-fg3">#{rankIndex + 1}</span>
              </div>

              <p className="my-3 text-xs text-fg2 line-clamp-3 min-h-[54px]">
                {delegate.bio || 'No bio description provided.'}
              </p>

              <div className="flex gap-4.5 pt-3 border-t border-line mt-auto">
                <div>
                  <div className="text-[10px] font-semibold tracking-wider uppercase text-fg3">
                    Voting power
                  </div>
                  <div className="font-mono text-sm font-medium text-fg mt-0.5 whitespace-nowrap">
                    {delegate.votingPower}
                  </div>
                </div>
                <div>
                  <div className="text-[10px] font-semibold tracking-wider uppercase text-fg3">
                    Delegators
                  </div>
                  <div className="font-mono text-sm font-medium text-fg mt-0.5">
                    {delegate.proposalsVoted}
                  </div>
                </div>
              </div>

              <div className="h-1 rounded-full bg-surface3 overflow-hidden mt-3">
                <div
                  className="h-full rounded-full bg-brand-gradient"
                  style={{ width: `${sharePercent}%` }}
                />
              </div>

              <button
                onClick={() => handleDelegate(delegate.address)}
                disabled={isPending || isCurrentDelegate}
                className="mt-3.5 h-[34px] rounded-full border border-line2 bg-surface3 text-fg text-xs font-semibold hover:bg-surface2 transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isPending ? 'Delegating...' : isCurrentDelegate ? 'Current Delegate' : 'Delegate votes'}
              </button>
            </article>
          )
        })}
      </div>

      {hasMore && (
        <div className="flex justify-center mt-4">
          <button
            onClick={() => setVisibleCount((prev) => prev + 6)}
            className="h-[36px] px-5 rounded-full border border-line2 bg-surface3 text-fg2 text-xs font-medium cursor-pointer hover:text-fg hover:bg-surface2 transition-colors"
          >
            Show all {filteredDelegates.length} delegates
          </button>
        </div>
      )}

      {filteredDelegates.length === 0 && (
        <div className="border border-line rounded-xl bg-console-surface p-6 text-center text-fg2 text-xs">
          No delegates found matching search.
        </div>
      )}
    </div>
  )
}
