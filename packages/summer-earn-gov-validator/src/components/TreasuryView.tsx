'use client'

import { useState } from 'react'

import { TreasuryData } from '@/services/treasury'

interface TreasuryViewProps {
  initialData: TreasuryData
}

export function TreasuryView({ initialData }: TreasuryViewProps) {
  const [selectedChain, setSelectedChain] = useState<string>('all')

  const filteredHoldings =
    selectedChain === 'all'
      ? initialData.holdings
      : initialData.holdings.filter((h) => h.chain.toLowerCase() === selectedChain.toLowerCase())

  return (
    <div className="space-y-8 max-w-7xl mx-auto w-full">
      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-4">
        <div className="md:col-span-2 glass-elevated rounded-3xl p-8 relative overflow-hidden group">
          <div className="absolute top-0 right-0 w-64 h-64 bg-primary/10 blur-[100px] rounded-full -mr-20 -mt-20"></div>
          <div className="relative z-10 flex flex-col h-full justify-between">
            <div>
              <p className="text-on-surface-variant text-sm font-medium uppercase tracking-widest mb-1">
                Total Treasury Value
              </p>
              <h3 className="text-5xl md:text-6xl font-extrabold text-on-surface tracking-tighter text-glow drop-shadow-[0_0_15px_rgba(125,211,252,0.3)]">
                {initialData.totalValue}
              </h3>
            </div>
          </div>
        </div>

        <div className="glass-panel p-6 rounded-2xl hover:glass-panel-elevated hover:scale-105 transition-all duration-300">
          <p className="text-on-surface-variant text-xs font-medium uppercase tracking-wider mb-2">
            24h Change
          </p>
          <p className="text-2xl font-bold text-emerald-400 drop-shadow-[0_0_8px_rgba(52,211,153,0.3)]">
            {initialData.change24h}
          </p>
        </div>

        <div className="glass-panel p-6 rounded-2xl hover:glass-panel-elevated hover:scale-105 transition-all duration-300">
          <p className="text-on-surface-variant text-xs font-medium uppercase tracking-wider mb-2">
            Top Holding
          </p>
          <p className="text-xl font-bold text-on-surface">ETH</p>
          <p className="text-sm text-on-surface-variant">70% of total</p>
        </div>
      </div>

      {/* Chain Filter */}
      <div className="flex gap-2">
        {['all', 'Mainnet', 'Base', 'Arbitrum', 'Sonic'].map((chain) => (
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

      {/* Holdings Table */}
      <div className="space-y-4">
        <div className="flex justify-between items-end">
          <h3 className="text-xl font-bold text-on-surface">Asset Holdings</h3>
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
                {filteredHoldings.map((holding, index) => (
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
      </div>
    </div>
  )
}
