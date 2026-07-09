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
            ? 'bg-primary text-on-primary shadow-sm'
            : 'text-on-surface-variant hover:text-on-surface transition-colors'
        }`}
      >
        Production
      </button>
      <button
        onClick={() => setEnvironment('staging')}
        className={`px-4 py-1.5 text-xs font-medium rounded-md transition-colors ${
          environment === 'staging'
            ? 'bg-primary text-on-primary shadow-sm'
            : 'text-on-surface-variant hover:text-on-surface transition-colors'
        }`}
      >
        Staging
      </button>
    </>
  )
}
