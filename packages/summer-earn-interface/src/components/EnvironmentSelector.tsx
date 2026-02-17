'use client'

import { useEnvironment } from '@/hooks/useEnvironment'

export function EnvironmentSelector() {
  const { environment, setEnvironment } = useEnvironment()

  return (
    <>
      <button
        onClick={() => setEnvironment('production')}
        className={`px-4 py-1.5 text-xs font-medium rounded-md transition-colors ${
          environment === 'production'
            ? 'bg-primary text-white shadow-sm'
            : 'text-slate-400 hover:text-white transition-colors'
        }`}
      >
        Production
      </button>
      <button
        onClick={() => setEnvironment('staging')}
        className={`px-4 py-1.5 text-xs font-medium rounded-md transition-colors ${
          environment === 'staging'
            ? 'bg-primary text-white shadow-sm'
            : 'text-slate-400 hover:text-white transition-colors'
        }`}
      >
        Staging
      </button>
    </>
  )
}
