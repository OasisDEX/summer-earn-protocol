'use client'

import { useEffect, useState } from 'react'
import { formatEther } from 'viem'
import { ChainSelector } from '../../components/ChainSelector'
import { ContractCard } from '../../components/ContractCard'
import { EnvironmentSelector } from '../../components/EnvironmentSelector'
import { SolverInfo } from '../../components/SolverInfo'
import { AdminModal } from '../../components/modals/AdminModal'
import { CreateBondModal } from '../../components/modals/CreateBondModal'
import { CreateIntentModal } from '../../components/modals/CreateIntentModal'
import { SolveIntentModal } from '../../components/modals/SolveIntentModal'
import { MOCK_INTENT_ORACLE_ADDRESSES } from '../../config/environments'
import { useEnvironment } from '../../hooks/useEnvironment'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import { useLocalStorage } from '../../hooks/useLocalStorage'
import { useSyncWalletChain } from '../../hooks/useSyncWalletChain'
import type { ChainId } from '../../types'

export default function IntentSystemPage() {
  const [storedChain, setStoredChain] = useLocalStorage<ChainId>('selectedChain', '8453') // Default to Base
  const [selectedChain, setSelectedChain] = useState<ChainId>(storedChain)
  const { environment, setEnvironment } = useEnvironment()
  const [copiedAddress, setCopiedAddress] = useState<string | null>(null)

  // Modal states
  const [showCreateIntent, setShowCreateIntent] = useState(false)
  const [showSolveIntent, setShowSolveIntent] = useState(false)
  const [showCreateBond, setShowCreateBond] = useState(false)
  const [showAdmin, setShowAdmin] = useState(false)

  useSyncWalletChain(selectedChain)

  useEffect(() => {
    setStoredChain(selectedChain)
  }, [selectedChain, setStoredChain])

  // Use the Intent System hook for real data
  const {
    intentData,
    solverInfo,
    isDeployed,
    intentBondFactory,
    intentHandler,
    genericIntentArk,
    aaveV3Escrow,
    tokens,
  } = useIntentSystem(environment, selectedChain)

  // Get mockIntentOracle from config
  const mockIntentOracle = MOCK_INTENT_ORACLE_ADDRESSES[environment][selectedChain]

  const copyToClipboard = async (address: string) => {
    try {
      await navigator.clipboard.writeText(address)
      setCopiedAddress(address)
      setTimeout(() => setCopiedAddress(null), 2000)
    } catch (err) {
      console.error('Failed to copy address:', err)
    }
  }

  const getExplorerUrl = (address: string) => {
    if (selectedChain === '8453') {
      return `https://basescan.org/address/${address}`
    }
    return `https://etherscan.io/address/${address}` // Default fallback
  }

  const getChainName = () => {
    switch (selectedChain) {
      case '8453':
        return 'Base'
      case '1':
        return 'Ethereum'
      case '42161':
        return 'Arbitrum'
      case '146':
        return 'Sonic'
      default:
        return `Chain ${selectedChain}`
    }
  }

  return (
    <main className="min-h-screen bg-charcoal-900 p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header Section */}
        <div className="mb-8">
          <div className="flex items-center gap-4 mb-4">
            <a href="/" className="text-blue-400 hover:text-blue-300 transition-colors">
              ← Back to Home
            </a>
          </div>

          <h1 className="text-3xl font-bold text-white mb-2">Intent System Configuration</h1>
          <p className="text-gray-300 mb-6">
            Monitor and manage the deployed Intent System contracts on {getChainName()}
          </p>

          <div className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <EnvironmentSelector selectedEnvironment={environment} onChange={setEnvironment} />
              <ChainSelector selectedChain={selectedChain} onChange={setSelectedChain} />
            </div>
          </div>
        </div>

        {/* Deployment Status */}
        <div className="mb-8">
          <div
            className={`p-4 rounded-lg border ${
              isDeployed
                ? 'bg-green-900/20 border-green-500/30 text-green-300'
                : 'bg-red-900/20 border-red-500/30 text-red-300'
            }`}
          >
            <div className="flex items-center gap-2">
              <div
                className={`w-3 h-3 rounded-full ${isDeployed ? 'bg-green-400' : 'bg-red-400'}`}
              />
              <span className="font-semibold">
                {isDeployed ? 'Intent System Deployed' : 'Intent System Not Deployed'}
              </span>
            </div>
            <p className="mt-2 text-sm opacity-80">
              {isDeployed
                ? `All core contracts are deployed and operational on ${getChainName()}`
                : `No Intent System contracts found on ${getChainName()}`}
            </p>
          </div>
        </div>

        {/* Contract Information */}
        {isDeployed && (
          <>
            {/* Core Contracts */}
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">Core Contracts</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <ContractCard
                  title="IntentBondFactory"
                  description="Manages solver bonds"
                  address={intentBondFactory}
                  icon="🏭"
                  color="bg-blue-600"
                  chainId={selectedChain}
                  onCopy={copyToClipboard}
                  copiedAddress={copiedAddress}
                />
                <ContractCard
                  title="IntentHandler"
                  description="Core intent management"
                  address={intentHandler}
                  icon="⚡"
                  color="bg-purple-600"
                  chainId={selectedChain}
                  onCopy={copyToClipboard}
                  copiedAddress={copiedAddress}
                />
              </div>
            </div>

            {/* Protocol Contracts */}
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">Protocol Contracts</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <ContractCard
                  title="GenericIntentArk"
                  description="Intent posting and management"
                  address={genericIntentArk}
                  icon="🚢"
                  color="bg-green-600"
                  chainId={selectedChain}
                  onCopy={copyToClipboard}
                  copiedAddress={copiedAddress}
                />
                <ContractCard
                  title="AaveV3Escrow"
                  description="Aave V3 integration adapter"
                  address={aaveV3Escrow}
                  icon="🏦"
                  color="bg-orange-600"
                  chainId={selectedChain}
                  onCopy={copyToClipboard}
                  copiedAddress={copiedAddress}
                />
              </div>
            </div>

            {/* Infrastructure */}
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">Infrastructure</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <ContractCard
                  title="MockIntentOracle"
                  description="Price verification (test)"
                  address={mockIntentOracle}
                  icon="🔮"
                  color="bg-yellow-600"
                  chainId={selectedChain}
                  onCopy={copyToClipboard}
                  copiedAddress={copiedAddress}
                />
              </div>
            </div>

            {/* Token Information */}
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">Supported Tokens</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {tokens &&
                  Object.entries(tokens).map(([symbol, address]) => (
                    <div
                      key={symbol}
                      className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur"
                    >
                      <div className="flex items-center gap-3 mb-4">
                        <div className="w-10 h-10 bg-indigo-600 rounded-lg flex items-center justify-center">
                          <span className="text-white font-bold text-lg">🪙</span>
                        </div>
                        <div>
                          <h3 className="text-lg font-semibold text-white">{symbol}</h3>
                          <p className="text-sm text-gray-400">Token contract</p>
                        </div>
                      </div>
                      <div className="space-y-3">
                        <div>
                          <span className="text-gray-400 text-sm">Address:</span>
                          <div className="font-mono text-sm bg-charcoal-700 p-2 rounded mt-1 break-all">
                            {address}
                          </div>
                        </div>
                        <div className="flex gap-2">
                          <a
                            href={getExplorerUrl(address)}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="px-3 py-1 bg-indigo-600 hover:bg-indigo-700 text-white text-sm rounded transition-colors"
                          >
                            View on Explorer
                          </a>
                          <button
                            onClick={() => copyToClipboard(address)}
                            className={`px-3 py-1 text-sm rounded transition-colors ${
                              copiedAddress === address
                                ? 'bg-green-600 text-white'
                                : 'bg-gray-600 hover:bg-gray-700 text-white'
                            }`}
                          >
                            {copiedAddress === address ? 'Copied!' : 'Copy Address'}
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
              </div>
            </div>

            {/* Intent System Actions */}
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">Intent System Actions</h2>

              {/* Intent Lifecycle Actions */}
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-white mb-3">🎯 Intent Lifecycle</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10">
                    <h4 className="font-semibold text-white mb-2">Create Intent</h4>
                    <p className="text-sm text-gray-400 mb-3">
                      Keeper calls GenericIntentArk.postIntent()
                    </p>
                    <div className="text-xs text-gray-500 space-y-1">
                      <div>• Required notional amount</div>
                      <div>• Term length</div>
                      <div>• Target yield</div>
                      <div>• Oracle & expiry</div>
                    </div>
                  </div>

                  <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10">
                    <h4 className="font-semibold text-white mb-2">Solve Intent</h4>
                    <p className="text-sm text-gray-400 mb-3">
                      Solver calls IntentHandler.solveIntent()
                    </p>
                    <div className="text-xs text-gray-500 space-y-1">
                      <div>• Must have sufficient bond</div>
                      <div>• Escrow yield upfront</div>
                      <div>• Oracle price validation</div>
                    </div>
                  </div>

                  <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10">
                    <h4 className="font-semibold text-white mb-2">Settle Intent</h4>
                    <p className="text-sm text-gray-400 mb-3">
                      Solver calls IntentHandler.settleIntent()
                    </p>
                    <div className="text-xs text-gray-500 space-y-1">
                      <div>• After term completion</div>
                      <div>• Keeps bond intact</div>
                      <div>• Releases escrowed yield</div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Management Actions */}
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-white mb-3">⚙️ Management Actions</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10">
                    <h4 className="font-semibold text-white mb-2">Resign Intent</h4>
                    <p className="text-sm text-gray-400 mb-3">Early termination options</p>
                    <div className="text-xs text-gray-500 space-y-1">
                      <div>• User resign: before solving</div>
                      <div>• Solver resign: 50% bond penalty</div>
                      <div>• Returns escrowed yield</div>
                    </div>
                  </div>

                  <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10">
                    <h4 className="font-semibold text-white mb-2">Bond Management</h4>
                    <p className="text-sm text-gray-400 mb-3">Solver bond operations</p>
                    <div className="text-xs text-gray-500 space-y-1">
                      <div>• Add/remove bond amounts</div>
                      <div>• Check voucher status</div>
                      <div>• Bond slashing on failure</div>
                    </div>
                  </div>

                  <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10">
                    <h4 className="font-semibold text-white mb-2">Role Management</h4>
                    <p className="text-sm text-gray-400 mb-3">Admin role assignments</p>
                    <div className="text-xs text-gray-500 space-y-1">
                      <div>• Grant/revoke solver role</div>
                      <div>• Grant/revoke ark role</div>
                      <div>• Grant/revoke liquidator role</div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Aave V3 Escrow Actions */}
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-white mb-3">🏦 Aave V3 Escrow Actions</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10">
                    <h4 className="font-semibold text-white mb-2">Asset Operations</h4>
                    <p className="text-sm text-gray-400 mb-3">Deposit & withdrawal</p>
                    <div className="text-xs text-gray-500 space-y-1">
                      <div>• deposit(): Supply to Aave V3</div>
                      <div>• withdraw(): Withdraw from Aave V3</div>
                      <div>• totalAssets(): Get aToken balance</div>
                    </div>
                  </div>

                  <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10">
                    <h4 className="font-semibold text-white mb-2">Reward Management</h4>
                    <p className="text-sm text-gray-400 mb-3">Claim and distribute rewards</p>
                    <div className="text-xs text-gray-500 space-y-1">
                      <div>• claimAllRewards(): Keeper only</div>
                      <div>• Transfers rewards to ark</div>
                      <div>• Supports multiple reward tokens</div>
                    </div>
                  </div>

                  <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10">
                    <h4 className="font-semibold text-white mb-2">Yield Management</h4>
                    <p className="text-sm text-gray-400 mb-3">Escrowed yield handling</p>
                    <div className="text-xs text-gray-500 space-y-1">
                      <div>• returnEscrowedYield(): Return to solver</div>
                      <div>• Only callable by IntentHandler</div>
                      <div>• Handles early termination</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Solver Information */}
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">Solver Information</h2>
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {solverInfo ? (
                  <SolverInfo
                    solverAddress={solverInfo.address}
                    totalAssets={`${formatEther(solverInfo.totalAssets)} USDC`}
                    bondAmount={`${formatEther(solverInfo.bondAmount)} SUMMER`}
                    isVouched={solverInfo.isVouched}
                    chainId={selectedChain}
                  />
                ) : (
                  <div className="bg-charcoal-800/50 p-6 rounded-xl border border-white/10">
                    <div className="text-center">
                      <div className="w-16 h-16 bg-gray-700 rounded-full flex items-center justify-center mx-auto mb-4">
                        <span className="text-2xl">👤</span>
                      </div>
                      <h3 className="text-lg font-semibold text-white mb-2">No Solver Active</h3>
                      <p className="text-gray-400 mb-4">
                        No solver has been assigned to the current intent yet.
                      </p>
                      <button
                        onClick={() => setShowCreateBond(true)}
                        className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white text-sm rounded transition-colors"
                      >
                        Create Solver Bond
                      </button>
                    </div>
                  </div>
                )}
                <div className="bg-charcoal-800/50 p-6 rounded-xl border border-white/10">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-10 h-10 bg-blue-600 rounded-lg flex items-center justify-center">
                      <span className="text-white font-bold text-lg">📈</span>
                    </div>
                    <div>
                      <h3 className="text-lg font-semibold text-white">Performance Metrics</h3>
                      <p className="text-sm text-gray-400">Solver performance overview</p>
                    </div>
                  </div>
                  <div className="space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                      <div className="bg-charcoal-700/50 p-3 rounded-lg text-center">
                        <div className="text-2xl font-bold text-green-400">12</div>
                        <div className="text-sm text-gray-400">Intents Solved</div>
                      </div>
                      <div className="bg-charcoal-700/50 p-3 rounded-lg text-center">
                        <div className="text-2xl font-bold text-blue-400">98.5%</div>
                        <div className="text-sm text-gray-400">Success Rate</div>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <div className="bg-charcoal-700/50 p-3 rounded-lg text-center">
                        <div className="text-2xl font-bold text-purple-400">$2.1M</div>
                        <div className="text-sm text-gray-400">Total Volume</div>
                      </div>
                      <div className="bg-charcoal-700/50 p-3 rounded-lg text-center">
                        <div className="text-2xl font-bold text-yellow-400">45 days</div>
                        <div className="text-sm text-gray-400">Avg Term</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Quick Actions */}
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">Quick Actions</h2>
              <div className="flex flex-wrap gap-4">
                <button
                  onClick={() => setShowCreateIntent(true)}
                  className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
                >
                  📝 Create Intent
                </button>
                <button
                  onClick={() => setShowSolveIntent(true)}
                  className="px-6 py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg font-semibold transition-colors"
                >
                  🔍 Solve Intent
                </button>
                <button
                  onClick={() => setShowCreateBond(true)}
                  className="px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg font-semibold transition-colors"
                >
                  🏦 Create Bond
                </button>
                <button
                  onClick={() => setShowAdmin(true)}
                  className="px-6 py-3 bg-orange-600 hover:bg-orange-700 text-white rounded-lg font-semibold transition-colors"
                >
                  ⚙️ Admin Functions
                </button>
                <button className="px-6 py-3 bg-cyan-600 hover:bg-cyan-700 text-white rounded-lg font-semibold transition-colors">
                  📊 View Statistics
                </button>
                <button className="px-6 py-3 bg-yellow-600 hover:bg-yellow-700 text-white rounded-lg font-semibold transition-colors">
                  🔮 Oracle Status
                </button>
              </div>
            </div>

            {/* System Status Overview */}
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">System Status Overview</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10 text-center">
                  <div className="text-2xl mb-2">🏭</div>
                  <div className="text-lg font-semibold text-white">Bond Factory</div>
                  <div className="text-sm text-green-400">✓ Active</div>
                  <div className="text-xs text-gray-400 mt-1">Ready for bonds</div>
                </div>

                <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10 text-center">
                  <div className="text-2xl mb-2">⚡</div>
                  <div className="text-lg font-semibold text-white">Intent Handler</div>
                  <div className="text-sm text-green-400">✓ Active</div>
                  <div className="text-xs text-gray-400 mt-1">Ready for intents</div>
                </div>

                <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10 text-center">
                  <div className="text-2xl mb-2">🚢</div>
                  <div className="text-lg font-semibold text-white">Generic Ark</div>
                  <div className="text-sm text-green-400">✓ Active</div>
                  <div className="text-xs text-gray-400 mt-1">Ready for posting</div>
                </div>

                <div className="bg-charcoal-800/50 p-4 rounded-lg border border-white/10 text-center">
                  <div className="text-2xl mb-2">🏦</div>
                  <div className="text-lg font-semibold text-white">Aave Escrow</div>
                  <div className="text-sm text-green-400">✓ Active</div>
                  <div className="text-xs text-gray-400 mt-1">Ready for operations</div>
                </div>
              </div>
            </div>
          </>
        )}

        {/* Not Deployed Message */}
        {!isDeployed && (
          <div className="text-center py-16">
            <div className="w-24 h-24 bg-gray-700 rounded-full flex items-center justify-center mx-auto mb-6">
              <span className="text-4xl">🚫</span>
            </div>
            <h3 className="text-xl font-semibold text-white mb-2">Intent System Not Deployed</h3>
            <p className="text-gray-400 mb-6">
              The Intent System contracts have not been deployed on {getChainName()} yet.
            </p>
            <div className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 max-w-md mx-auto">
              <h4 className="font-semibold text-white mb-3">To deploy:</h4>
              <ol className="text-sm text-gray-300 space-y-2 text-left">
                <li>1. Use the deployment scripts in core-contracts</li>
                <li>2. Update the configuration files</li>
                <li>3. Verify contracts on the blockchain</li>
                <li>4. Configure initial parameters</li>
              </ol>
            </div>
          </div>
        )}

        {/* Modals */}
        <CreateIntentModal
          isOpen={showCreateIntent}
          onClose={() => setShowCreateIntent(false)}
          environment={environment}
          chainId={selectedChain}
        />

        <SolveIntentModal
          isOpen={showSolveIntent}
          onClose={() => setShowSolveIntent(false)}
          environment={environment}
          chainId={selectedChain}
        />

        <CreateBondModal
          isOpen={showCreateBond}
          onClose={() => setShowCreateBond(false)}
          environment={environment}
          chainId={selectedChain}
        />

        <AdminModal
          isOpen={showAdmin}
          onClose={() => setShowAdmin(false)}
          environment={environment}
          chainId={selectedChain}
        />
      </div>
    </main>
  )
}
