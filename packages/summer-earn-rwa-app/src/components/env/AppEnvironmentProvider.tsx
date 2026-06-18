'use client'

import { createContext, useContext } from 'react'

import { type AppEnvironment, DEFAULT_APP_ENVIRONMENT } from '@/config/appEnvironment'

const AppEnvironmentContext = createContext<AppEnvironment>(DEFAULT_APP_ENVIRONMENT)

export function AppEnvironmentProvider({
  env,
  children,
}: {
  env: AppEnvironment
  children: React.ReactNode
}) {
  return <AppEnvironmentContext.Provider value={env}>{children}</AppEnvironmentContext.Provider>
}

export function useAppEnvironment(): AppEnvironment {
  return useContext(AppEnvironmentContext)
}
