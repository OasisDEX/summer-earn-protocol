'use client'

interface StatCardProps {
  label: string
  value: string
  suffix?: string
  highlight?: boolean
}

export function StatCard({ label, value, suffix, highlight = false }: StatCardProps) {
  return (
    <div className={`glass p-5 rounded-xl ${highlight ? 'border-primary/20 bg-primary/5' : ''}`}>
      <p
        className={`text-xs font-semibold uppercase tracking-wider mb-1 ${
          highlight ? 'text-primary' : 'text-slate-500'
        }`}
      >
        {label}
      </p>
      <h3 className="text-2xl font-bold text-white">
        {value}
        {suffix && <span className="text-lg font-normal text-slate-400"> {suffix}</span>}
      </h3>
    </div>
  )
}
