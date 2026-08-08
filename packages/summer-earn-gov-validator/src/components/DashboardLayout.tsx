import { Suspense } from 'react'

import { BottomNavBar, CreateProposalFAB } from './BottomNavBar'
import { TopNavBar } from './TopNavBar'

interface DashboardLayoutProps {
  children: React.ReactNode
  activeTab?: string
}

export function DashboardLayout({ children }: DashboardLayoutProps) {
  return (
    <div className="flex flex-col min-h-screen bg-bg text-fg">
      <Suspense fallback={null}>
        <TopNavBar />
      </Suspense>
      <main className="flex-1 min-w-0 w-full max-w-[1240px] mx-auto px-5 py-6 pb-20 lg:pb-16">
        {children}
      </main>
      <Suspense fallback={null}>
        <BottomNavBar />
      </Suspense>
      <CreateProposalFAB />
    </div>
  )
}
