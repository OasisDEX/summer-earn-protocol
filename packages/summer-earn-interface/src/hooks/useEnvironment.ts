import { createContext, createElement, useCallback, useContext } from 'react'

import type { Environment } from '../config/environments'
import { useLocalStorage } from './useLocalStorage'

interface EnvironmentContextValue {
  environment: Environment
  setEnvironment: (env: Environment) => void
  toggleEnvironment: () => void
}

const EnvironmentContext = createContext<EnvironmentContextValue | undefined>(undefined)

export function EnvironmentProvider({ children }: { children: React.ReactNode }) {
  const [environment, setEnvironment] = useLocalStorage<Environment>('environment', 'production')

  const toggleEnvironment = useCallback(() => {
    setEnvironment((prev) => (prev === 'production' ? 'staging' : 'production'))
  }, [setEnvironment])

  return createElement(
    EnvironmentContext.Provider,
    { value: { environment, setEnvironment, toggleEnvironment } },
    children,
  )
}

export function useEnvironment() {
  const ctx = useContext(EnvironmentContext)
  if (!ctx) {
    throw new Error('useEnvironment must be used within an EnvironmentProvider')
  }
  return ctx
}
