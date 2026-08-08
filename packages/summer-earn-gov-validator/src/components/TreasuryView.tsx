'use client'

import { useState } from 'react'

import type { TreasuryData, TreasuryHolding } from '@/services/treasury'

interface TreasuryViewProps {
  initialData: TreasuryData
}

function HoldingsTable({ holdings }: { holdings: TreasuryHolding[] }) {
  return (
    <div className="border border-line rounded-xl bg-console-surface overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full text-left">
          <thead className="bg-surface2 border-b border-line text-[11px] font-semibold tracking-wider text-fg3 uppercase">
            <tr>
              <th className="px-4.5 py-3">Token</th>
              <th className="px-4.5 py-3 text-right">Balance</th>
              <th className="px-4.5 py-3 text-right">USD Value</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-line text-xs">
            {holdings.map((holding, index) => (
              <tr key={index} className="hover:bg-surface2 transition-colors">
                <td className="px-4.5 py-3.5">
                  <div className="flex items-center gap-2.5">
                    <div className="w-6 h-6 rounded-full overflow-hidden flex items-center justify-center bg-surface3 flex-shrink-0 font-mono text-[10px] font-semibold text-fg">
                      {holding.logoURI ? (
                        <img
                          src={holding.logoURI}
                          alt={holding.symbol}
                          className="w-full h-full object-cover"
                        />
                      ) : (
                        holding.symbol.slice(0, 2)
                      )}
                    </div>
                    <div className="min-w-0">
                      <span className="font-mono text-xs font-semibold text-fg block">{holding.symbol}</span>
                      <span className="text-[11px] text-fg2 truncate block">
                        {holding.token} · {holding.chain}
                      </span>
                    </div>
                  </div>
                </td>
                <td className="px-4.5 py-3.5 font-mono text-fg2 text-right">
                  {holding.balance}
                </td>
                <td className="px-4.5 py-3.5 font-mono text-fg font-medium text-right">
                  {holding.value}
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

  const walletSections = initialData.wallets
    .map((section) => ({ ...section, holdings: section.holdings.filter(matchesChain) }))
    .filter((section) => section.holdings.length > 0)

  const chainOptions = ['all', 'Mainnet', 'Base', 'Arbitrum', 'Sonic', 'Hyperliquid']

  return (
    <div className="space-y-6 max-w-[1240px] mx-auto w-full">
      <div>
        <h1 className="m-0 text-[26px] font-semibold tracking-[-0.03em] text-fg">Treasury</h1>
        <p className="mt-1 text-fg2 text-xs">Prices provided by CoinGecko.</p>
      </div>

      {initialData.error && (
        <div className="bg-warn-bg border border-warn/20 text-warn px-4 py-3 rounded-xl flex items-center gap-3 text-xs">
          <span className="material-symbols-outlined shrink-0 text-xl">warning</span>
          <p className="flex-1 m-0">{initialData.error}</p>
        </div>
      )}

      {/* KPI Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-px bg-line border border-line rounded-xl overflow-hidden">
        <div className="bg-console-surface p-4">
          <div className="text-[11px] font-semibold tracking-wider uppercase text-fg3">
            Total Treasury Value
          </div>
          <div className="font-mono text-2xl font-medium tracking-tight text-fg mt-1.5">
            {initialData.totalValue}
          </div>
        </div>

        <div className="bg-console-surface p-4">
          <div className="text-[11px] font-semibold tracking-wider uppercase text-fg3">
            Top Holding
          </div>
          <div className="font-mono text-2xl font-medium tracking-tight text-fg mt-1.5">
            {initialData.topHolding?.symbol || '—'}
          </div>
          <div className="text-xs text-fg3 mt-0.5">
            {initialData.topHolding ? `${initialData.topHolding.percentage.toFixed(1)}% of total` : ''}
          </div>
        </div>

        <div className="bg-console-surface p-4 sm:col-span-2 lg:col-span-1">
          <div className="text-[11px] font-semibold tracking-wider uppercase text-fg3">
            Wallets Tracked
          </div>
          <div className="font-mono text-2xl font-medium tracking-tight text-fg mt-1.5">
            {initialData.wallets.length}
          </div>
        </div>
      </div>

      {/* Top Holdings Aggregated */}
      <section className="border border-line rounded-xl bg-console-surface overflow-hidden">
        <div className="px-4.5 py-3 border-b border-line text-xs font-semibold text-fg">
          Top holdings, aggregated
        </div>

        <div className="divide-y divide-line">
          {initialData.aggregatedHoldings.slice(0, 4).map((h, i) => (
            <div
              key={i}
              className="grid grid-cols-1 md:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)_minmax(0,1.4fr)] items-center gap-4 px-4.5 py-3.5"
            >
              <div className="flex items-center gap-3 min-w-0">
                <div className="w-7 h-7 rounded-full overflow-hidden flex items-center justify-center bg-surface3 flex-shrink-0 font-mono text-[10px] font-semibold text-fg">
                  {h.logoURI ? (
                    <img src={h.logoURI} alt={h.symbol} className="w-full h-full object-cover" />
                  ) : (
                    h.symbol.slice(0, 2)
                  )}
                </div>
                <div className="min-w-0">
                  <span className="block text-xs font-semibold text-fg">{h.symbol}</span>
                  <span className="block text-[11px] text-fg3 truncate">{h.name}</span>
                </div>
              </div>

              <div className="font-mono text-sm font-medium text-fg">
                ${h.totalValue.toLocaleString(undefined, { maximumFractionDigits: 0 })}
              </div>

              <div>
                <div className="flex justify-between font-mono text-[11px] text-fg3 mb-1">
                  <span>{h.totalBalance.toLocaleString(undefined, { maximumFractionDigits: 2 })} {h.symbol}</span>
                  <span>{h.percentage.toFixed(1)}%</span>
                </div>
                <div className="h-1.5 rounded-full bg-surface3 overflow-hidden">
                  <div
                    className="h-full rounded-full bg-brand-gradient"
                    style={{ width: `${Math.min(h.percentage, 100)}%` }}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Chain Filter Pills */}
      <div className="flex gap-1.5 flex-wrap">
        {chainOptions.map((chain) => (
          <button
            key={chain}
            onClick={() => setSelectedChain(chain)}
            className={`h-[30px] px-[11px] rounded-full border text-xs font-medium cursor-pointer transition-colors ${
              selectedChain === chain
                ? 'border-brand-pink bg-pink-bg text-brand-pink'
                : 'border-line2 bg-surface3 text-fg2 hover:text-fg'
            }`}
          >
            {chain === 'all' ? 'All chains' : chain}
          </button>
        ))}
      </div>

      {/* Per-wallet Sections */}
      <div className="flex flex-col gap-3.5">
        {walletSections.length === 0 ? (
          <div className="border border-line rounded-xl bg-console-surface p-6 text-center text-fg2 text-xs">
            No holdings for the selected chain.
          </div>
        ) : (
          walletSections.map((section) => (
            <section
              key={section.key}
              className="border border-line rounded-xl bg-console-surface overflow-hidden"
            >
              <div className="flex items-center justify-between gap-3 px-4.5 py-3 border-b border-line">
                <span className="text-xs font-semibold text-fg flex items-center gap-2">
                  {section.label}
                  {section.externalUrl && (
                    <a
                      href={section.externalUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-fg3 hover:text-brand-pink transition-colors"
                    >
                      <span className="material-symbols-outlined text-sm align-middle">
                        open_in_new
                      </span>
                    </a>
                  )}
                </span>
                <span className="font-mono text-sm font-medium text-fg">{section.value}</span>
              </div>
              <HoldingsTable holdings={section.holdings} />
            </section>
          ))
        )}
      </div>
    </div>
  )
}
