// Runtime environment selector. Production and staging are DIFFERENT contract
// deployments (and different subgraph slugs — staging appends `-staging`), so
// the active environment decides both the institutions directory and every
// subgraph URL. Persisted in a cookie so server components, loaders, and
// client hooks all agree on one value.

export type AppEnvironment = 'production' | 'staging'

export const APP_ENV_COOKIE = 'app-env'

export const DEFAULT_APP_ENVIRONMENT: AppEnvironment = 'staging'

export function parseAppEnvironment(value: string | undefined | null): AppEnvironment {
  return value === 'production' || value === 'staging' ? value : DEFAULT_APP_ENVIRONMENT
}
