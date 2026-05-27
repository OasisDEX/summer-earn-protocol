export function ProposalsListSkeleton() {
  return (
    <div className="flex flex-col min-h-screen">
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 mb-10">
        <div>
          <div className="h-12 w-80 bg-slate-700 rounded-lg animate-pulse mb-2"></div>
          <div className="h-5 w-96 bg-slate-800 rounded animate-pulse"></div>
        </div>
      </div>

      <div className="flex gap-4 mb-8">
        <div className="h-10 w-20 bg-slate-700 rounded-lg animate-pulse"></div>
        <div className="h-10 w-20 bg-slate-700 rounded-lg animate-pulse"></div>
        <div className="h-10 w-20 bg-slate-700 rounded-lg animate-pulse"></div>
      </div>

      <div className="space-y-4">
        {[1, 2, 3].map((i) => (
          <div key={i} className="glass-panel p-6 rounded-2xl">
            <div className="flex items-center gap-3 mb-4">
              <div className="h-5 w-16 bg-slate-700 rounded animate-pulse"></div>
              <div className="h-5 w-20 bg-slate-700 rounded animate-pulse"></div>
            </div>
            <div className="h-7 w-3/4 bg-slate-700 rounded animate-pulse mb-2"></div>
            <div className="h-5 w-full bg-slate-800 rounded animate-pulse mb-4"></div>
            <div className="flex gap-6">
              <div className="h-5 w-32 bg-slate-800 rounded animate-pulse"></div>
              <div className="h-2 w-48 bg-slate-800 rounded-full animate-pulse"></div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
