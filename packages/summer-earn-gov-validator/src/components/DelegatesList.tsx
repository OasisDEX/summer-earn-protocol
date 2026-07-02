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
  const { address, isConnected } = useAccount()
  const currentChainId = useChainId()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync, isPending } = useWriteContract()

  // Fetch current delegate
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

  const truncateAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`
  }

  return (
    <div className="flex flex-col min-h-screen">
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 mb-12">
        <div className="space-y-2">
          <h1 className="text-4xl md:text-5xl font-extrabold tracking-tighter text-on-surface">
            Community Delegates
          </h1>
          <p className="text-on-surface-variant max-w-xl text-lg">
            Choose a representative to vote on your behalf or join the ranks to lead the Lazy Summer
            DAO ecosystem.
          </p>
        </div>
      </div>

      {/* Search */}
      <div className="mb-8">
        <div className="relative max-w-md">
          <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400">
            search
          </span>
          <input
            type="text"
            placeholder="Search by name or address..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full bg-surface-container border border-outline-variant/30 rounded-lg pl-10 pr-4 py-3 text-on-surface focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all outline-none"
          />
        </div>
      </div>

      {/* Delegates Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredDelegates.map((delegate) => {
          const isCurrentDelegate =
            currentDelegate?.toString().toLowerCase() === delegate.address.toLowerCase()

          return (
            <div
              key={delegate.address}
              className={`glass-card hover:glass-card-elevated hover:scale-[1.02] p-6 rounded-2xl group border transition-all duration-300 shadow-lg hover:shadow-primary/5 flex flex-col justify-between ${
                isCurrentDelegate
                  ? 'border-emerald-400/30 bg-emerald-400/5'
                  : 'border-sky-400/10 hover:border-primary/40'
              }`}
            >
              <div>
                <div className="flex items-start justify-between mb-6">
                  <div className="flex items-center gap-4">
                    <div className="w-14 h-14 rounded-full overflow-hidden bg-gradient-to-br from-primary to-tertiary p-[2px] shadow-lg shadow-primary/10">
                      <div className="w-full h-full rounded-full bg-surface-container flex items-center justify-center overflow-hidden">
                        {delegate.picture ? (
                          <img
                            src={delegate.picture}
                            alt={delegate.name}
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <span className="material-symbols-outlined text-slate-400 text-2xl">
                            person
                          </span>
                        )}
                      </div>
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <h3 className="font-bold text-on-surface text-lg leading-tight">
                          {delegate.name}
                        </h3>
                        {isCurrentDelegate && (
                          <span className="px-1.5 py-0.5 rounded-md bg-emerald-500/10 border border-emerald-400/20 text-[10px] font-bold text-emerald-400 tracking-wider uppercase">
                            Current
                          </span>
                        )}
                      </div>
                      <div className="flex items-center gap-2">
                        <p className="text-xs text-on-surface-variant font-mono opacity-60">
                          {truncateAddress(delegate.address)}
                        </p>
                        {delegate.twitter && (
                          <a
                            href={`https://twitter.com/${delegate.twitter}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-primary hover:text-surface-tint transition-colors"
                          >
                            <svg className="w-3 h-3 fill-current" viewBox="0 0 24 24">
                              <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                            </svg>
                          </a>
                        )}
                      </div>
                    </div>
                  </div>
                </div>

                {delegate.bio && (
                  <p className="text-sm text-on-surface-variant line-clamp-3 mb-6 min-h-[4.5rem] italic opacity-80 leading-relaxed">
                    &quot;{delegate.bio}&quot;
                  </p>
                )}
              </div>

              <div className="grid grid-cols-2 gap-4 mb-6">
                <div className="p-3 bg-surface-container-low rounded-xl border border-outline/10">
                  <p className="text-[10px] uppercase tracking-wider text-on-surface-variant mb-1">
                    Voting Power
                  </p>
                  <p className="text-lg font-bold text-on-surface">{delegate.votingPower}</p>
                </div>
                <div className="p-3 bg-surface-container-low rounded-xl border border-outline/10">
                  <p className="text-[10px] uppercase tracking-wider text-on-surface-variant mb-1">
                    Delegators
                  </p>
                  <p className="text-lg font-bold text-on-surface">{delegate.proposalsVoted}</p>
                </div>
                {delegate.curia && (
                  <>
                    <div className="p-3 bg-primary/5 rounded-xl border border-primary/20">
                      <p className="text-[10px] uppercase tracking-wider text-on-surface-variant mb-1 flex items-center gap-1">
                        PRS Score
                        <span
                          className="material-symbols-outlined text-[12px] opacity-50 cursor-help"
                          title="Curia forum Post Reputation Score, aggregated over the last year"
                        >
                          info
                        </span>
                      </p>
                      <p className="text-lg font-bold text-primary">
                        {delegate.curia.prsScore !== null
                          ? delegate.curia.prsScore.toLocaleString(undefined, {
                              maximumFractionDigits: 1,
                            })
                          : '—'}
                      </p>
                    </div>
                    <div className="p-3 bg-surface-container-low rounded-xl border border-outline/10">
                      <p className="text-[10px] uppercase tracking-wider text-on-surface-variant mb-1">
                        Votes Cast
                      </p>
                      <p className="text-lg font-bold text-on-surface">
                        {delegate.curia.votesCast}
                        {delegate.curia.proposalsCount > 0 && (
                          <span className="text-xs font-medium text-on-surface-variant">
                            {' '}
                            / {delegate.curia.proposalsCount}
                          </span>
                        )}
                      </p>
                    </div>
                  </>
                )}
              </div>
              {delegate.curia && (
                <p className="text-[10px] text-on-surface-variant opacity-60 -mt-4 mb-6 text-right">
                  Analytics by{' '}
                  <a
                    href="https://curiahub.xyz"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="hover:text-primary underline decoration-dotted"
                  >
                    Curia
                  </a>
                </p>
              )}

              <button
                onClick={() => handleDelegate(delegate.address)}
                disabled={isPending || isCurrentDelegate}
                className="w-full mt-6 py-3 border border-primary/20 bg-primary/5 hover:bg-primary text-primary hover:text-on-primary font-semibold rounded-xl transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
              >
                {isPending && (
                  <span className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
                )}
                {isPending
                  ? 'Delegating...'
                  : isCurrentDelegate
                    ? 'Current Delegate'
                    : 'Delegate Votes'}
              </button>
            </div>
          )
        })}
      </div>

      {filteredDelegates.length === 0 && (
        <div className="text-center py-12">
          <span className="material-symbols-outlined text-6xl text-slate-600 mb-4">search_off</span>
          <p className="text-on-surface-variant">No delegates found</p>
        </div>
      )}
    </div>
  )
}
