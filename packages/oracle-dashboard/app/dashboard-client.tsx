'use client'

import { useState, useMemo } from 'react'
import dynamic from 'next/dynamic'
import {
  useOracleData,
  NETWORK_TO_CHAIN_ID,
  type NetworkType,
  type TickerStats,
} from '../hooks/useOracleData'
import { Sidebar } from '../components/dashboard/Sidebar'
import { DashboardHeader } from '../components/dashboard/DashboardHeader'
import { KPIGrid } from '../components/dashboard/KPIGrid'
import { OracleGrid } from '../components/dashboard/OracleGrid'
import { OracleDetail } from '../components/dashboard/OracleDetail'

const ManualUpdateModal = dynamic(() =>
  import('../components/ManualUpdateModal').then((mod) => mod.ManualUpdateModal),
)
const BatchUpdateModal = dynamic(() =>
  import('../components/BatchUpdateModal').then((mod) => mod.BatchUpdateModal),
)

interface DashboardClientProps {
  initialData?: TickerStats[]
}

export default function DashboardClient({ initialData }: DashboardClientProps) {
  const [currentTab, setCurrentTab] = useState<'overview' | 'activity' | 'settings'>('overview')
  const [selectedTicker, setSelectedTicker] = useState<string | null>(null)
  const [isUpdateModalOpen, setIsUpdateModalOpen] = useState(false)
  const [searchQuery, setSearchBar] = useState('')
  const [selectedNetwork, setSelectedNetwork] = useState<NetworkType>('base')
  const [isBatchModalOpen, setIsBatchModalOpen] = useState(false)
  const [selectedForBatch, setSelectedForBatch] = useState<string[]>([])
  const [isSelectionMode, setIsSelectionMode] = useState(false)

  const { stats, loading, refetch } = useOracleData(
    selectedNetwork,
    selectedNetwork === 'base' ? initialData : undefined,
  )

  const kpis = useMemo(
    () => ({
      total: stats.length,
      healthy: stats.filter((s) => s.isUpToDate).length,
      stale: stats.filter((s) => !s.isUpToDate).length,
    }),
    [stats],
  )

  const selectedOracle = useMemo(() => {
    return stats.find((s) => s.ticker === selectedTicker)
  }, [stats, selectedTicker])

  const selectedNetworkChainId = NETWORK_TO_CHAIN_ID[selectedNetwork]

  return (
    <div className="bg-background-light dark:bg-background-dark text-slate-900 dark:text-slate-100 font-display min-h-screen flex overflow-hidden w-full">
      <Sidebar
        currentTab={currentTab}
        onTabChange={setCurrentTab}
        selectedTicker={selectedTicker}
        onClearTicker={() => setSelectedTicker(null)}
      />

      <main className="flex-1 flex flex-col overflow-hidden">
        <DashboardHeader
          title={
            selectedTicker
              ? 'Oracle Details'
              : currentTab === 'activity'
                ? 'Activity Monitoring'
                : currentTab === 'settings'
                  ? 'Protocol Settings'
                  : 'Health Dashboard'
          }
          selectedNetwork={selectedNetwork}
          onNetworkChange={setSelectedNetwork}
          loading={loading}
          onRefresh={refetch}
          onBatchUpdate={() => {
            if (isSelectionMode) {
              if (selectedForBatch.length > 0) {
                setIsBatchModalOpen(true)
              } else {
                setIsSelectionMode(false)
              }
            } else {
              setIsSelectionMode(true)
              // Auto-select stale oracles initially
              setSelectedForBatch(
                stats.filter((s) => !s.isUpToDate && s.offChainPrice > 0).map((s) => s.ticker),
              )
            }
          }}
          canBatchUpdate={stats.some((s) => !s.isUpToDate && s.offChainPrice > 0)}
          isSelectionMode={isSelectionMode}
          selectedCount={selectedForBatch.length}
          onCancelSelection={() => {
            setIsSelectionMode(false)
            setSelectedForBatch([])
          }}
        />

        <div className="flex-1 overflow-y-auto custom-scrollbar p-8 space-y-8">
          {loading && stats.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-64 space-y-4">
              <div className="h-12 w-12 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
              <p className="text-slate-500 font-bold animate-pulse">Fetching Oracle Data...</p>
            </div>
          ) : selectedTicker && selectedOracle ? (
            <OracleDetail
              oracle={selectedOracle}
              // selectedNetwork={selectedNetwork}
              onBack={() => setSelectedTicker(null)}
              onTriggerUpdate={() => setIsUpdateModalOpen(true)}
            />
          ) : currentTab === 'overview' ? (
            <>
              <KPIGrid {...kpis} />
              <OracleGrid
                stats={stats}
                searchQuery={searchQuery}
                onSearchChange={setSearchBar}
                onSelectOracle={setSelectedTicker}
                selectedForBatch={selectedForBatch}
                isSelectionMode={isSelectionMode}
                onToggleBatchSelection={(ticker) => {
                  setSelectedForBatch((prev) =>
                    prev.includes(ticker) ? prev.filter((t) => t !== ticker) : [...prev, ticker],
                  )
                }}
              />
            </>
          ) : currentTab === 'activity' ? (
            <div className="bg-white rounded-xl border border-slate-200 p-8 text-center py-20">
              <span className="material-icons-round text-slate-300 text-6xl mb-4">history</span>
              <h3 className="text-xl font-bold">Activity Log</h3>
              <p className="text-slate-500">
                Recent heartbeat and manual update events will appear here.
              </p>
            </div>
          ) : (
            <div className="bg-white rounded-xl border border-slate-200 p-8 text-center py-20">
              <span className="material-icons-round text-slate-300 text-6xl mb-4">settings</span>
              <h3 className="text-xl font-bold">Protocol Settings</h3>
              <p className="text-slate-500">
                Manage global oracle configurations and registry permissions.
              </p>
            </div>
          )}
        </div>

        <footer className="h-12 border-t border-primary/5 px-8 flex items-center justify-between bg-white dark:bg-background-dark/50 text-[10px] font-extrabold uppercase tracking-widest text-slate-400">
          <div className="flex gap-4">
            <span className="flex items-center gap-1">
              <div className="w-1.5 h-1.5 rounded-full bg-emerald-500"></div> API Connected
            </span>
            <span className="flex items-center gap-1">
              <div className="w-1.5 h-1.5 rounded-full bg-emerald-500"></div> Blockchain Live
            </span>
          </div>
          <div className="flex gap-6">
            <span>Summer Earn Protocol</span>
            <span>v1.0.0-Stable</span>
          </div>
        </footer>
      </main>

      {selectedOracle ? (
        <ManualUpdateModal
          isOpen={isUpdateModalOpen}
          onClose={() => setIsUpdateModalOpen(false)}
          ticker={selectedOracle.ticker}
          onChainPrice={selectedOracle.onChainPrice}
          offChainPrice={selectedOracle.offChainPrice}
          oracleAddress={selectedOracle.oracleAddress}
          chainId={selectedNetworkChainId}
        />
      ) : null}

      <BatchUpdateModal
        isOpen={isBatchModalOpen}
        onClose={() => {
          setIsBatchModalOpen(false)
          setIsSelectionMode(false)
          setSelectedForBatch([])
        }}
        oracles={stats
          .filter((s) => selectedForBatch.includes(s.ticker))
          .map((s) => ({
            ticker: s.ticker,
            oracleAddress: s.oracleAddress,
            onChainPrice: s.onChainPrice,
            offChainPrice: s.offChainPrice,
          }))}
        chainId={selectedNetworkChainId}
      />
    </div>
  )
}
