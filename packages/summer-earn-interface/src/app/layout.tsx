import { Inter } from 'next/font/google'
import { ConnectButton } from '../components/ConnectButton'
import './globals.css'
import { Providers } from './providers'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: 'Summer Earn Protocol Interface',
  description: 'A simple interface for Summer Earn Protocol',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <Providers>
          <div className="min-h-screen bg-charcoal-900">
            {/* Header */}
            <header className="bg-charcoal-800 border-b border-white/10 shadow-card backdrop-blur">
              <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div className="flex justify-between items-center h-16">
                  {/* Logo/Title */}
                  <div className="flex items-center">
                    <h1 className="text-2xl font-bold text-white">Summer Earn Protocol</h1>
                    <span className="ml-3 px-2 py-1 bg-violet-500/20 text-violet-400 text-xs font-medium rounded-full border border-violet-500/30">
                      v1.0
                    </span>
                  </div>

                  {/* Navigation/Actions */}
                  <div className="flex items-center space-x-4">
                    <ConnectButton />
                  </div>
                </div>
              </div>
            </header>

            {/* Main content */}
            <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">{children}</main>
          </div>
        </Providers>
      </body>
    </html>
  )
}
