'use client'

import { BottomNavBar, CreateProposalFAB } from './BottomNavBar'
import { SideNavBar } from './SideNavBar'
import { TopNavBar } from './TopNavBar'

interface DashboardLayoutProps {
  children: React.ReactNode
  activeTab?: string
}

export function DashboardLayout({ children }: DashboardLayoutProps) {
  return (
    <div className="flex flex-col min-h-screen">
      <TopNavBar />
      <div className="flex flex-1">
        <SideNavBar />
        <main className="flex-1 min-w-0 p-6 lg:p-10 mb-20 lg:mb-0">{children}</main>
      </div>
      <BottomNavBar />
      <CreateProposalFAB />
    </div>
  )
}
