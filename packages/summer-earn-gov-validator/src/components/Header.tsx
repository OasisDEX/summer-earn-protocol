'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

import { ConnectButton } from './ConnectButton'
import { DarkModeToggle } from './DarkModeToggle'

export function Header() {
  const pathname = usePathname()

  return (
    <header className="bg-white dark:bg-gray-800 shadow-sm border-b border-gray-200 dark:border-gray-700">
      <div className="container mx-auto px-4 py-4">
        <div className="flex justify-between items-center">
          <div className="flex items-center space-x-8">
            <h1 className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
              Summer Earn Governance
            </h1>
            <nav className="flex space-x-6">
              <Link
                href="/"
                className={`text-sm font-medium transition-colors duration-200 ${
                  pathname === '/'
                    ? 'text-blue-600 dark:text-blue-400 border-b-2 border-blue-600 dark:border-blue-400 pb-1'
                    : 'text-gray-600 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400'
                }`}
              >
                Validator
              </Link>
              <Link
                href="/cross-chain"
                className={`text-sm font-medium transition-colors duration-200 ${
                  pathname === '/cross-chain'
                    ? 'text-blue-600 dark:text-blue-400 border-b-2 border-blue-600 dark:border-blue-400 pb-1'
                    : 'text-gray-600 dark:text-gray-300 hover:text-blue-600 dark:hover:text-blue-400'
                }`}
              >
                Cross-Chain Proposals
              </Link>
            </nav>
          </div>
          <div className="flex items-center space-x-4">
            <DarkModeToggle />
            <ConnectButton />
          </div>
        </div>
      </div>
    </header>
  )
}
