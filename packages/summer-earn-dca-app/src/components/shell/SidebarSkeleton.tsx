export function SidebarSkeleton() {
  return (
    <aside
      aria-busy="true"
      className="sticky top-0 flex h-screen flex-col gap-6 border-r border-[var(--border-faint)] bg-[rgba(8,8,12,0.6)] px-4 py-6 backdrop-blur-[20px]"
    >
      <div className="flex items-center gap-2.5 px-2 py-1 text-[18px] font-semibold tracking-[-0.02em]">
        <span
          className="relative h-[22px] w-[22px] rounded-[8px]"
          style={{
            background: 'linear-gradient(135deg, var(--pink) 0%, var(--violet) 100%)',
            boxShadow: '0 0 0 4px rgba(255,73,160,0.10)',
          }}
        >
          <span className="absolute inset-[5px] rounded-[4px]" style={{ background: 'var(--bg)' }} />
        </span>
        summer.fi
      </div>

      <nav className="flex flex-col gap-0.5">
        <div className="px-3 pb-1 pt-2 text-[11px] uppercase tracking-[0.08em] text-[var(--text-4)]">
          Workspace
        </div>
        <div className="flex w-full items-center gap-2.5 rounded-md border border-transparent px-3 py-[9px] text-sm text-[var(--text-2)]">
          Portfolio
        </div>
        <div className="flex w-full items-center gap-2.5 rounded-md border border-transparent px-3 py-[9px] text-sm text-[var(--text-2)]">
          New strategy
        </div>
      </nav>

      <div className="mt-auto h-[112px] animate-pulse rounded-lg border border-[var(--border-faint)] bg-[var(--surface)]" />
    </aside>
  )
}
