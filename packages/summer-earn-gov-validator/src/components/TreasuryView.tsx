'use client'

import { useState } from 'react'

import type { TreasuryData, TreasuryHolding } from '@/services/treasury'

interface TreasuryViewProps {
  initialData: TreasuryData
}

function HoldingsTable({ holdings }: { holdings: TreasuryHolding[] }) {
  return (
    <div className="glass rounded-3xl overflow-hidden border-sky-400/5">
      <div className="overflow-x-auto">
        <table className="w-full text-left">
          <thead className="bg-slate-900/50 border-b border-sky-400/10">
            <tr>
              <th className="px-6 py-4 text-xs font-bold uppercase tracking-widest text-on-surface-variant">
                Token
              </th>
              <th className="px-6 py-4 text-xs font-bold uppercase tracking-widest text-on-surface-variant">
                Balance
              </th>
              <th className="px-6 py-4 text-xs font-bold uppercase tracking-widest text-on-surface-variant">
                Value
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-sky-400/5">
            {holdings.map((holding, index) => (
              <tr key={index} className="hover:bg-primary/5 transition-colors">
                <td className="px-6 py-5">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-full overflow-hidden flex items-center justify-center border border-sky-400/10 bg-slate-800">
                      {holding.logoURI ? (
                        <img
                          src={holding.logoURI}
                          alt={holding.symbol}
                          className="w-full h-full object-contain p-1"
                          onError={(e) => {
                            ;(e.target as HTMLImageElement).src =
                              'https://assets.smold.app/api/token/1/0x0000000000000000000000000000000000000000/logo-128.png'
                          }}
                        />
                      ) : (
                        <div className="w-full h-full bg-gradient-to-br from-primary to-tertiary flex items-center justify-center">
                          <span className="material-symbols-outlined text-xs text-on-primary">
                            paid
                          </span>
                        </div>
                      )}
                    </div>
                    <div>
                      <p className="font-bold text-on-surface">{holding.token}</p>
                      <p className="text-xs text-on-surface-variant">
                        {holding.symbol} • {holding.chain}
                      </p>
                    </div>
                  </div>
                </td>
                <td className="px-6 py-5">
                  <p className="font-medium text-on-surface">{holding.balance}</p>
                </td>
                <td className="px-6 py-5">
                  <p className="font-bold text-primary">{holding.value}</p>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export function TreasuryView({ initialData }: TreasuryViewProps) {
  const [selectedChain, setSelectedChain] = useState<string>('all')

  const matchesChain = (holding: TreasuryHolding) =>
    selectedChain === 'all' || holding.chain.toLowerCase() === selectedChain.toLowerCase()

  // Per-wallet sections, each filtered by the selected chain; hide empties.
  const walletSections = initialData.wallets
    .map((section) => ({ ...section, holdings: section.holdings.filter(matchesChain) }))
    .filter((section) => section.holdings.length > 0)

  // Each multisig's share of the whole treasury (unfiltered), so it stays stable
  // as the chain filter changes.
  const grandTotal = initialData.wallets.reduce((sum, w) => sum + w.totalValue, 0)
  const shareOfTotal = (value: number) => (grandTotal > 0 ? (value / grandTotal) * 100 : 0)
  const truncate = (addr: string) => `${addr.slice(0, 6)}…${addr.slice(-4)}`
  const sectionLink = (section: (typeof walletSections)[number]) =>
    section.safeUrl ||
    section.externalUrl ||
    (section.address ? `https://basescan.org/address/${section.address}` : undefined)

  return (
    <div className="space-y-8 max-w-7xl mx-auto w-full">
      {initialData.error && (
        <div className="bg-amber-400/10 border border-amber-400/20 text-amber-400 px-6 py-4 rounded-2xl flex items-center gap-4 animate-slide-in">
          <span className="material-symbols-outlined shrink-0 text-3xl">warning</span>
          <div className="flex-1">
            <p className="font-bold text-sm uppercase tracking-wider mb-0.5 whitespace-nowrap overflow-hidden text-ellipsis">
              Price Data Warning
            </p>
            <p className="text-xs opacity-80">{initialData.error}</p>
          </div>
        </div>
      )}

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="md:col-span-2 glass-elevated rounded-3xl p-8 relative overflow-hidden group">
          <div className="absolute top-0 right-0 w-64 h-64 bg-primary/10 blur-[100px] rounded-full -mr-20 -mt-20"></div>
          <div className="relative z-10 flex flex-col h-full justify-between">
            <div>
              <div className="flex items-center gap-2 mb-1">
                <p className="text-on-surface-variant text-sm font-medium uppercase tracking-widest">
                  Total Treasury Value
                </p>
                {initialData.error && (
                  <div className="group/tooltip relative flex items-center">
                    <span className="material-symbols-outlined text-amber-400 text-sm cursor-help">
                      error_outline
                    </span>
                    <div className="absolute left-1/2 -translate-x-1/2 bottom-full mb-2 px-3 py-2 bg-slate-900 border border-amber-400/20 text-amber-400 text-[10px] rounded-lg opacity-0 invisible group-hover/tooltip:opacity-100 group-hover/tooltip:visible transition-all whitespace-nowrap z-50 shadow-2xl">
                      Prices may be stale: {initialData.error}
                    </div>
                  </div>
                )}
              </div>
              <h3 className="text-5xl md:text-6xl font-extrabold text-on-surface tracking-tighter text-glow drop-shadow-[0_0_15px_rgba(125,211,252,0.3)]">
                {initialData.totalValue}
              </h3>
            </div>
          </div>
        </div>

        <div className="glass-panel p-6 rounded-2xl hover:glass-panel-elevated hover:scale-105 transition-all duration-300">
          <p className="text-on-surface-variant text-xs font-medium uppercase tracking-wider mb-2">
            Top Holding
          </p>
          <p className="text-xl font-bold text-on-surface">
            {initialData.topHolding?.symbol || '—'}
          </p>
          <p className="text-sm text-on-surface-variant">
            {initialData.topHolding?.percentage.toFixed(1)}% of total
          </p>
        </div>
      </div>

      {/* Top Holdings Aggregated */}
      <div className="space-y-4">
        <h3 className="text-xl font-bold text-on-surface">Top Holdings (Aggregated)</h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {initialData.aggregatedHoldings.slice(0, 4).map((holding, index) => (
            <div
              key={index}
              className="glass-panel p-5 rounded-2xl border-l-4 border-primary/40 hover:glass-panel-elevated transition-all group"
            >
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 rounded-full overflow-hidden flex items-center justify-center border border-sky-400/10 bg-slate-800">
                  {holding.logoURI ? (
                    <img
                      src={holding.logoURI}
                      alt={holding.symbol}
                      className="w-full h-full object-contain p-1.5"
                    />
                  ) : (
                    <span className="material-symbols-outlined text-sm text-primary">paid</span>
                  )}
                </div>
                <div>
                  <p className="font-bold text-on-surface leading-none mb-1">{holding.symbol}</p>
                  <p className="text-[10px] text-on-surface-variant uppercase font-bold tracking-widest">
                    {holding.name}
                  </p>
                </div>
              </div>
              <div className="space-y-1">
                <p className="text-lg font-black text-primary">
                  ${holding.totalValue.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                </p>
                <div className="flex justify-between items-center text-[10px]">
                  <span className="text-on-surface-variant">
                    {holding.totalBalance.toLocaleString(undefined, { maximumFractionDigits: 2 })}{' '}
                    {holding.symbol}
                  </span>
                  <span className="text-primary font-bold">{holding.percentage.toFixed(1)}%</span>
                </div>
                <div className="w-full h-1 bg-slate-800 rounded-full overflow-hidden mt-2">
                  <div
                    className="h-full bg-primary shadow-[0_0_8px_rgba(125,211,252,0.4)] transition-all duration-1000"
                    style={{ width: `${holding.percentage}%` }}
                  ></div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Chain Filter */}
      <div className="flex gap-2">
        {['all', 'Mainnet', 'Base', 'Arbitrum', 'Sonic', 'HyperEVM'].map((chain) => (
          <button
            key={chain}
            onClick={() => setSelectedChain(chain)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              selectedChain === chain
                ? 'bg-primary/10 text-primary'
                : 'text-on-surface-variant hover:text-on-surface'
            }`}
          >
            {chain === 'all' ? 'All Chains' : chain}
          </button>
        ))}
      </div>

      {/* Per-wallet sections */}
      <div className="space-y-4">
        <div className="flex justify-between items-end">
          <h3 className="text-xl font-bold text-on-surface">Asset Holdings by Wallet</h3>
          <div className="text-xs text-on-surface-variant pb-1">
            Prices provided by{' '}
            <a
              href="https://www.coingecko.com/"
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary hover:underline transition-all"
            >
              CoinGecko
            </a>
          </div>
        </div>

        {walletSections.length === 0 ? (
          <div className="glass rounded-3xl px-6 py-10 text-center text-on-surface-variant border-sky-400/5">
            No holdings for the selected chain.
          </div>
        ) : (
          <div className="space-y-8">
            {walletSections.map((section) => {
              const link = sectionLink(section)
              return (
                <div key={section.key} className="space-y-3">
                  <div className="flex items-center justify-between flex-wrap gap-2">
                    <div className="flex items-center gap-3 min-w-0">
                      <h4 className="text-lg font-bold text-on-surface">{section.label}</h4>
                      {section.address && link && (
                        <a
                          href={link}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center gap-1 text-xs font-mono text-on-surface-variant hover:text-primary transition-colors"
                          title={section.safeUrl ? 'Open in Safe' : 'View account'}
                        >
                          {truncate(section.address)}
                          <span className="material-symbols-outlined text-sm align-middle">
                            open_in_new
                          </span>
                        </a>
                      )}
                    </div>
                    <div className="flex items-baseline gap-2">
                      <span className="text-xs font-bold text-on-surface-variant uppercase tracking-wider">
                        {shareOfTotal(section.totalValue).toFixed(1)}%
                      </span>
                      <span className="text-lg font-black text-primary">{section.value}</span>
                    </div>
                  </div>
                  <HoldingsTable holdings={section.holdings} />
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
