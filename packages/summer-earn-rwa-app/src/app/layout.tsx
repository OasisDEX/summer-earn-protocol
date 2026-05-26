'use cache'

import { Suspense } from 'react'
import type { Metadata } from 'next'

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
            <Suspense fallback={<SidebarSkeleton />}>
              <Sidebar />
            </Suspense>
            <main>
              <Suspense fallback={null}>{children}</Suspense>
            </main>
          </div>
        </Providers>
      </body>
    </html>
  )
}
