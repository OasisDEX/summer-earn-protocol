'use client'

import { useEffect, useState } from 'react'
import { formatEther, formatUnits } from 'viem'
import { useAccount } from 'wagmi'

import { ChainSelector } from '../../components/ChainSelector'
import { CreateBondModal } from '../../components/modals/CreateBondModal'
import { CreateIntentModal } from '../../components/modals/CreateIntentModal'
import { SetPriceModal } from '../../components/modals/SetPriceModal'
import { SolveIntentModal } from '../../components/modals/SolveIntentModal'
import {
  AddressDisplay,
  Badge,
  Button,
  EmptyState,
  ErrorState,
  PageHeader,
  SectionHeader,
  Table,
  TableContainer,
  TBody,
  Td,
  Th,
  THead,
  Tr,
} from '../../components/ui'
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
    <div className="min-h-screen p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header Section */}
        <div className="mb-8">
          <a
            href="/"
            className="inline-flex items-center gap-1 text-sm text-on-surface-variant hover:text-on-surface transition-colors mb-4"
          >
            ← Back to Home
          </a>

          <PageHeader
            title="Intent System Configuration"
            description={`Monitor and manage the deployed Intent System contracts on ${getChainName()}`}
          />

          <div className="glass p-6 rounded-xl shadow-card">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <ChainSelector selectedChain={selectedChain} onChange={setSelectedChain} />
            </div>
          </div>
        </div>

        {/* Deployment Status */}
        <div className="mb-8">
          {isDeployed ? (
            <div className="p-4 rounded-lg border bg-success/15 border-success/25 text-success">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-success" />
                <span className="font-semibold">Intent System Deployed</span>
              </div>
              <p className="mt-2 text-sm opacity-80">
                All core contracts are deployed and operational on {getChainName()}
              </p>
            </div>
          ) : (
            <ErrorState
              title="Intent System Not Deployed"
              description={`No Intent System contracts found on ${getChainName()}`}
            />
          )}
        </div>

        {/* Real Data - Intent Events */}
        {isDeployed && (
          <div className="mb-8">
            <SectionHeader
              title="Live Intent Events"
              actions={
                <Button onClick={fetchIntentEvents} disabled={eventsLoading} variant="primary">
                  {eventsLoading ? 'Loading...' : 'Refresh Events'}
                </Button>
              }
            />

            {eventsLoading ? (
              <div className="bg-surface-container-high border border-white/10 p-8 rounded-xl text-center">
                <div className="animate-spin w-8 h-8 border-2 border-primary border-t-transparent rounded-full mx-auto mb-4"></div>
                <p className="text-on-surface-variant">Loading intent events...</p>
              </div>
            ) : intentEvents && intentEvents.length > 0 ? (
              <TableContainer>
                <Table>
                  <THead className="bg-white/5">
                    <Tr>
                      <Th>Time</Th>
                      <Th>Intent ID</Th>
                      <Th>User</Th>
                      <Th>Solver</Th>
                      <Th>Status</Th>
                      <Th numeric>Notional</Th>
                      <Th numeric>Bond</Th>
                      <Th numeric>Term</Th>
                      <Th>Actions</Th>
                    </Tr>
                  </THead>
                  <TBody>
                    {formatIntentEvents().map((event, index) => (
                      <Tr key={index} hover>
                        <Td className="text-on-surface-variant whitespace-nowrap">
                          {event.formattedTime}
                        </Td>
                        <Td className="font-mono text-info">{event.shortIntentId}</Td>
                        <Td className="font-mono text-on-surface-variant">{event.shortUser}</Td>
                        <Td className="font-mono text-on-surface-variant">{event.shortSolver}</Td>
                        <Td>
                          <Badge
                            tone={
                              event.state === 'Settled'
                                ? 'success'
                                : event.state === 'Solved'
                                  ? 'info'
                                  : event.state === 'Created'
                                    ? 'warning'
                                    : 'neutral'
                            }
                          >
                            {event.state}
                          </Badge>
                        </Td>
                        <Td numeric className="text-on-surface-variant">
                          {event.requiredNotionalFormatted}
                        </Td>
                        <Td numeric className="text-on-surface-variant">
                          {event.requiredBondFormatted}
                        </Td>
                        <Td numeric className="text-on-surface-variant">
                          {event.termDays}
                        </Td>
                        <Td>
                          {event.state === 'Created' && (
                            <button
                              onClick={() => openSolveModal(event)}
                              className="px-3 py-1 bg-secondary/15 border border-secondary/30 text-secondary hover:bg-secondary/25 text-xs rounded-lg transition-colors"
                            >
                              Solve
                            </button>
                          )}
                        </Td>
                      </Tr>
                    ))}
                  </TBody>
                </Table>
              </TableContainer>
            ) : (
              <EmptyState
                title="No intent events found in recent blocks"
                action={
                  <Button onClick={fetchIntentEvents} variant="primary">
                    Refresh Events
                  </Button>
                }
              />
            )}
          </div>
        )}

        {/* My Solver Bond - Actionable Content */}
        {isConnected && userAddress && (
          <div className="mb-8">
            <SectionHeader title="My Solver Bond" />
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className="bg-surface-container-high border border-white/10 p-6 rounded-xl">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-white/5 border border-white/10 rounded-lg flex items-center justify-center">
                    <span className="text-lg">🏦</span>
                  </div>
                  <div>
                    <h3 className="text-lg font-headline font-semibold text-on-surface">
                      Bond Status
                    </h3>
                    <p className="text-sm text-on-surface-variant">Your solver bond information</p>
                  </div>
                </div>
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="bg-white/5 border border-white/10 p-3 rounded-lg text-center">
                      <div className="text-2xl font-bold text-primary tabular-nums">
                        {formatEther(bondAmount)} SUMMER
                      </div>
                      <div className="text-sm text-on-surface-variant">Bond Amount</div>
                    </div>
                    <div className="bg-white/5 border border-white/10 p-3 rounded-lg text-center">
                      <div
                        className={`text-2xl font-bold ${
                          solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                            ? 'text-success'
                            : 'text-error'
                        }`}
                      >
                        {solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                          ? 'Yes'
                          : 'No'}
                      </div>
                      <div className="text-sm text-on-surface-variant">Voucher Status</div>
                    </div>
                  </div>
                  <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
                    <div className="text-sm text-on-surface-variant mb-2">Wallet Address:</div>
                    <AddressDisplay value={userAddress} full className="text-sm" />
                  </div>

                  <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
                    <div className="text-sm text-on-surface-variant mb-2">Fund Bond:</div>
                    <div className="flex gap-2">
                      <button
                        onClick={() => fundBond(BigInt(1000) * BigInt(10 ** 18))} // 1000 SUMMER
                        className="px-3 py-1 bg-secondary/15 border border-secondary/30 text-secondary hover:bg-secondary/25 text-xs rounded-lg transition-colors"
                      >
                        +1000 SUMMER
                      </button>
                      <button
                        onClick={() => fundBond(BigInt(500) * BigInt(10 ** 18))} // 500 SUMMER
                        className="px-3 py-1 bg-secondary/15 border border-secondary/30 text-secondary hover:bg-secondary/25 text-xs rounded-lg transition-colors"
                      >
                        +500 SUMMER
                      </button>
                      <button
                        onClick={() => fundBond(BigInt(100) * BigInt(10 ** 18))} // 100 SUMMER
                        className="px-3 py-1 bg-secondary/15 border border-secondary/30 text-secondary hover:bg-secondary/25 text-xs rounded-lg transition-colors"
                      >
                        +100 SUMMER
                      </button>
                    </div>
                  </div>

                  <div className="flex gap-2">
                    <Button
                      onClick={() => setShowCreateBond(true)}
                      variant="primary"
                      className="flex-1"
                    >
                      {bondAmount > BigInt(0) ? 'Add to Bond' : 'Create Bond'}
                    </Button>
                    <button
                      onClick={() => copyToClipboard(userAddress)}
                      className={`px-4 py-2 text-sm rounded-lg transition-colors ${
                        copiedAddress === userAddress
                          ? 'bg-success/15 border border-success/30 text-success'
                          : 'bg-white/5 border border-white/10 text-on-surface hover:bg-white/10'
                      }`}
                    >
                      {copiedAddress === userAddress ? 'Copied!' : 'Copy Address'}
                    </button>
                  </div>
                </div>
              </div>

              <div className="bg-surface-container-high border border-white/10 p-6 rounded-xl">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-white/5 border border-white/10 rounded-lg flex items-center justify-center">
                    <span className="text-lg">📊</span>
                  </div>
                  <div>
                    <h3 className="text-lg font-headline font-semibold text-on-surface">
                      Bond Requirements
                    </h3>
                    <p className="text-sm text-on-surface-variant">
                      Minimum requirements to be a solver
                    </p>
                  </div>
                </div>
                <div className="space-y-4">
                  <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-on-surface-variant">Minimum Bond:</span>
                      <span className="font-semibold text-on-surface tabular-nums">
                        1,000 SUMMER
                      </span>
                    </div>
                  </div>
                  <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-on-surface-variant">Voucher Status:</span>
                      <span
                        className={`font-semibold ${
                          solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                            ? 'text-success'
                            : 'text-error'
                        }`}
                      >
                        {solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                          ? 'Active'
                          : 'Inactive'}
                      </span>
                    </div>
                  </div>
                  <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-on-surface-variant">Can Solve Intents:</span>
                      <span
                        className={`font-semibold ${
                          solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                            ? 'text-success'
                            : 'text-error'
                        }`}
                      >
                        {solverInfo && solverInfo.address === userAddress && solverInfo.isVouched
                          ? 'Yes'
                          : 'No'}
                      </span>
                    </div>
                  </div>
                  <div className="text-xs text-on-surface-variant space-y-1">
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
          <SectionHeader title="Quick Actions" />
          <div className="flex flex-wrap gap-4">
            <Button onClick={() => setShowCreateIntent(true)} variant="primary" size="lg">
              Create Intent
            </Button>
            <Button onClick={() => setShowSolveIntent(true)} variant="secondary" size="lg">
              Solve Intent
            </Button>
            <Button onClick={() => setShowCreateBond(true)} variant="secondary" size="lg">
              Create Bond
            </Button>
            <Button onClick={() => setShowSetPrice(true)} variant="secondary" size="lg">
              Set Price
            </Button>
          </div>
        </div>

        {/* Not Deployed Message */}
        {!isDeployed && (
          <EmptyState
            icon="🚫"
            title="Intent System Not Deployed"
            description={`The Intent System contracts have not been deployed on ${getChainName()} yet.`}
            action={
              <div className="w-full max-w-md rounded-xl border border-white/10 bg-white/[0.02] p-6 text-left">
                <h4 className="font-semibold text-on-surface mb-3">To deploy:</h4>
                <ol className="text-sm text-on-surface-variant space-y-2">
                  <li>1. Use the deployment scripts in core-contracts</li>
                  <li>2. Update the configuration files</li>
                  <li>3. Verify contracts on the blockchain</li>
                  <li>4. Configure initial parameters</li>
                </ol>
              </div>
            }
          />
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
