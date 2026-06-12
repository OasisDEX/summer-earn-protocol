import { Suspense } from 'react'
import type { Metadata } from 'next'

import { AppEnvironmentBoundary } from '@/components/env/AppEnvironmentBoundary'
import { Sidebar } from '@/components/shell/Sidebar'
import { SidebarSkeleton } from '@/components/shell/SidebarSkeleton'

import { Providers } from './providers'

import '@fontsource/geist/300.css'
import '@fontsource/geist/400.css'
import '@fontsource/geist/500.css'
import '@fontsource/geist/600.css'
import '@fontsource/geist/700.css'
import '@fontsource/geist-mono/400.css'
import '@fontsource/geist-mono/500.css'
import './globals.css'

export const metadata: Metadata = {
  title: 'Summer Earn RWA — institutional rounds vaults',
  description:
    'Institutional deposits, settlement, and admin for Summer.fi rounds-vault wrapped fleets',
}

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" data-theme="dark" data-density="cozy">
      <body>
        <Providers>
          <div className="bg-glow" aria-hidden />
          <div className="bg-grid" aria-hidden />
          <div className="app">
            {/* The environment cookie read makes this subtree dynamic — the
                boundary must stay inside Suspense for PPR. */}
            <Suspense fallback={<SidebarSkeleton />}>
              <AppEnvironmentBoundary>
                <Sidebar />
              </AppEnvironmentBoundary>
            </Suspense>
            <main>
              <Suspense fallback={null}>
                <AppEnvironmentBoundary>{children}</AppEnvironmentBoundary>
              </Suspense>
            </main>
          </div>
        </Providers>
      </body>
    </html>
  )
}
