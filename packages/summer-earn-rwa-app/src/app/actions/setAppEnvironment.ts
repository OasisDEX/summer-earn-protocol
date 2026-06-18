'use server'

import { cookies } from 'next/headers'

import { APP_ENV_COOKIE, type AppEnvironment, parseAppEnvironment } from '@/config/appEnvironment'

export async function setAppEnvironment(env: AppEnvironment): Promise<void> {
  const store = await cookies()
  store.set(APP_ENV_COOKIE, parseAppEnvironment(env), {
    path: '/',
    maxAge: 60 * 60 * 24 * 365,
    sameSite: 'lax',
  })
}
