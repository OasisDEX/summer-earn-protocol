import { cookies } from 'next/headers'

import 'server-only'

import { APP_ENV_COOKIE, type AppEnvironment, parseAppEnvironment } from '@/config/appEnvironment'

// Reads the environment cookie. cookies() is request-scoped, so this must be
// called OUTSIDE any 'use cache' scope — read it in the page/boundary and pass
// the value down as an argument (it then becomes part of the cache key).
export async function getAppEnvironment(): Promise<AppEnvironment> {
  const store = await cookies()
  return parseAppEnvironment(store.get(APP_ENV_COOKIE)?.value)
}
