import { useCallback } from 'react'

import type { Environment } from '../config/environments'
import { useLocalStorage } from './useLocalStorage'

export function useEnvironment() {
  const [environment, setEnvironment] = useLocalStorage<Environment>('environment', 'production')

  const toggleEnvironment = useCallback(() => {
    console.log('toggling environment', environment)
    setEnvironment((prev) => (prev === 'production' ? 'staging' : 'production'))
  }, [setEnvironment])

  return {
    environment,
    setEnvironment,
    toggleEnvironment,
  }
}
