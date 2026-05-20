import type { Metadata } from 'next'

import { Providers } from './providers'

import './globals.css'

export const metadata: Metadata = {
  title: 'Summer Earn DCA',
  description: 'Recurring dollar-cost-averaging strategies on Summer.fi vaults',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
