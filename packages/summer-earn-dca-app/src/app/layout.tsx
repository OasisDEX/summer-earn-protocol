import type { Metadata } from 'next'

import { Sidebar } from '@/components/shell/Sidebar'

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
  title: 'summer.fi — DCA on Summer.fi',
  description: 'Recurring dollar-cost-averaging strategies on Summer.fi vaults',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" data-theme="dark" data-density="cozy">
      <body>
        <Providers>
          <div className="bg-glow" aria-hidden />
          <div className="bg-grid" aria-hidden />
          <div className="app">
            <Sidebar />
            <main>{children}</main>
          </div>
        </Providers>
      </body>
    </html>
  )
}
