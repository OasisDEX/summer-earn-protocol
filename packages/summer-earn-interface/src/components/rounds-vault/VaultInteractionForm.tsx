'use client'

import { useMemo, useState } from 'react'
import { erc20Abi, formatUnits, parseUnits } from 'viem'
import {
  useConnection,
  usePublicClient,
  useReadContract,
  useReadContracts,
  useWriteContract,
} from 'wagmi'

const erc20MetadataAbi = [
  ...erc20Abi,
  {
    type: 'function',
    name: 'symbol',
    inputs: [],
    outputs: [{ name: '', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'decimals',
    inputs: [],
    outputs: [{ name: '', type: 'uint8' }],
    stateMutability: 'view',
  },
] as const

const accessManagerAbi = [
  {
    type: 'function',
    name: 'setWhitelisted',
    inputs: [
      { name: 'context', type: 'address' },
      { name: 'account', type: 'address' },
      { name: 'allowed', type: 'bool' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'hasRole',
    inputs: [
      { name: 'role', type: 'bytes32' },
      { name: 'account', type: 'address' },
    ],
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'isWhitelisted',
    inputs: [
      { name: 'context', type: 'address' },
      { name: 'account', type: 'address' },
    ],
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view',
  },
] as const

interface VaultInteractionFormProps {
  title: string
  description: string
  vaultAddress: `0x${string}`
  vaultAbi: any
  accessManagerAddress?: `0x${string}`
  showFleetURL?: boolean
}

export function VaultInteractionForm({
  title,
  description,
  vaultAddress,
  vaultAbi,
  accessManagerAddress,
}: VaultInteractionFormProps) {
  const { address, chain } = useConnection()
  const publicClient = usePublicClient()

  const [depositAmount, setDepositAmount] = useState('')
  const [exchangeAmount, setExchangeAmount] = useState('')
  const [receiptId, setReceiptId] = useState('')

  const [retryRoundId, setRetryRoundId] = useState('')
  const [settleRoundId, setSettleRoundId] = useState('')
  const [rollbackRoundId, setRollbackRoundId] = useState('')

  const [whitelistAddress, setWhitelistAddress] = useState('')
  const [whitelistStatus, setWhitelistStatus] = useState<boolean>(true)

  const roundStateMap: Record<number, string> = {
    0: 'NotOpened',
    1: 'Opened',
    2: 'InSettlement',
    3: 'Settled',
  }

  // ── On-chain reads ──

  const { data: depositTokenAddr } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'asset',
  }) as { data: `0x${string}` | undefined }

  const { data: exchangeTokenAddr } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'exchangeAsset',
  }) as { data: `0x${string}` | undefined }

  const { data: currentRound } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'getCurrentRound',
  }) as { data: bigint | undefined }

  const { data: roundStateValue } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'roundState',
    args: currentRound !== undefined ? [currentRound] : undefined,
    query: { enabled: currentRound !== undefined },
  }) as { data: number | undefined }

  const { data: vaultTotalAssets } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'totalAssets',
  }) as { data: bigint | undefined }

  const { data: targetVault } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'vault',
  }) as { data: `0x${string}` | undefined }

  const { data: governorRoleHash } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'GOVERNOR_ROLE',
  }) as { data: `0x${string}` | undefined }

  const { data: superKeeperRoleHash } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'SUPER_KEEPER_ROLE',
  }) as { data: `0x${string}` | undefined }

  const { data: keeperRoleHash } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'generateRole',
    args: [1, vaultAddress], // ContractSpecificRoles.KEEPER_ROLE is 1
  }) as { data: `0x${string}` | undefined }

  const { data: isGovernor } = useReadContract({
    address: accessManagerAddress,
    abi: accessManagerAbi,
    functionName: 'hasRole',
    args: governorRoleHash && address ? [governorRoleHash, address] : undefined,
    query: { enabled: !!accessManagerAddress && !!governorRoleHash && !!address },
  }) as { data: boolean | undefined }

  const { data: isSuperKeeper } = useReadContract({
    address: accessManagerAddress,
    abi: accessManagerAbi,
    functionName: 'hasRole',
    args: superKeeperRoleHash && address ? [superKeeperRoleHash, address] : undefined,
    query: { enabled: !!accessManagerAddress && !!superKeeperRoleHash && !!address },
  }) as { data: boolean | undefined }

  const { data: isKeeperLocal } = useReadContract({
    address: accessManagerAddress,
    abi: accessManagerAbi,
    functionName: 'hasRole',
    args: keeperRoleHash && address ? [keeperRoleHash, address] : undefined,
    query: { enabled: !!accessManagerAddress && !!keeperRoleHash && !!address },
  }) as { data: boolean | undefined }

  const { data: isWhitelisted } = useReadContract({
    address: accessManagerAddress,
    abi: accessManagerAbi,
    functionName: 'isWhitelisted',
    args: targetVault && address ? [targetVault, address] : undefined,
    query: { enabled: !!accessManagerAddress && !!targetVault && !!address },
  }) as { data: boolean | undefined }

  // ── Token metadata ──

  const { data: depositSymbol } = useReadContract({
    address: depositTokenAddr,
    abi: erc20MetadataAbi,
    functionName: 'symbol',
    query: { enabled: !!depositTokenAddr },
  }) as { data: string | undefined }

  const { data: depositDecimals } = useReadContract({
    address: depositTokenAddr,
    abi: erc20MetadataAbi,
    functionName: 'decimals',
    query: { enabled: !!depositTokenAddr },
  }) as { data: number | undefined }

  const { data: depositBalance } = useReadContract({
    address: depositTokenAddr,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!depositTokenAddr },
  }) as { data: bigint | undefined }

  const { data: exchangeSymbol } = useReadContract({
    address: exchangeTokenAddr,
    abi: erc20MetadataAbi,
    functionName: 'symbol',
    query: { enabled: !!exchangeTokenAddr },
  }) as { data: string | undefined }

  const { data: allowance } = useReadContract({
    address: depositTokenAddr,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && vaultAddress ? [address, vaultAddress] : undefined,
    query: { enabled: !!address && !!depositTokenAddr && !!vaultAddress },
  }) as { data: bigint | undefined }

  // ── Multicall: receipt balances for ALL rounds (0 .. currentRound) ──

  const roundCount = currentRound !== undefined ? Number(currentRound) + 1 : 0

  const receiptCalls = useMemo(() => {
    if (!address || roundCount === 0) return []
    return Array.from({ length: roundCount }, (_, i) => ({
      address: vaultAddress,
      abi: vaultAbi,
      functionName: 'balanceOf' as const,
      args: [address, BigInt(i)],
    }))
  }, [address, roundCount, vaultAddress, vaultAbi])

  const { data: allReceiptResults } = useReadContracts({
    contracts: receiptCalls as any,
    query: { enabled: receiptCalls.length > 0 },
  })

  // Filter to rounds with balance > 0
  const receiptsWithBalance = useMemo(() => {
    if (!allReceiptResults) return []
    return allReceiptResults
      .map((res: any, i: number) => ({
        round: i,
        balance: res.status === 'success' ? (res.result as bigint) : 0n,
      }))
      .filter((r) => r.balance > 0n)
  }, [allReceiptResults])

  // Balance for the queried past round
  const queryRoundId = receiptId !== '' ? BigInt(receiptId) : undefined
  const { data: pastRoundReceipts } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'balanceOf',
    args: address && queryRoundId !== undefined ? [address, queryRoundId] : undefined,
    query: { enabled: !!address && queryRoundId !== undefined },
  }) as { data: bigint | undefined }

  // ── Derived helpers ──

  const dDec = depositDecimals ?? 18
  const dSym = depositSymbol ?? '???'
  const eSym = exchangeSymbol ?? '???'

  // ── Write actions ──

  const { writeContractAsync, isPending } = useWriteContract()

  const handleDeposit = async () => {
    if (!depositAmount || !address || !depositTokenAddr) return
    const parsed = parseUnits(depositAmount, dDec)
    try {
      // Check if allowance is insufficient
      if (allowance === undefined || allowance < parsed) {
        const hash = await writeContractAsync({
          address: depositTokenAddr,
          abi: erc20Abi,
          functionName: 'approve',
          args: [vaultAddress, parsed],
          chain: chain,
          account: address,
        })

        // Wait for the approve transaction to be mined
        if (publicClient) {
          await publicClient.waitForTransactionReceipt({ hash })
        }
      }

      await writeContractAsync({
        address: vaultAddress,
        abi: vaultAbi,
        functionName: 'deposit',
        args: [parsed, address],
        chain: chain,
        account: address,
      })
      setDepositAmount('')
    } catch (e) {
      console.error('Deposit failed:', e)
    }
  }

  const handleRedeemCurrentRound = async (roundId: number, bal: bigint) => {
    if (!address || currentRound === undefined) return
    try {
      await writeContractAsync({
        address: vaultAddress,
        abi: vaultAbi,
        functionName: 'redeem',
        args: [BigInt(roundId), bal, address, address],
        chain: chain,
        account: address,
      })
    } catch (e) {
      console.error('Redeem failed:', e)
    }
  }

  const handleExchangePastReceipts = async () => {
    if (!receiptId || !exchangeAmount || !address) return
    const parsed = parseUnits(exchangeAmount, dDec)
    try {
      await writeContractAsync({
        address: vaultAddress,
        abi: vaultAbi,
        functionName: 'redeemExchangeAsset',
        args: [BigInt(receiptId), parsed, address, address],
        chain: chain,
        account: address,
      })
      setExchangeAmount('')
    } catch (e) {
      console.error('Exchange failed:', e)
    }
  }

  const handleNextRound = async () => {
    try {
      await writeContractAsync({
        address: vaultAddress,
        abi: vaultAbi,
        functionName: 'nextRound',
        chain: chain,
        account: address,
      })
    } catch (e) {
      console.error('nextRound failed:', e)
    }
  }

  const handleRetryRound = async () => {
    if (!retryRoundId) return
    try {
      await writeContractAsync({
        address: vaultAddress,
        abi: vaultAbi,
        functionName: 'retryRound',
        args: [BigInt(retryRoundId)],
        chain: chain,
        account: address,
      })
      setRetryRoundId('')
    } catch (e) {
      console.error('retryRound failed:', e)
    }
  }

  const handleSetRoundSettled = async () => {
    if (!settleRoundId) return
    try {
      await writeContractAsync({
        address: vaultAddress,
        abi: vaultAbi,
        functionName: 'setRoundSettled',
        args: [BigInt(settleRoundId)],
        chain: chain,
        account: address,
      })
      setSettleRoundId('')
    } catch (e) {
      console.error('setRoundSettled failed:', e)
    }
  }

  const handleEmergencyRollback = async () => {
    if (!rollbackRoundId) return
    try {
      await writeContractAsync({
        address: vaultAddress,
        abi: vaultAbi,
        functionName: 'emergencyRollbackRound',
        args: [BigInt(rollbackRoundId)],
        chain: chain,
        account: address,
      })
      setRollbackRoundId('')
    } catch (e) {
      console.error('emergencyRollbackRound failed:', e)
    }
  }

  const handleSetWhitelisted = async () => {
    if (!whitelistAddress || !accessManagerAddress || !targetVault) return
    try {
      await writeContractAsync({
        address: accessManagerAddress,
        abi: accessManagerAbi,
        functionName: 'setWhitelisted',
        args: [targetVault, whitelistAddress as `0x${string}`, whitelistStatus],
        chain: chain,
        account: address,
      })
      setWhitelistAddress('')
    } catch (e) {
      console.error('setWhitelisted failed:', e)
    }
  }

  // ── Render ──

  return (
    <div className="bg-charcoal-800/60 p-6 rounded-2xl border border-white/5 backdrop-blur-xl shadow-2xl hover:border-white/10 transition-all duration-300">
      <h2 className="text-2xl font-bold bg-gradient-to-r from-blue-400 to-indigo-400 bg-clip-text text-transparent mb-2">
        {title}
      </h2>
      <p className="text-gray-400 text-sm mb-6">{description}</p>

      {/* ── Protocol State ── */}
      <div className="space-y-3 mb-8">
        <Row
          label="Current Round"
          value={`${currentRound?.toString() ?? '…'} ${
            roundStateValue !== undefined ? `(${roundStateMap[roundStateValue]})` : ''
          }`}
        />
        <Row label="Deposit token" value={`${dSym} (${depositTokenAddr?.slice(0, 8)}…)`} />
        <Row label="Exchange token" value={`${eSym} (${exchangeTokenAddr?.slice(0, 8)}…)`} />
        <Row
          label="Vault TVL"
          value={
            vaultTotalAssets !== undefined ? `${formatUnits(vaultTotalAssets, dDec)} ${dSym}` : '…'
          }
        />
      </div>

      {/* ── Your Receipts (all rounds with balance > 0) ── */}
      <Section title="Your Receipts">
        {receiptsWithBalance.length === 0 ? (
          <p className="text-gray-500 text-sm">No receipts found across any round.</p>
        ) : (
          <div className="space-y-2">
            {receiptsWithBalance.map(({ round, balance }) => {
              const isCurrentRound = currentRound !== undefined && BigInt(round) === currentRound
              return (
                <div
                  key={round}
                  className="flex items-center justify-between bg-gray-900/50 p-3 rounded-xl border border-white/5"
                >
                  <div className="flex items-center gap-2">
                    <span
                      className={`text-xs font-mono px-2 py-0.5 rounded ${isCurrentRound ? 'bg-blue-500/20 text-blue-300' : 'bg-gray-700/50 text-gray-400'}`}
                    >
                      R{round}
                    </span>
                    <span className="text-white text-sm font-medium">
                      {formatUnits(balance, dDec)} {dSym}
                    </span>
                    {isCurrentRound && <span className="text-xs text-blue-400">(current)</span>}
                  </div>
                  <div className="flex gap-2">
                    {isCurrentRound ? (
                      <button
                        onClick={() => handleRedeemCurrentRound(round, balance)}
                        disabled={isPending}
                        className="text-xs bg-yellow-500/20 text-yellow-300 hover:bg-yellow-500/30 border border-yellow-500/30 px-3 py-1 rounded-lg transition-all disabled:opacity-50"
                      >
                        Redeem
                      </button>
                    ) : (
                      <button
                        onClick={() => {
                          setReceiptId(String(round))
                          setExchangeAmount(formatUnits(balance, dDec))
                        }}
                        className="text-xs bg-indigo-500/20 text-indigo-300 hover:bg-indigo-500/30 border border-indigo-500/30 px-3 py-1 rounded-lg transition-all"
                      >
                        Exchange →
                      </button>
                    )}
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </Section>

      <Divider />

      {/* ── Deposit ── */}
      <Section title={`Deposit ${dSym}`}>
        {isWhitelisted === false && (
          <div className="bg-red-500/10 border border-red-500/20 text-red-400 p-3 rounded-xl mb-4 text-sm flex items-start gap-2">
            <span className="mt-0.5 text-red-500">⚠️</span>
            <span>
              Your wallet is not whitelisted to interact with this vault. Deposits and withdrawals
              will revert until you are granted access.
            </span>
          </div>
        )}
        <div className="flex gap-3">
          <input
            type="text"
            placeholder={`Amount in ${dSym}`}
            value={depositAmount}
            onChange={(e) => setDepositAmount(e.target.value)}
            className="flex-1 bg-gray-900 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 transition-all"
          />
          <button
            onClick={handleDeposit}
            disabled={isPending || !depositAmount}
            className="bg-blue-500 hover:bg-blue-400 text-white font-medium px-6 py-3 rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95"
          >
            Deposit
          </button>
        </div>
        <div className="flex justify-between items-center mt-1">
          <p className="text-xs text-gray-500">
            Balance: {depositBalance !== undefined ? formatUnits(depositBalance, dDec) : '0'} {dSym}
          </p>
          <p className="text-xs text-gray-500">
            Approved: {allowance !== undefined ? formatUnits(allowance, dDec) : '0'} {dSym}
          </p>
        </div>
      </Section>

      <Divider />

      {/* ── Exchange Past Receipts ── */}
      <Section title={`Exchange past receipts → ${eSym}`}>
        <div className="flex gap-3">
          <input
            type="number"
            placeholder="Round ID"
            value={receiptId}
            onChange={(e) => setReceiptId(e.target.value)}
            className="w-28 bg-gray-900 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all"
          />
          <input
            type="text"
            placeholder="Receipt amount"
            value={exchangeAmount}
            onChange={(e) => setExchangeAmount(e.target.value)}
            className="flex-1 bg-gray-900 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all"
          />
          <button
            onClick={handleExchangePastReceipts}
            disabled={isPending || !receiptId || !exchangeAmount}
            className="bg-indigo-500 hover:bg-indigo-400 text-white font-medium px-6 py-3 rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95"
          >
            Exchange
          </button>
        </div>
        {pastRoundReceipts !== undefined && receiptId !== '' && (
          <p className="text-xs text-gray-500 mt-1">
            Your receipts for round {receiptId}: {formatUnits(pastRoundReceipts, dDec)}
          </p>
        )}
      </Section>

      <Divider />

      {/* ── Administration Panel ── */}
      <div className="space-y-4 bg-gray-900/40 p-5 rounded-xl border border-blue-500/20">
        <div className="flex justify-between items-center">
          <h3 className="text-sm font-semibold text-blue-400 uppercase tracking-wider flex items-center gap-2">
            Administration Actions
          </h3>
          <div className="flex gap-2">
            {isGovernor && (
              <span className="text-[10px] font-bold bg-purple-500/20 text-purple-300 border border-purple-500/30 px-2 py-0.5 rounded">
                GOVERNOR
              </span>
            )}
            {isSuperKeeper && (
              <span className="text-[10px] font-bold bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 px-2 py-0.5 rounded">
                SUPER KEEPER
              </span>
            )}
            {isKeeperLocal && (
              <span className="text-[10px] font-bold bg-blue-500/20 text-blue-300 border border-blue-500/30 px-2 py-0.5 rounded">
                LOCAL KEEPER
              </span>
            )}
          </div>
        </div>

        {accessManagerAddress && (
          <div className="text-xs text-gray-400 break-all mb-2 flex flex-col gap-2">
            <div>
              <span className="text-gray-500 block mb-1">Access Manager contract:</span>
              <code className="text-blue-300 font-mono bg-blue-900/20 px-2 py-1 rounded">
                {accessManagerAddress}
              </code>
            </div>
          </div>
        )}

        <div className="space-y-3 pt-2 border-t border-white/5">
          <div className="flex justify-between items-center bg-gray-900/50 p-3 rounded-xl border border-white/5 gap-4">
            <div className="flex flex-col">
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-bold bg-blue-500/20 text-blue-300 px-2 py-0.5 rounded">
                  KEEPER
                </span>
                <span className="text-sm text-gray-300">Advance Round</span>
              </div>
              <span className="text-xs text-gray-500 mt-1">
                Advances to Round {currentRound !== undefined ? Number(currentRound) + 1 : '…'}
              </span>
            </div>
            <button
              onClick={handleNextRound}
              disabled={isPending}
              className="bg-blue-500/20 text-blue-400 hover:bg-blue-500/30 hover:text-blue-300 border border-blue-500/30 font-medium px-4 py-2 rounded-lg text-sm transition-all disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95"
            >
              nextRound()
            </button>
          </div>

          <div className="flex justify-between items-center bg-gray-900/50 p-3 rounded-xl border border-white/5 gap-4">
            <div className="flex flex-col">
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-bold bg-blue-500/20 text-blue-300 px-2 py-0.5 rounded">
                  KEEPER
                </span>
                <span className="text-sm text-gray-300">Retry Round</span>
              </div>
            </div>
            <div className="flex gap-2">
              <input
                type="number"
                placeholder="Round ID"
                value={retryRoundId}
                onChange={(e) => setRetryRoundId(e.target.value)}
                className="w-24 bg-gray-800 border border-white/10 rounded-lg px-3 py-1 text-sm text-white focus:outline-none focus:ring-1 focus:ring-blue-500/50"
              />
              <button
                onClick={handleRetryRound}
                disabled={isPending || !retryRoundId}
                className="bg-blue-500/20 text-blue-400 hover:bg-blue-500/30 hover:text-blue-300 border border-blue-500/30 font-medium px-3 py-1 rounded-lg text-sm transition-all disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95 whitespace-nowrap"
              >
                retryRound()
              </button>
            </div>
          </div>

          <div className="flex justify-between items-center bg-gray-900/50 p-3 rounded-xl border border-white/5 gap-4">
            <div className="flex flex-col">
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-bold bg-blue-500/20 text-blue-300 px-2 py-0.5 rounded">
                  KEEPER
                </span>
                <span className="text-sm text-gray-300">Settle Round</span>
              </div>
            </div>
            <div className="flex gap-2">
              <input
                type="number"
                placeholder="Round ID"
                value={settleRoundId}
                onChange={(e) => setSettleRoundId(e.target.value)}
                className="w-24 bg-gray-800 border border-white/10 rounded-lg px-3 py-1 text-sm text-white focus:outline-none focus:ring-1 focus:ring-blue-500/50"
              />
              <button
                onClick={handleSetRoundSettled}
                disabled={isPending || !settleRoundId}
                className="bg-blue-500/20 text-blue-400 hover:bg-blue-500/30 hover:text-blue-300 border border-blue-500/30 font-medium px-3 py-1 rounded-lg text-sm transition-all disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95 whitespace-nowrap"
              >
                setRoundSettled()
              </button>
            </div>
          </div>

          <div className="flex justify-between items-center bg-gray-900/50 p-3 rounded-xl border border-white/5 gap-4">
            <div className="flex flex-col">
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-bold bg-purple-500/20 text-purple-300 px-2 py-0.5 rounded">
                  GOVERNOR
                </span>
                <span className="text-sm text-gray-300">Emergency Rollback</span>
              </div>
            </div>
            <div className="flex gap-2">
              <input
                type="number"
                placeholder="Round ID"
                value={rollbackRoundId}
                onChange={(e) => setRollbackRoundId(e.target.value)}
                className="w-24 bg-gray-800 border border-white/10 rounded-lg px-3 py-1 text-sm text-white focus:outline-none focus:ring-1 focus:ring-purple-500/50"
              />
              <button
                onClick={handleEmergencyRollback}
                disabled={isPending || !rollbackRoundId}
                className="bg-purple-500/20 text-purple-400 hover:bg-purple-500/30 hover:text-purple-300 border border-purple-500/30 font-medium px-3 py-1 rounded-lg text-sm transition-all disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95 whitespace-nowrap"
              >
                emergencyRollback()
              </button>
            </div>
          </div>

          <div className="flex justify-between items-center bg-gray-900/50 p-3 rounded-xl border border-white/5 gap-4">
            <div className="flex flex-col">
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-bold bg-green-500/20 text-green-300 px-2 py-0.5 rounded">
                  WHITELIST MANAGER
                </span>
                <span className="text-sm text-gray-300">Set Whitelist</span>
              </div>
              <span className="text-xs text-gray-500 mt-1">
                Context: {targetVault ? `${targetVault.slice(0, 10)}…` : '…'}
              </span>
            </div>
            <div className="flex gap-2">
              <input
                type="text"
                placeholder="0x..."
                value={whitelistAddress}
                onChange={(e) => setWhitelistAddress(e.target.value)}
                className="w-40 bg-gray-800 border border-white/10 rounded-lg px-3 py-1 text-sm text-white focus:outline-none focus:ring-1 focus:ring-green-500/50"
              />
              <select
                value={whitelistStatus ? 'true' : 'false'}
                onChange={(e) => setWhitelistStatus(e.target.value === 'true')}
                className="bg-gray-800 border border-white/10 rounded-lg px-2 py-1 text-sm text-white focus:outline-none focus:ring-1 focus:ring-green-500/50"
              >
                <option value="true">Allow</option>
                <option value="false">Deny</option>
              </select>
              <button
                onClick={handleSetWhitelisted}
                disabled={isPending || !whitelistAddress || !accessManagerAddress}
                className="bg-green-500/20 text-green-400 hover:bg-green-500/30 hover:text-green-300 border border-green-500/30 font-medium px-3 py-1 rounded-lg text-sm transition-all disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95 whitespace-nowrap"
              >
                setWhitelisted()
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

/* ── Tiny helper components ── */

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between items-center bg-gray-900/50 p-3 rounded-xl border border-white/5">
      <span className="text-gray-400 text-sm">{label}</span>
      <span className="font-mono text-white text-sm font-medium">{value}</span>
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="space-y-3">
      <h3 className="text-sm font-semibold text-gray-300 uppercase tracking-wider">{title}</h3>
      {children}
    </div>
  )
}

function Divider() {
  return <div className="h-px bg-white/5 w-full my-6" />
}
