import { memo } from 'react'

interface KPIGridProps {
  total: number
  healthy: number
  stale: number
}

export const KPIGrid = memo(function KPIGrid({ total, healthy, stale }: KPIGridProps) {
  return (
    <section className="grid grid-cols-1 md:grid-cols-3 gap-6">
      <div className="bg-white dark:bg-slate-900 p-6 rounded-2xl border border-primary/5 shadow-sm">
        <div className="flex justify-between items-start">
          <div>
            <p className="text-slate-500 text-sm font-semibold uppercase tracking-wider">
              Total Oracles
            </p>
            <h2 className="text-4xl font-extrabold mt-1">{total}</h2>
          </div>
          <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center text-primary">
            <span className="material-icons-round">storage</span>
          </div>
        </div>
      </div>
      <div className="bg-white dark:bg-slate-900 p-6 rounded-2xl border border-primary/5 shadow-sm">
        <div className="flex justify-between items-start">
          <div>
            <p className="text-slate-500 text-sm font-semibold uppercase tracking-wider">Healthy</p>
            <h2 className="text-4xl font-extrabold mt-1 text-emerald-500">{healthy}</h2>
          </div>
          <div className="w-12 h-12 rounded-xl bg-emerald-500/10 flex items-center justify-center text-emerald-500">
            <span className="material-icons-round">check_circle</span>
          </div>
        </div>
      </div>
      <div className="bg-white dark:bg-slate-900 p-6 rounded-2xl border border-primary/5 shadow-sm">
        <div className="flex justify-between items-start">
          <div>
            <p className="text-slate-500 text-sm font-semibold uppercase tracking-wider">
              Stale / Warning
            </p>
            <h2 className="text-4xl font-extrabold mt-1 text-amber-500">{stale}</h2>
          </div>
          <div className="w-12 h-12 rounded-xl bg-amber-500/10 flex items-center justify-center text-amber-500">
            <span className="material-icons-round">warning</span>
          </div>
        </div>
      </div>
    </section>
  )
})
