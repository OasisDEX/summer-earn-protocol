import { DashboardLayout } from '@/components/DashboardLayout'

export default function Loading() {
  return (
    <DashboardLayout>
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="flex flex-col items-center gap-3">
          <div className="w-8 h-8 border-2 border-brand-pink border-t-transparent rounded-full animate-spin" />
          <span className="text-[11px] font-semibold tracking-wider uppercase text-fg3">
            Loading
          </span>
        </div>
      </div>
    </DashboardLayout>
  )
}
