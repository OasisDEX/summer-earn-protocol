'use client'

import { useEnvironment } from '@/hooks/useEnvironment'

export function EnvironmentSelector() {
  const { environment, setEnvironment } = useEnvironment()

  return (
    <div className="flex items-center space-x-3 bg-charcoal-700/50 rounded-lg px-3 py-1.5 border border-white/5">
      <span className="text-xs font-medium text-gray-400 uppercase tracking-wider">Env</span>
      <div className="flex space-x-1 bg-charcoal-900 rounded p-0.5">
        <button
          onClick={() => setEnvironment('production')}
          className={`px-3 py-1 text-xs font-medium rounded transition-colors ${
            environment === 'production'
              ? 'bg-violet-500 text-white shadow-sm'
              : 'text-gray-400 hover:text-gray-200 hover:bg-white/5'
          }`}
        >
          Prod
        </button>
        <button
          onClick={() => setEnvironment('staging')}
          className={`px-3 py-1 text-xs font-medium rounded transition-colors ${
            environment === 'staging'
              ? 'bg-amber-500 text-white shadow-sm'
              : 'text-gray-400 hover:text-gray-200 hover:bg-white/5'
          }`}
        >
          Dev
        </button>
      </div>
    </div>
  )
}
