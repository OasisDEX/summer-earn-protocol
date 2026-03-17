'use client'

import { useEffect } from 'react'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error(error)
  }, [error])

  return (
    <div className="flex h-screen w-full flex-col items-center justify-center bg-[#f6f6f8] p-4 text-center">
      <div className="mb-6 rounded-full bg-rose-100 p-4 text-rose-600">
        <span className="material-icons-round text-4xl">error_outline</span>
      </div>
      <h2 className="mb-2 text-2xl font-black tracking-tight text-slate-900">
        Something went wrong!
      </h2>
      <p className="mb-8 max-w-md text-slate-500">
        The dashboard encountered an unexpected error. This might be due to a network issue or a
        configuration problem.
      </p>
      <div className="flex gap-4">
        <button
          onClick={() => reset()}
          className="rounded-xl bg-primary px-6 py-3 font-bold text-white shadow-lg shadow-primary/20 transition-all hover:bg-primary/90 active:scale-95"
        >
          Try again
        </button>
        <button
          onClick={() => window.location.reload()}
          className="rounded-xl border border-slate-200 bg-white px-6 py-3 font-bold text-slate-600 transition-all hover:bg-slate-50 active:scale-95"
        >
          Reload Page
        </button>
      </div>
    </div>
  )
}
