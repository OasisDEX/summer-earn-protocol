'use client'

import { useTransition } from 'react'
import { useRouter } from 'next/navigation'

import { setAppEnvironment } from '@/app/actions/setAppEnvironment'
import { useAppEnvironment } from '@/components/env/AppEnvironmentProvider'
import { Segmented } from '@/components/ui/Segmented'
import type { AppEnvironment } from '@/config/appEnvironment'

export function EnvironmentSwitch() {
  const env = useAppEnvironment()
  const router = useRouter()
  const [isPending, startTransition] = useTransition()

  const select = (next: AppEnvironment) => {
    if (next === env || isPending) return
    startTransition(async () => {
      await setAppEnvironment(next)
      router.refresh()
    })
  }

  return (
    <div className={isPending ? 'opacity-60' : undefined}>
      <div className="px-3 pb-1 text-[11px] uppercase tracking-[0.08em] text-[var(--text-4)]">
        Environment
      </div>
      <Segmented
        className="mx-2 w-[calc(100%-1rem)] [&>button]:flex-1"
        value={env}
        onChange={select}
        options={[
          { value: 'production', label: 'Prod' },
          { value: 'staging', label: 'Staging' },
        ]}
      />
    </div>
  )
}
