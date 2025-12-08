'use client'

import { useEffect, useState } from 'react'
import { formatEther, formatUnits } from 'viem'
import { useAccount } from 'wagmi'

import { ChainSelector } from '../../components/ChainSelector'
import { CreateBondModal } from '../../components/modals/CreateBondModal'
import { CreateIntentModal } from '../../components/modals/CreateIntentModal'
import { SetPriceModal } from '../../components/modals/SetPriceModal'
import { SolveIntentModal } from '../../components/modals/SolveIntentModal'
import { useEnvironment } from '../../hooks/useEnvironment'
import type { IntentEvent } from '../../hooks/useIntentSystem'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import { useLocalStorage } from '../../hooks/useLocalStorage'
import { useSyncWalletChain } from '../../hooks/useSyncWalletChain'
import type { ChainId } from '../../types'

type PrefilledIntentData = {
  intentId: string
  user: string
  requiredNotional: bigint
  requiredBond: bigint
  term: bigint
  targetYield: bigint
  token: string
  oracle: string
  expiry: bigint
}

type FormattedIntentEvent = IntentEvent & {
  formattedTime: string
  shortUser: string
  shortSolver: string
  shortIntentId: string
  termDays: string
  requiredNotionalFormatted: string
  requiredBondFormatted: string
  targetYieldFormatted: string
}

const DEFAULT_ORACLE_ADDRESS = '0x0000000000000000000000000000000000000000'

export default function IntentSystemPage() {
  const [storedChain, setStoredChain] = useLocalStorage<ChainId>('selectedChain', '8453')
  const [selectedChain, setSelectedChain] = useState<ChainId>(storedChain)
  const { environment } = useEnvironment()
  const { address: userAddress, isConnected } = useAccount()

  // Modal states
  const [showCreateIntent, setShowCreateIntent] = useState(false)
  const [showSolveIntent, setShowSolveIntent] = useState(false)
  const [showCreateBond, setShowCreateBond] = useState(false)
  const [showSetPrice, setShowSetPrice] = useState(false)
  const [selectedIntentForSolving, setSelectedIntentForSolving] =
    useState<PrefilledIntentData | null>(null)

  useSyncWalletChain(selectedChain)

  useEffect(() => {
    setStoredChain(selectedChain)
  }, [selectedChain, setStoredChain])

  const {
    isDeployed,
    intentHandler,
    intentEvents,
    eventsLoading,
    fetchIntentEvents,
    solverInfo,
    intentBondFactory,
    getSolverBondAmount,
    addBond,
    refreshSolverInfo,
  } = useIntentSystem(environment, selectedChain)

  // Bond state
  const [bondAmount, setBondAmount] = useState<bigint>(BigInt(0))
  const [copiedAddress, setCopiedAddress] = useState<string | null>(null)

  // Helper functions
  const copyToClipboard = async (address: string) => {
    try {
      await navigator.clipboard.writeText(address)
      setCopiedAddress(address)
      setTimeout(() => setCopiedAddress(null), 2000)
    } catch (err) {
      console.error('Failed to copy address:', err)
    }
  }

  // Fetch bond information when user connects or chain changes
  useEffect(() => {
    const fetchBondInfo = async () => {
      if (userAddress && isDeployed && intentBondFactory) {
        try {
          const amount = await getSolverBondAmount(userAddress)
          setBondAmount(amount)

          // Bond contracts are abstracted for now; updating amount is sufficient in UI
        } catch (error) {
          console.error('Error fetching bond info:', error)
        }
      }
    }

    const timer = setTimeout(() => {
      fetchBondInfo()
    }, 100)

    return () => clearTimeout(timer)
  }, [userAddress, isDeployed, intentBondFactory, selectedChain, getSolverBondAmount])

  // Update bond info when solverInfo changes
  useEffect(() => {
    if (solverInfo && userAddress && solverInfo.address === userAddress) {
      setBondAmount(solverInfo.bondAmount)
    }
  }, [solverInfo, userAddress])

  // Function to fund the bond
  const fundBond = async (amount: bigint) => {
    if (!userAddress) return

    try {
      const hash = await addBond(userAddress, amount)
      if (hash) {
        console.log('Bond funded successfully:', hash)
        setTimeout(async () => {
          refreshSolverInfo()
          const newAmount = await getSolverBondAmount(userAddress)
          setBondAmount(newAmount)
        }, 5000)
      }
    } catch (error) {
      console.error('Error funding bond:', error)
    }
  }

  // Function to open solve modal with prefilled intent data
  const openSolveModal = (event: FormattedIntentEvent) => {
    const prefilledData: PrefilledIntentData = {
      intentId: event.intentId,
      user: event.user,
      requiredNotional: event.requiredNotional,
      requiredBond: event.requiredBond,
      term: event.term,
      targetYield: event.targetYield,
      token: event.token,
      oracle: DEFAULT_ORACLE_ADDRESS,
      expiry: event.expiry,
    }

    setSelectedIntentForSolving(prefilledData)
    setShowSolveIntent(true)
  }

  // Fetch intent events
  useEffect(() => {
    if (isDeployed && intentHandler) {
      fetchIntentEvents()
    }
  }, [isDeployed, intentHandler, selectedChain, fetchIntentEvents])

  // Helper function to format intent events for display
  const formatIntentEvents = (): FormattedIntentEvent[] => {
    if (!intentEvents || intentEvents.length === 0) {
      return []
    }

    return intentEvents.map((event) => ({
      ...event,
      formattedTime: new Date(event.timestamp * 1000).toLocaleString(),
      shortUser: `${event.user.slice(0, 6)}...${event.user.slice(-4)}`,
      shortSolver: event.solver ? `${event.solver.slice(0, 6)}...${event.solver.slice(-4)}` : 'N/A',
      shortIntentId: `${event.intentId.slice(0, 10)}...`,
      termDays: event.term > BigInt(0) ? `${Number(event.term) / 86400} days` : 'N/A',
      requiredNotionalFormatted:
        event.requiredNotional > BigInt(0)
          ? formatAmount(event.requiredNotional, event.token)
          : 'N/A',
      requiredBondFormatted:
        event.requiredBond > BigInt(0) ? formatEther(event.requiredBond) : 'N/A',
      targetYieldFormatted: event.targetYield > BigInt(0) ? formatEther(event.targetYield) : 'N/A',
    }))
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

  // Token decimals mapping - common tokens and their decimals
  const TOKEN_DECIMALS: Record<string, number> = {
    '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913': 6, // USDC on Base
    '0x932CCb7D2A6F1821a1Ecee9e1279aC30E0d4db32': 18, // SUMMER on Base
  }

  // Function to get token decimals, defaulting to 18 if unknown
  const getTokenDecimals = (tokenAddress: string): number => {
    return TOKEN_DECIMALS[tokenAddress.toLowerCase()] ?? 18
  }

  // Function to format amount based on token decimals
  const formatAmount = (amount: bigint, tokenAddress: string): string => {
    if (amount === BigInt(0)) return '0'
    const decimals = getTokenDecimals(tokenAddress)
    try {
      return formatUnits(amount, decimals)
    } catch (error) {
      console.error('Error formatting amount:', error)
      return amount.toString()
    }
  }

  return (
    <div className="min-h-screen bg-gray-900 p-8">
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

          <div className="bg-gray-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
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

        {/* Real Data - Intent Events */}
        {isDeployed && (
          <div className="mb-8">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold text-white">Live Intent Events</h2>
              <button
                onClick={fetchIntentEvents}
                disabled={eventsLoading}
                className="px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white text-sm rounded transition-colors"
              >
                {eventsLoading ? 'Loading...' : 'Refresh Events'}
              </button>
            </div>

            {eventsLoading ? (
              <div className="bg-gray-800/50 p-8 rounded-xl border border-white/10 text-center">
                <div className="animate-spin w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full mx-auto mb-4"></div>
                <p className="text-gray-400">Loading intent events...</p>
              </div>
            ) : intentEvents && intentEvents.length > 0 ? (
              <div className="bg-gray-800/50 rounded-xl border border-white/10 overflow-hidden">
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className="bg-gray-700/50">
                      <tr>
                        <th className="px-4 py-3 text-left text-gray-300">Time</th>
                        <th className="px-4 py-3 text-left text-gray-300">Intent ID</th>
                        <th className="px-4 py-3 text-left text-gray-300">User</th>
                        <th className="px-4 py-3 text-left text-gray-300">Solver</th>
                        <th className="px-4 py-3 text-left text-gray-300">Status</th>
                        <th className="px-4 py-3 text-left text-gray-300">Notional</th>
                        <th className="px-4 py-3 text-left text-gray-300">Bond</th>
                        <th className="px-4 py-3 text-left text-gray-300">Term</th>
                        <th className="px-4 py-3 text-left text-gray-300">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {formatIntentEvents().map((event, index) => (
                        <tr key={index} className="border-t border-white/5 hover:bg-white/5">
                          <td className="px-4 py-3 text-gray-300">{event.formattedTime}</td>
                          <td className="px-4 py-3 font-mono text-blue-400">
                            {event.shortIntentId}
                          </td>
                          <td className="px-4 py-3 font-mono text-purple-400">{event.shortUser}</td>
                          <td className="px-4 py-3 font-mono text-green-400">
                            {event.shortSolver}
                          </td>
                          <td className="px-4 py-3">
                            <span
                              className={`px-2 py-1 rounded text-xs ${
                                event.state === 'Settled'
                                  ? 'bg-green-600 text-white'
                                  : event.state === 'Solved'
                                    ? 'bg-blue-600 text-white'
                                    : event.state === 'Created'
                                      ? 'bg-yellow-600 text-white'
                                      : 'bg-gray-600 text-white'
                              }`}
                            >
                              {event.state}
                            </span>
                          </td>
                          <td className="px-4 py-3 text-gray-300">
                            {event.requiredNotionalFormatted}
                          </td>
                          <td className="px-4 py-3 text-gray-300">{event.requiredBondFormatted}</td>
                          <td className="px-4 py-3 text-gray-300">{event.termDays}</td>
                          <td className="px-4 py-3">
                            {event.state === 'Created' && (
                              <button
                                onClick={() => openSolveModal(event)}
                                className="px-3 py-1 bg-green-600 hover:bg-green-700 text-white text-xs rounded transition-colors"
                              >
                                Solve
                              </button>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            ) : (
              <div className="bg-gray-800/50 p-8 rounded-xl border border-white/10 text-center">
                <p className="text-gray-400 mb-4">No intent events found in recent blocks</p>
                <button
                  onClick={fetchIntentEvents}
                  className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm rounded transition-colors"
                >
                  Refresh Events
                </button>
              </div>
            )}
          </div>
        )}

        {/* My Solver Bond - Actionable Content */}
        {isConnected && userAddress && (
          <div className="mb-8">
            <h2 className="text-xl font-semibold text-white mb-4">My Solver Bond</h2>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className="bg-gray-800/50 p-6 rounded-xl border border-white/10">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-purple-600 rounded-lg flex items-center justify-center">
                    <span className="text-white font-bold text-lg">🏦</span>
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-white">Bond Status</h3>
                    <p className="text-sm text-gray-400">Your solver bond information</p>
                  </div>
                </div>
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="bg-gray-700/50 p-3 rounded-lg text-center">
                      <div className="text-2xl font-bold text-purple-400">
                        {formatEther(bondAmount)} SUMMER
                      </div>
                      <div className="text-sm text-gray-400">Bond Amount</div>
                    </div>
                    <div className="bg-gray-700/50 p-3 rounded-lg text-center">
                      <div
                        className={`text-2xl font-bold ${
                          solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                            ? 'text-green-400'
                            : 'text-red-400'
                        }`}
                      >
                        {solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                          ? 'Yes'
                          : 'No'}
                      </div>
                      <div className="text-sm text-gray-400">Voucher Status</div>
                    </div>
                  </div>
                  <div className="bg-gray-700/50 p-3 rounded-lg">
                    <div className="text-sm text-gray-400 mb-2">Wallet Address:</div>
                    <div className="font-mono text-sm break-all">{userAddress}</div>
                  </div>

                  <div className="bg-gray-700/50 p-3 rounded-lg">
                    <div className="text-sm text-gray-400 mb-2">Fund Bond:</div>
                    <div className="flex gap-2">
                      <button
                        onClick={() => fundBond(BigInt(1000) * BigInt(10 ** 18))} // 1000 SUMMER
                        className="px-3 py-1 bg-green-600 hover:bg-green-700 text-white text-xs rounded transition-colors"
                      >
                        +1000 SUMMER
                      </button>
                      <button
                        onClick={() => fundBond(BigInt(500) * BigInt(10 ** 18))} // 500 SUMMER
                        className="px-3 py-1 bg-green-600 hover:bg-green-700 text-white text-xs rounded transition-colors"
                      >
                        +500 SUMMER
                      </button>
                      <button
                        onClick={() => fundBond(BigInt(100) * BigInt(10 ** 18))} // 100 SUMMER
                        className="px-3 py-1 bg-green-600 hover:bg-green-700 text-white text-xs rounded transition-colors"
                      >
                        +100 SUMMER
                      </button>
                    </div>
                  </div>

                  <div className="flex gap-2">
                    <button
                      onClick={() => setShowCreateBond(true)}
                      className="flex-1 px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white text-sm rounded transition-colors"
                    >
                      {bondAmount > BigInt(0) ? 'Add to Bond' : 'Create Bond'}
                    </button>
                    <button
                      onClick={() => copyToClipboard(userAddress)}
                      className={`px-4 py-2 text-sm rounded transition-colors ${
                        copiedAddress === userAddress
                          ? 'bg-green-600 text-white'
                          : 'bg-gray-600 hover:bg-gray-700 text-white'
                      }`}
                    >
                      {copiedAddress === userAddress ? 'Copied!' : 'Copy Address'}
                    </button>
                  </div>
                </div>
              </div>

              <div className="bg-gray-800/50 p-6 rounded-xl border border-white/10">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-green-600 rounded-lg flex items-center justify-center">
                    <span className="text-white font-bold text-lg">📊</span>
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-white">Bond Requirements</h3>
                    <p className="text-sm text-gray-400">Minimum requirements to be a solver</p>
                  </div>
                </div>
                <div className="space-y-4">
                  <div className="bg-gray-700/50 p-3 rounded-lg">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Minimum Bond:</span>
                      <span className="font-semibold text-white">1,000 SUMMER</span>
                    </div>
                  </div>
                  <div className="bg-gray-700/50 p-3 rounded-lg">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Voucher Status:</span>
                      <span
                        className={`font-semibold ${
                          solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                            ? 'text-green-400'
                            : 'text-red-400'
                        }`}
                      >
                        {solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                          ? 'Active'
                          : 'Inactive'}
                      </span>
                    </div>
                  </div>
                  <div className="bg-gray-700/50 p-3 rounded-lg">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-400">Can Solve Intents:</span>
                      <span
                        className={`font-semibold ${
                          solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                            ? 'text-green-400'
                            : 'text-red-400'
                        }`}
                      >
                        {solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                          ? 'Yes'
                          : 'No'}
                      </span>
                    </div>
                  </div>
                  <div className="text-xs text-gray-400 space-y-1">
                    <div>• Bond must be at least 1,000 SUMMER</div>
                    <div>• Vouched solvers can solve intents</div>
                    <div>• Bond is locked while solving</div>
                    <div>• Early resignation: 50% penalty</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

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
              onClick={() => setShowSetPrice(true)}
              className="px-6 py-3 bg-yellow-600 hover:bg-yellow-700 text-white rounded-lg font-semibold transition-colors"
            >
              💰 Set Price
            </button>
          </div>
        </div>

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
            <div className="bg-gray-800/70 p-6 rounded-xl border border-white/10 max-w-md mx-auto">
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
          onClose={() => {
            setShowSolveIntent(false)
            setSelectedIntentForSolving(null)
          }}
          environment={environment}
          chainId={selectedChain}
          intentData={selectedIntentForSolving ?? undefined}
        />

        <CreateBondModal
          isOpen={showCreateBond}
          onClose={() => setShowCreateBond(false)}
          environment={environment}
          chainId={selectedChain}
        />

        <SetPriceModal
          isOpen={showSetPrice}
          onClose={() => setShowSetPrice(false)}
          environment={environment}
          chainId={selectedChain}
        />
      </div>
    </div>
  )
}
