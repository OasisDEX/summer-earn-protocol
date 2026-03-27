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
        <div className="glass-panel p-8 rounded-2xl max-w-md">
          <span className="material-symbols-outlined text-6xl text-error mb-4">error</span>
          <h2 className="text-2xl font-bold text-on-surface mb-2">Something went wrong</h2>
          <p className="text-on-surface-variant mb-6">
            {error.message || 'An unexpected error occurred'}
          </p>
          <button
            onClick={() => reset()}
            className="px-6 py-3 bg-primary text-on-primary rounded-lg font-semibold hover:brightness-110 active:scale-95 transition-all"
          >
            Try again
          </button>
        </div>
      </div>
    </DashboardLayout>
  )
}
