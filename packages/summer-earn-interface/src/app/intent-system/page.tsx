'use client'

import { useEffect, useState } from 'react'
import { ChainSelector } from '../../components/ChainSelector'
import { EnvironmentSelector } from '../../components/EnvironmentSelector'
import { ContractCard } from '../../components/ContractCard'
import { useEnvironment } from '../../hooks/useEnvironment'
import { useLocalStorage } from '../../hooks/useLocalStorage'
import { useSyncWalletChain } from '../../hooks/useSyncWalletChain'
import type { ChainId } from '../../types'
import { 
  INTENT_BOND_FACTORY_ADDRESSES, 
  INTENT_HANDLER_ADDRESSES, 
  GENERIC_INTENT_ARK_ADDRESSES,
  AAVE_V3_ESCROW_ADDRESSES,
  MOCK_INTENT_ORACLE_ADDRESSES,
  INTENT_SYSTEM_TOKENS
} from '../../config/environments'

export default function IntentSystemPage() {
  const [storedChain, setStoredChain] = useLocalStorage<ChainId>('selectedChain', '8453') // Default to Base
  const [selectedChain, setSelectedChain] = useState<ChainId>(storedChain)
  const { environment, setEnvironment } = useEnvironment()
  const [copiedAddress, setCopiedAddress] = useState<string | null>(null)
  
  useSyncWalletChain(selectedChain)
  
  useEffect(() => {
    setStoredChain(selectedChain)
  }, [selectedChain, setStoredChain])

  // Get contract addresses for current environment and chain
  const intentBondFactory = INTENT_BOND_FACTORY_ADDRESSES[environment][selectedChain]
  const intentHandler = INTENT_HANDLER_ADDRESSES[environment][selectedChain]
  const genericIntentArk = GENERIC_INTENT_ARK_ADDRESSES[environment][selectedChain]
  const aaveV3Escrow = AAVE_V3_ESCROW_ADDRESSES[environment][selectedChain]
  const mockIntentOracle = MOCK_INTENT_ORACLE_ADDRESSES[environment][selectedChain]
  const tokens = INTENT_SYSTEM_TOKENS[environment][selectedChain]

  const isDeployed = intentBondFactory !== '0x0000000000000000000000000000000000000000'

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
            <a
              href="/"
              className="text-blue-400 hover:text-blue-300 transition-colors"
            >
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
          <div className={`p-4 rounded-lg border ${
            isDeployed 
              ? 'bg-green-900/20 border-green-500/30 text-green-300' 
              : 'bg-red-900/20 border-red-500/30 text-red-300'
          }`}>
            <div className="flex items-center gap-2">
              <div className={`w-3 h-3 rounded-full ${
                isDeployed ? 'bg-green-400' : 'bg-red-400'
              }`} />
              <span className="font-semibold">
                {isDeployed ? 'Intent System Deployed' : 'Intent System Not Deployed'}
              </span>
            </div>
            <p className="mt-2 text-sm opacity-80">
              {isDeployed 
                ? `All core contracts are deployed and operational on ${getChainName()}`
                : `No Intent System contracts found on ${getChainName()}`
              }
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
                {tokens && Object.entries(tokens).map(([symbol, address]) => (
                  <div key={symbol} className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
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

            {/* Quick Actions */}
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-white mb-4">Quick Actions</h2>
              <div className="flex flex-wrap gap-4">
                <button className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors">
                  📊 View Intent Statistics
                </button>
                <button className="px-6 py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg font-semibold transition-colors">
                  🔍 Monitor Intents
                </button>
                <button className="px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg font-semibold transition-colors">
                  ⚙️ Manage Solvers
                </button>
                <button className="px-6 py-3 bg-orange-600 hover:bg-orange-700 text-white rounded-lg font-semibold transition-colors">
                  📝 Post Intent
                </button>
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
      </div>
    </main>
  )
}
