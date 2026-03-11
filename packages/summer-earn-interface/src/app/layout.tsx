import { Inter } from 'next/font/google'
import Link from 'next/link'

import { ConnectButton } from '../components/ConnectButton'
import { EnvironmentSelector } from '../components/EnvironmentSelector'
import { Providers } from './providers'

import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: 'Summer Earn Protocol Interface',
  description: 'A simple interface for Summer Earn Protocol',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${inter.className} bg-background-dark text-slate-200 font-display min-h-screen`}
      >
        <Providers>
          <div className="min-h-screen bg-charcoal-900">
            {/* Header */}
            <header className="sticky top-0 z-50 glass border-b border-white/10 px-6 py-4">
              <div className="max-w-7xl mx-auto flex items-center justify-between">
                <Link
                  href="/"
                  className="flex items-center space-x-2 hover:opacity-90 transition-opacity"
                >
                  <div className="w-10 h-10 bg-primary rounded-lg flex items-center justify-center shadow-lg shadow-primary/20">
                    <span className="text-white text-xl">☀</span>
                  </div>
                  <div>
                    <h1 className="text-xl font-bold tracking-tight text-white">
                      Summer <span className="text-primary">Earn</span>
                    </h1>
                    <div className="flex items-center space-x-2 mt-0.5">
                      <span className="text-[10px] uppercase tracking-widest text-slate-500 font-semibold bg-white/5 px-1.5 py-0.5 rounded">
                        v1.0.2 Protocol
                      </span>
                    </div>
                  </div>
                </Link>
                <div className="flex items-center space-x-6">
                  <div className="hidden md:flex items-center bg-black/40 p-1 rounded-lg border border-white/5">
                    <EnvironmentSelector />
                  </div>
                  <ConnectButton />
                </div>
              </div>
            </header>

            {/* Main content */}
            <main className="max-w-none px-6 py-8">{children}</main>
          </div>
        </Providers>
      </body>
    </html>
  )
}
