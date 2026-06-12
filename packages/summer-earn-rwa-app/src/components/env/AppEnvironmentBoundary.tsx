import { AppEnvironmentProvider } from '@/components/env/AppEnvironmentProvider'
import { getAppEnvironment } from '@/lib/server/appEnvironment'

// Server component: reads the environment cookie once per request and feeds it
// into the client context, so client components render the correct value
// during SSR (no document.cookie reads, no hydration mismatch). Must sit
// inside a Suspense boundary — the cookie read makes this subtree dynamic.
export async function AppEnvironmentBoundary({ children }: { children: React.ReactNode }) {
  const env = await getAppEnvironment()
  return <AppEnvironmentProvider env={env}>{children}</AppEnvironmentProvider>
}
