import './globals.css'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Summer.Fi Auctions',
  description: 'View and participate in Summer.Fi token auctions',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        <main className="min-h-screen p-4 md:p-8">
          {children}
        </main>
      </body>
    </html>
  )
} 