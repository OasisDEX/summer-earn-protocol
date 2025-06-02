import { ethers } from 'ethers'
import React, { useEffect, useState } from 'react'
import { useAccount, useSwitchChain, useWriteContract } from 'wagmi'
import config from '../config/index.json'
import { CrossChainProposal, ProposalWithCrossChain, fetchAllProposals } from '../services/subgraph'
import { ProposalFilter, ProposalStatus } from './ProposalFilter'

// Timelock Controller ABI for executeBatch
const TIMELOCK_ABI = [
  {
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'payloads', type: 'bytes[]' },
      { name: 'predecessor', type: 'bytes32' },
      { name: 'salt', type: 'bytes32' },
    ],
    name: 'executeBatch',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
] as const

// Governor ABI for execute
const GOVERNOR_ABI = [
  {
    inputs: [{ name: 'proposalId', type: 'uint256' }],
    name: 'execute',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'descriptionHash', type: 'bytes32' },
    ],
    name: 'queue',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const

// Chain ID to network name mapping
const CHAIN_ID_TO_NETWORK: Record<string, keyof typeof config> = {
  '1': 'mainnet',
  '8453': 'base',
  '42161': 'arbitrum',
  '146': 'sonic',
}

export const CrossChainProposals: React.FC = () => {
  const [proposals, setProposals] = useState<ProposalWithCrossChain[]>([])
  const [filteredProposals, setFilteredProposals] = useState<ProposalWithCrossChain[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [executingProposals, setExecutingProposals] = useState<Set<string>>(new Set())
  const [selectedStatuses, setSelectedStatuses] = useState<ProposalStatus[]>([
    'Pending',
    'Queued',
    'Ready',
    'Executed',
  ])

  const { address, isConnected, chainId } = useAccount()
  const { writeContract, isPending, error: writeContractError } = useWriteContract()
  const { switchChain } = useSwitchChain()

  const handleExecuteProposal = async (proposal: CrossChainProposal) => {
    if (!isConnected || !address) {
      alert('Please connect your wallet first')
      return
    }

    const proposalChainId = parseInt(proposal.chainId)
    const networkName = CHAIN_ID_TO_NETWORK[proposal.chainId]

    if (!networkName) {
      alert(`Unsupported chain ID: ${proposal.chainId}`)
      return
    }

    // Get timelock address from config
    const timelockAddress = config[networkName]?.deployedContracts?.gov?.timelock?.address
    if (!timelockAddress) {
      alert(`Timelock address not found for chain ${networkName}`)
      return
    }

    try {
      setExecutingProposals((prev) => new Set(prev).add(proposal.id))

      // Switch chain if needed
      if (chainId !== proposalChainId) {
        await switchChain({ chainId: proposalChainId })
      }

      // Convert values from string to bigint
      const values = proposal.values.map((v) => BigInt(v))

      // Execute the proposal
      await writeContract({
        address: timelockAddress as `0x${string}`,
        abi: TIMELOCK_ABI,
        functionName: 'executeBatch',
        args: [
          proposal.targets as `0x${string}`[],
          values,
          proposal.calldatas as `0x${string}`[],
          '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`, // predecessor
          proposal.salt as `0x${string}`,
        ],
      })

      console.log(`Successfully executed proposal ${proposal.id} on chain ${proposal.chainId}`)

      // Refresh proposals after execution
      setTimeout(() => {
        loadProposals()
      }, 2000)
    } catch (error) {
      console.error('Error executing proposal:', error)
      alert(
        `Failed to execute proposal: ${error instanceof Error ? error.message : 'Unknown error'}`,
      )
    } finally {
      setExecutingProposals((prev) => {
        const newSet = new Set(prev)
        newSet.delete(proposal.id)
        return newSet
      })
    }
  }

  const handleExecuteBaseProposal = async (proposalId: string) => {
    if (!isConnected || !address) {
      alert('Please connect your wallet first')
      return
    }

    const networkName = 'base'
    const governorAddress = config[networkName]?.deployedContracts?.gov?.summerGovernor?.address
    if (!governorAddress) {
      alert('Governor address not found for Base network')
      return
    }

    try {
      setExecutingProposals((prev) => new Set(prev).add(proposalId))

      // Switch to Base if needed
      if (chainId !== 8453) {
        await switchChain({ chainId: 8453 })
      }

      // Execute the proposal
      await writeContract({
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'execute',
        args: [BigInt(proposalId)],
      })

      console.log(`Successfully executed base proposal ${proposalId}`)

      // Refresh proposals after execution
      setTimeout(() => {
        loadProposals()
      }, 2000)
    } catch (error) {
      console.error('Error executing base proposal:', error)
      alert(
        `Failed to execute base proposal: ${error instanceof Error ? error.message : 'Unknown error'}`,
      )
    } finally {
      setExecutingProposals((prev) => {
        const newSet = new Set(prev)
        newSet.delete(proposalId)
        return newSet
      })
    }
  }

  const handleQueueBaseProposal = async (proposal: {
    id: string
    targets: string[]
    values: string[]
    calldatas: string[]
    description: string
  }) => {
    if (!isConnected || !address) {
      alert('Please connect your wallet first')
      return
    }

    const networkName = 'base'
    const governorAddress = config[networkName]?.deployedContracts?.gov?.summerGovernor?.address
    if (!governorAddress) {
      alert('Governor address not found for Base network')
      return
    }

    try {
      setExecutingProposals((prev) => new Set(prev).add(proposal.id))

      // Switch to Base if needed
      if (chainId !== 8453) {
        await switchChain({ chainId: 8453 })
      }

      // Create description hash
      const descriptionHash = ethers.keccak256(ethers.toUtf8Bytes(proposal.description))

      // Queue the proposal

      writeContract({
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'queue',
        args: [
          proposal.targets as `0x${string}`[],
          proposal.values.map((v) => BigInt(v)),
          proposal.calldatas as `0x${string}`[],
          descriptionHash as `0x${string}`,
        ],
      })

      // Refresh proposals after queueing
      setTimeout(() => {
        loadProposals()
      }, 2000)
    } catch (error) {
      console.error('Error queueing base proposal:', error)
      alert(
        `Failed to queue base proposal: ${error instanceof Error ? error.message : 'Unknown error'}`,
      )
    } finally {
      setExecutingProposals((prev) => {
        const newSet = new Set(prev)
        newSet.delete(proposal.id)
        return newSet
      })
    }
  }

  const loadProposals = async () => {
    try {
      const data = await fetchAllProposals()
      setProposals(data)
      filterProposals(data, selectedStatuses)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load proposals')
    } finally {
      setLoading(false)
    }
  }

  const getCrossChainProposalStatus = (proposal: CrossChainProposal): ProposalStatus => {
    if (proposal.status === 'Executed') return 'Executed'
    if (proposal.status === 'Pending') {
      const currentTimestamp = Math.floor(Date.now() / 1000)
      const eta = Number(proposal.eta)
      if (eta > 0 && currentTimestamp < eta) {
        return 'Queued'
      } else if (eta > 0 && currentTimestamp >= eta) {
        return 'Ready'
      }
    }
    return proposal.status as ProposalStatus
  }

  const filterProposals = (proposals: ProposalWithCrossChain[], statuses: ProposalStatus[]) => {
    const filtered = proposals.filter((proposal) => {
      // First check if the base proposal matches any selected status
      const baseStatus = proposal.baseProposal.status.toUpperCase()
      const baseStatusMatches = statuses.some((status) => {
        if (status === 'Queued' && baseStatus === 'QUEUED') return true
        if (status === 'Ready' && baseStatus === 'QUEUED') {
          const currentTimestamp = Math.floor(Date.now() / 1000)
          const eta = Number(proposal.baseProposal.eta)
          return eta > 0 && currentTimestamp >= eta
        }
        if (status === 'Executed' && baseStatus === 'EXECUTED') return true
        if (status === 'Active' && baseStatus === 'ACTIVE') return true
        if (status === 'Pending' && baseStatus === 'PENDING') return true
        return false
      })

      // If base proposal matches, include it regardless of cross-chain status
      if (baseStatusMatches) return true

      // Then check if any cross-chain proposal matches the selected statuses
      const crossChainStatusMatches = proposal.crossChainProposals.some((ccp) => {
        const ccpStatus = getCrossChainProposalStatus(ccp)
        return statuses.includes(ccpStatus)
      })

      return crossChainStatusMatches
    })

    setFilteredProposals(filtered)
  }

  useEffect(() => {
    loadProposals()
  }, [])

  useEffect(() => {
    filterProposals(proposals, selectedStatuses)
  }, [selectedStatuses])

  if (loading)
    return (
      <div className="flex justify-center items-center min-h-[200px]">
        <div className="animate-pulse flex flex-col items-center space-y-4">
          <div className="h-8 w-32 bg-gray-200 rounded"></div>
          <div className="h-4 w-24 bg-gray-200 rounded"></div>
        </div>
      </div>
    )
  if (error)
    return (
      <div className="text-red-500 p-6 border border-red-200 rounded-lg bg-red-50">
        <div className="flex items-center space-x-2">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <span>Error: {error}</span>
        </div>
      </div>
    )

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h2 className="text-3xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
          Cross-Chain Proposals
        </h2>
        <div className="text-sm text-gray-500">Total Proposals: {filteredProposals.length}</div>
      </div>

      <div className="space-y-4">
        <ProposalFilter selectedStatuses={selectedStatuses} onStatusChange={setSelectedStatuses} />
      </div>

      <div className="grid gap-6">
        {filteredProposals.map(({ baseProposal, crossChainProposals }) => {
          const baseStatus = baseProposal.status.toUpperCase()
          const isBaseQueued = baseStatus === 'Queued'
          const isBaseReady =
            isBaseQueued &&
            Number(baseProposal.eta) > 0 &&
            Math.floor(Date.now() / 1000) >= Number(baseProposal.eta)

          return (
            <div
              key={baseProposal.id}
              className="group border border-gray-200 rounded-xl p-6 space-y-4 bg-white shadow-sm hover:shadow-lg transition-all duration-300 ease-in-out"
            >
              <div className="space-y-4">
                <div className="flex justify-between items-start">
                  <div className="space-y-1">
                    <h3 className="text-xl font-semibold text-gray-900">
                      Proposal #{baseProposal.id}
                    </h3>
                    <p className="text-sm text-gray-500">
                      Created on{' '}
                      {new Date(Number(baseProposal.createdAt) * 1000).toLocaleDateString()}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span
                      className={`px-4 py-1.5 rounded-full text-sm font-medium transition-colors duration-200 ${
                        baseStatus === 'EXECUTED'
                          ? 'bg-green-100 text-green-800'
                          : isBaseReady
                            ? 'bg-orange-100 text-orange-800'
                            : isBaseQueued
                              ? 'bg-yellow-100 text-yellow-800'
                              : baseStatus === 'ACTIVE'
                                ? 'bg-blue-100 text-blue-800'
                                : 'bg-gray-100 text-gray-800'
                      }`}
                    >
                      {isBaseReady ? 'Ready' : baseStatus}
                    </span>
                    {baseStatus === 'PENDING' && (
                      <button
                        onClick={() => handleQueueBaseProposal(baseProposal)}
                        disabled={executingProposals.has(baseProposal.id) || isPending}
                        className={`px-4 py-1.5 text-white text-sm font-medium rounded-lg transition-colors duration-200 flex items-center space-x-2 ${
                          executingProposals.has(baseProposal.id) || isPending
                            ? 'bg-gray-400 cursor-not-allowed'
                            : 'bg-blue-600 hover:bg-blue-700'
                        }`}
                      >
                        {executingProposals.has(baseProposal.id) || isPending ? (
                          <>
                            <svg
                              className="w-4 h-4 animate-spin"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                              />
                            </svg>
                            <span>Queueing...</span>
                          </>
                        ) : (
                          <>
                            <svg
                              className="w-4 h-4"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M5 13l4 4L19 7"
                              />
                            </svg>
                            <span>Queue</span>
                          </>
                        )}
                      </button>
                    )}
                    {(isBaseReady || isBaseQueued) && (
                      <button
                        onClick={() => handleExecuteBaseProposal(baseProposal.id)}
                        disabled={executingProposals.has(baseProposal.id) || isPending}
                        className={`px-4 py-1.5 text-white text-sm font-medium rounded-lg transition-colors duration-200 flex items-center space-x-2 ${
                          executingProposals.has(baseProposal.id) || isPending
                            ? 'bg-gray-400 cursor-not-allowed'
                            : 'bg-blue-600 hover:bg-blue-700'
                        }`}
                      >
                        {executingProposals.has(baseProposal.id) || isPending ? (
                          <>
                            <svg
                              className="w-4 h-4 animate-spin"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                              />
                            </svg>
                            <span>Executing...</span>
                          </>
                        ) : (
                          <>
                            <svg
                              className="w-4 h-4"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                              />
                            </svg>
                            <span>Execute</span>
                          </>
                        )}
                      </button>
                    )}
                  </div>
                </div>
                <p className="text-gray-600 text-sm leading-relaxed bg-gray-50 p-4 rounded-lg">
                  {baseProposal.description.slice(0, 100)}
                  {baseProposal.description.length > 100 && '...'}
                </p>
                <div className="flex flex-wrap gap-3 text-sm">
                  <span className="px-4 py-2 bg-gray-50 rounded-full flex items-center space-x-2">
                    <svg
                      className="w-4 h-4 text-gray-500"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                    <span>
                      ETA:{' '}
                      {baseProposal.eta === '0'
                        ? 'Not queued'
                        : new Date(Number(baseProposal.eta) * 1000).toLocaleString()}
                    </span>
                  </span>
                  <span className="px-4 py-2 bg-gray-50 rounded-full flex items-center space-x-2">
                    <svg
                      className="w-4 h-4 text-gray-500"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M13 10V3L4 14h7v7l9-11h-7z"
                      />
                    </svg>
                    <span>Chains: {baseProposal.chains.join(', ')}</span>
                  </span>
                </div>
              </div>

              <div className="space-y-3 pt-4 border-t border-gray-100">
                <div className="flex items-center justify-between">
                  <h4 className="text-lg font-medium text-gray-700">Cross-Chain Proposals</h4>
                  <span className="text-sm text-gray-500">
                    {crossChainProposals.length} proposals
                  </span>
                </div>
                {crossChainProposals.length === 0 ? (
                  <div className="text-gray-500 italic bg-gray-50 p-4 rounded-lg text-center">
                    <p>No cross-chain proposals found</p>
                    {baseStatus === 'PENDING' || baseStatus === 'ACTIVE' ? (
                      <p className="text-sm mt-1">
                        Cross-chain proposals will be created after this proposal is executed
                      </p>
                    ) : baseStatus === 'QUEUED' || isBaseReady ? (
                      <p className="text-sm mt-1">
                        Cross-chain proposals will be created after this proposal is executed
                      </p>
                    ) : (
                      <p className="text-sm mt-1">
                        This proposal may not have cross-chain components
                      </p>
                    )}
                  </div>
                ) : (
                  <div className="grid gap-3">
                    {crossChainProposals.map((ccp) => {
                      const ccpStatus = getCrossChainProposalStatus(ccp)
                      const eta = Number(ccp.eta)
                      const currentTimestamp = Math.floor(Date.now() / 1000)
                      const timeUntilReady = eta > 0 ? eta - currentTimestamp : 0

                      return (
                        <div
                          key={ccp.id}
                          className="border-l-4 border-blue-500 pl-4 py-3 bg-blue-50 rounded-r-lg hover:bg-blue-100 transition-colors duration-200"
                        >
                          <div className="flex flex-wrap gap-3 items-center justify-between">
                            <div className="flex flex-wrap gap-3 items-center">
                              <span className="font-medium text-blue-900 flex items-center space-x-2">
                                <svg
                                  className="w-4 h-4"
                                  fill="none"
                                  stroke="currentColor"
                                  viewBox="0 0 24 24"
                                >
                                  <path
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                    strokeWidth={2}
                                    d="M13 10V3L4 14h7v7l9-11h-7z"
                                  />
                                </svg>
                                <span>Chain: {ccp.chainId}</span>
                              </span>
                              <span
                                className={`px-3 py-1 rounded-full text-sm ${
                                  ccpStatus === 'Executed'
                                    ? 'bg-green-100 text-green-800'
                                    : ccpStatus === 'Ready'
                                      ? 'bg-orange-100 text-orange-800'
                                      : ccpStatus === 'Queued'
                                        ? 'bg-yellow-100 text-yellow-800'
                                        : ccpStatus === 'Pending'
                                          ? 'bg-blue-100 text-blue-800'
                                          : 'bg-gray-100 text-gray-800'
                                }`}
                              >
                                {ccpStatus}
                              </span>
                              {eta > 0 && (
                                <div className="flex items-center space-x-2 text-sm">
                                  {ccpStatus === 'Queued' ? (
                                    <span className="text-yellow-700">
                                      Ready in: {Math.floor(timeUntilReady / 3600)}h{' '}
                                      {Math.floor((timeUntilReady % 3600) / 60)}m
                                    </span>
                                  ) : ccpStatus === 'Ready' ? (
                                    <span className="text-orange-700">
                                      Ready since: {new Date(eta * 1000).toLocaleString()}
                                    </span>
                                  ) : null}
                                </div>
                              )}
                            </div>
                            {(ccpStatus === 'Ready' || ccpStatus === 'Pending') && (
                              <button
                                onClick={() => handleExecuteProposal(ccp)}
                                disabled={executingProposals.has(ccp.id) || isPending}
                                className={`px-4 py-2 text-white text-sm font-medium rounded-lg transition-colors duration-200 flex items-center space-x-2 ${
                                  executingProposals.has(ccp.id) || isPending
                                    ? 'bg-gray-400 cursor-not-allowed'
                                    : 'bg-blue-600 hover:bg-blue-700'
                                }`}
                              >
                                {executingProposals.has(ccp.id) || isPending ? (
                                  <>
                                    <svg
                                      className="w-4 h-4 animate-spin"
                                      fill="none"
                                      stroke="currentColor"
                                      viewBox="0 0 24 24"
                                    >
                                      <path
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                        strokeWidth={2}
                                        d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                                      />
                                    </svg>
                                    <span>Executing...</span>
                                  </>
                                ) : (
                                  <>
                                    <svg
                                      className="w-4 h-4"
                                      fill="none"
                                      stroke="currentColor"
                                      viewBox="0 0 24 24"
                                    >
                                      <path
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                        strokeWidth={2}
                                        d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                                      />
                                    </svg>
                                    <span>Execute</span>
                                  </>
                                )}
                              </button>
                            )}
                          </div>
                          <div className="mt-2 space-y-1">
                            <p className="text-sm text-blue-700 font-mono">ID: {ccp.id}</p>
                            <p className="text-sm text-blue-700 font-mono">Salt: {ccp.salt}</p>
                            {eta > 0 && (
                              <p className="text-sm text-blue-700">
                                ETA: {new Date(eta * 1000).toLocaleString()}
                              </p>
                            )}
                          </div>
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
