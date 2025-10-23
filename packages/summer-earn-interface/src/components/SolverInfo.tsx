'use client'

interface SolverInfoProps {
  solverAddress: string
  totalAssets: string
  bondAmount: string
  isVouched: boolean
  chainId: string
}

export function SolverInfo({
  solverAddress,
  totalAssets,
  bondAmount,
  isVouched,
  chainId,
}: SolverInfoProps) {
  const getExplorerUrl = (address: string) => {
    if (chainId === '8453') {
      return `https://basescan.org/address/${address}`
    }
    return `https://etherscan.io/address/${address}`
  }

  return (
    <div className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 bg-emerald-600 rounded-lg flex items-center justify-center">
          <span className="text-white font-bold text-lg">👤</span>
        </div>
        <div>
          <h3 className="text-lg font-semibold text-white">Solver Information</h3>
          <p className="text-sm text-gray-400">Current solver details and status</p>
        </div>
      </div>

      <div className="space-y-4">
        {/* Solver Address */}
        <div>
          <span className="text-gray-400 text-sm">Solver Address:</span>
          <div className="font-mono text-sm bg-charcoal-700 p-2 rounded mt-1 break-all">
            {solverAddress}
          </div>
          <div className="flex gap-2 mt-2">
            <a
              href={getExplorerUrl(solverAddress)}
              target="_blank"
              rel="noopener noreferrer"
              className="px-3 py-1 bg-emerald-600 hover:bg-emerald-700 text-white text-sm rounded transition-colors"
            >
              View on Explorer
            </a>
          </div>
        </div>

        {/* Status Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Total Assets */}
          <div className="bg-charcoal-700/50 p-3 rounded-lg">
            <div className="text-sm text-gray-400 mb-1">Total Assets</div>
            <div className="text-lg font-semibold text-white">{totalAssets}</div>
            <div className="text-xs text-gray-500">aToken balance</div>
          </div>

          {/* Bond Amount */}
          <div className="bg-charcoal-700/50 p-3 rounded-lg">
            <div className="text-sm text-gray-400 mb-1">Bond Amount</div>
            <div className="text-lg font-semibold text-white">{bondAmount}</div>
            <div className="text-xs text-gray-500">Summer tokens</div>
          </div>

          {/* Voucher Status */}
          <div className="bg-charcoal-700/50 p-3 rounded-lg">
            <div className="text-sm text-gray-400 mb-1">Voucher Status</div>
            <div
              className={`text-lg font-semibold ${isVouched ? 'text-green-400' : 'text-red-400'}`}
            >
              {isVouched ? '✓ Vouched' : '✗ Not Vouched'}
            </div>
            <div className="text-xs text-gray-500">
              {isVouched ? 'Ready to solve' : 'Insufficient bond'}
            </div>
          </div>
        </div>

        {/* Quick Actions */}
        <div className="pt-4 border-t border-white/10">
          <div className="flex flex-wrap gap-2">
            <button className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm rounded transition-colors">
              📊 View Intent History
            </button>
            <button className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white text-sm rounded transition-colors">
              ⚙️ Manage Bond
            </button>
            <button className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white text-sm rounded transition-colors">
              🔍 Monitor Performance
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
