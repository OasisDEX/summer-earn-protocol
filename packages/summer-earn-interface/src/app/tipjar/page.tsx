import { Suspense } from 'react'

import { TipJarDashboard } from './components/TipJarDashboard'

export default function TipJarPage() {
  return (
    <Suspense fallback={<div className="p-8 text-on-surface-variant">Loading TipJar…</div>}>
      <TipJarDashboard />
    </Suspense>
  )
}
