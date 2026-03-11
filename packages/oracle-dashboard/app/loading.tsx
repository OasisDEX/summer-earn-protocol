export default function Loading() {
  return (
    <div className="flex h-screen w-full items-center justify-center bg-[#f6f6f8]">
      <div className="flex flex-col items-center gap-4">
        <div className="h-12 w-12 animate-spin rounded-full border-4 border-primary border-t-transparent"></div>
        <p className="font-display text-sm font-bold text-slate-500 uppercase tracking-widest animate-pulse">
          Initializing Dashboard...
        </p>
      </div>
    </div>
  )
}
