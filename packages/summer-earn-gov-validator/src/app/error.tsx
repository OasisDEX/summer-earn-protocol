'use client'

import { useEffect } from 'react'

import { DashboardLayout } from '@/components/DashboardLayout'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    // Log the error to an error reporting service
    console.error(error)
  }, [error])

  return (
    <DashboardLayout>
      <div className="flex flex-col items-center justify-center min-h-[50vh] text-center">
        <div className="border border-line rounded-xl bg-console-surface p-8 max-w-md w-full">
          <div className="w-12 h-12 mx-auto mb-4 rounded-xl bg-crit-bg flex items-center justify-center text-crit text-2xl font-bold">
            !
          </div>
          <h2 className="text-lg font-semibold text-fg mb-2">Something went wrong</h2>
          <p className="text-fg2 text-sm mb-6">{error.message || 'An unexpected error occurred'}</p>
          <button
            onClick={() => reset()}
            className="h-[34px] px-5 bg-brand-gradient text-white rounded-full text-xs font-semibold hover:brightness-110 active:scale-95 transition-all"
          >
            Try again
          </button>
        </div>
      </div>
    </DashboardLayout>
  )
}
