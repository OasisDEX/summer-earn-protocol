'use client'

import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

interface SidebarProps {
  currentTab: 'overview' | 'activity' | 'settings'
  onTabChange: (tab: 'overview' | 'activity' | 'settings') => void
  selectedTicker: string | null
  onClearTicker: () => void
}

export function Sidebar({ currentTab, onTabChange, selectedTicker, onClearTicker }: SidebarProps) {
  return (
    <aside className="w-20 lg:w-64 border-r border-primary/10 bg-white dark:bg-background-dark/50 flex flex-col items-center lg:items-start transition-all">
      <div className="p-6 flex items-center gap-3 w-full">
        <div className="w-10 h-10 bg-primary rounded-xl flex items-center justify-center">
          <span className="material-icons-round text-white text-2xl">insights</span>
        </div>
        <span className="hidden lg:block font-extrabold text-xl tracking-tight text-primary">
          OracleHealth
        </span>
      </div>
      <nav className="mt-4 flex-1 w-full px-3 space-y-2">
        <button
          onClick={() => {
            onClearTicker()
            onTabChange('overview')
          }}
          className={cn(
            'flex items-center gap-4 px-4 py-3 rounded-xl transition-all w-full text-left',
            currentTab === 'overview' && !selectedTicker
              ? 'bg-primary/10 text-primary'
              : 'text-slate-400 hover:text-primary hover:bg-primary/5',
          )}
        >
          <span className="material-icons-round">dashboard</span>
          <span className="hidden lg:block font-semibold">Overview</span>
        </button>
        <button
          onClick={() => {
            onClearTicker()
            onTabChange('activity')
          }}
          className={cn(
            'flex items-center gap-4 px-4 py-3 rounded-xl transition-all w-full text-left',
            currentTab === 'activity'
              ? 'bg-primary/10 text-primary'
              : 'text-slate-400 hover:text-primary hover:bg-primary/5',
          )}
        >
          <span className="material-icons-round">history</span>
          <span className="hidden lg:block font-semibold">Activity Log</span>
        </button>
        <button
          onClick={() => {
            onClearTicker()
            onTabChange('settings')
          }}
          className={cn(
            'flex items-center gap-4 px-4 py-3 rounded-xl transition-all w-full text-left',
            currentTab === 'settings'
              ? 'bg-primary/10 text-primary'
              : 'text-slate-400 hover:text-primary hover:bg-primary/5',
          )}
        >
          <span className="material-icons-round">settings</span>
          <span className="hidden lg:block font-semibold">Settings</span>
        </button>
      </nav>
      <div className="p-6 w-full border-t border-primary/5">
        <div className="mt-4 p-4 rounded-xl bg-primary/5 hidden lg:block">
          <p className="text-xs font-bold text-primary uppercase tracking-widest">Network Status</p>
          <div className="flex items-center gap-2 mt-2">
            <div className="w-2 h-2 rounded-full bg-emerald-500"></div>
            <p className="text-sm font-medium text-slate-600 dark:text-slate-300">Base Connected</p>
          </div>
        </div>
      </div>
    </aside>
  )
}
