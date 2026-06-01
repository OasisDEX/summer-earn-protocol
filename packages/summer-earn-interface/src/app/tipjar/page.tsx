import { Suspense } from 'react'

import { TipJarDashboard } from './components/TipJarDashboard'

export default function TipJarPage() {
  return (
    <Suspense fallback={<div className="p-8 text-slate-400">Loading TipJar…</div>}>
      <TipJarDashboard />
    </Suspense>
  )
}
