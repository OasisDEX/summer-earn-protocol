import { Suspense } from 'react'

import { LzConfigDashboard } from './LzConfigDashboard'

export default function LzConfigPage() {
  return (
    <Suspense fallback={<div className="p-8 text-on-surface-variant">Loading LZ config…</div>}>
      <LzConfigDashboard />
    </Suspense>
  )
}
