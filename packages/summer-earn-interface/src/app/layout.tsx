import { Inter, Manrope } from 'next/font/google'
import Link from 'next/link'

import { ConnectButton } from '../components/ConnectButton'
import { EnvironmentSelector } from '../components/EnvironmentSelector'
import { Providers } from './providers'

import './globals.css'

const inter = Inter({ subsets: ['latin'], variable: '--font-inter' })
const manrope = Manrope({ subsets: ['latin'], variable: '--font-manrope' })

export const metadata = {
  title: 'Summer Earn Protocol Interface',
  description: 'A simple interface for Summer Earn Protocol',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`dark ${inter.variable} ${manrope.variable}`}>
      <body className="bg-surface text-on-surface font-sans min-h-screen">
        <Providers>
          <div className="min-h-screen">
            {/* Header */}
            <header className="sticky top-0 z-header glass px-6 py-4">
              <div className="max-w-7xl mx-auto flex items-center justify-between">
                <Link
                  href="/"
                  className="flex items-center space-x-2 hover:opacity-90 transition-opacity"
                >
                  <div className="w-10 h-10 bg-primary rounded-lg flex items-center justify-center shadow-lg shadow-primary/20">
                    <span className="text-on-primary text-xl">☀</span>
                  </div>
                  <div>
                    <h1 className="text-xl font-headline font-bold tracking-tight text-on-surface">
                      Summer <span className="text-primary">Earn</span>
                    </h1>
                    <div className="flex items-center space-x-2 mt-0.5">
                      <span className="text-[10px] uppercase tracking-widest text-on-surface-variant font-semibold bg-white/5 px-1.5 py-0.5 rounded">
                        v1.0.2 Protocol
                      </span>
                    </div>
                  </div>
                </Link>
                <div className="flex items-center space-x-6">
                  <Link
                    href="/tipjar"
                    className="hidden md:inline-block text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors"
                  >
                    TipJar
                  </Link>
                  <Link
                    href="/lz-config"
                    className="hidden md:inline-block text-sm font-medium text-on-surface-variant hover:text-on-surface transition-colors"
                  >
                    LZ Config
                  </Link>
                  <div className="hidden md:flex items-center bg-black/40 p-1 rounded-lg border border-white/5">
                    <EnvironmentSelector />
                  </div>
                  <ConnectButton />
                </div>
              </div>
              {/* Horizon line — the design pass's one signature glow */}
              <div
                aria-hidden="true"
                className="absolute inset-x-0 -bottom-px h-px bg-gradient-to-r from-primary/0 via-primary/60 to-secondary/40 shadow-[0_0_12px_rgba(137,172,255,0.35)]"
              />
            </header>

            {/* Main content */}
            <main className="max-w-7xl mx-auto px-6 py-8">{children}</main>
          </div>
        </Providers>
      </body>
    </html>
  )
}
