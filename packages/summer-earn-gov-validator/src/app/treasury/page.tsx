import { Header } from '@/components/Header'
import { TreasuryList } from '@/components/TreasuryList'

export default function TreasuryPage() {
  return (
    <>
      <Header />
      <main className="max-w-6xl mx-auto p-8 min-h-screen bg-gray-50 dark:bg-gray-900">
        <div className="mb-10 text-center">
          <h1 className="text-gray-900 dark:text-white mb-2 text-4xl font-black tracking-tight uppercase">
            Protocol Treasury
          </h1>
          <p className="text-gray-500 dark:text-gray-400 text-sm font-medium tracking-wide flex items-center justify-center gap-2">
            Multi-chain asset tracking for the Summer Earn Protocol Timelock
          </p>
        </div>

        <div className="bg-white/50 dark:bg-gray-800/50 p-6 rounded-3xl shadow-xl backdrop-blur-sm border border-gray-200 dark:border-gray-700">
          <TreasuryList />
        </div>
      </main>
    </>
  )
}
