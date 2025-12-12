'use client'

import { useEffect, useMemo, useState } from 'react'
import { getAddress } from 'viem'
import { usePublicClient } from 'wagmi'
import { base as baseChain } from 'wagmi/chains'

import { erc20Abi } from '@/abis/ERC20'
import { summerStakingAbi } from '@/abis/SummerStaking'
import { summerVestingWalletAbi } from '@/abis/SummerVestingWallet'
import { summerVestingWalletFactoryAbi } from '@/abis/SummerVestingWalletFactory'
import { summerVestingWalletFactoryV2Abi } from '@/abis/SummerVestingWalletFactoryV2'
import { summerVestingWalletV2Abi } from '@/abis/SummerVestingWalletV2'
import {
  STAKED_SUMMER_TOKEN_ADDRESSES,
  SUMMER_STAKING_ADDRESSES,
  SUMMER_TOKEN_ADDRESSES,
  SUMMER_VESTING_WALLET_FACTORY_ADDRESSES,
  SUMMER_VESTING_WALLET_FACTORY_V2_ADDRESSES,
  SUMMER_VESTING_WALLETS_ESCROW_ADDRESSES,
} from '@/config/environments'
import { useEnvironment } from '@/hooks/useEnvironment'
import { useSyncWalletChain } from '@/hooks/useSyncWalletChain'
import type { ChainId } from '@/types'
import { formatDecimalOutput } from '@/utils/decimals'

// --- Types & Constants ---

const ownerAbi = [
  {
    type: 'function',
    name: 'owner',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
] as const

const recipientsRaw: { codename: string; address: `0x${string}` }[] = [
  { codename: 'Gemini', address: '0x083fc10cE7e97CaFBaE0fE332a9c4384c5f54E45' },
  { codename: 'Storm', address: '0x1f9e7147fBfD6334a4215f2bCCACE141F5Ff9e23' },
  { codename: 'Rogue', address: '0x37D04A23485B55204E606C91D1F391048A4871b5' },
  { codename: 'Atom', address: '0xEEE24744799EA3FdbB92C249df11AF3DC17d2C12' },
  { codename: 'Mirage', address: '0x27E4D294B7a738bf3BcF5Ba28F694C03a0dC9d1D' },
  { codename: 'Samurai', address: '0x4b4C13434aaC5e99645A4D9E59Fe497B3318f50f' },
  { codename: 'Realm', address: '0xB00AD932761422B86dE9b7636fA31738D0a6D291' },
  { codename: 'Yeti', address: '0x0314C9Bd44556263959C06246B018137d376880E' },
  { codename: 'Pulse', address: '0x71E3cC5aF063Be18F7DA275F8Ac90387099B3D76' },
  { codename: 'Venom', address: '0xb13433136e9EaD0C1e82455441A7A1A6c40b442C' },
  { codename: 'Safari', address: '0x4DD0BbA91C023a39E942533CC9DAEEf8f9F39dd6' },
  { codename: 'Helm', address: '0xe93E606a0a718b19682fB0C78dC2972073c09d3e' },
  { codename: 'Exile', address: '0x27aC829a306932ED98aab8707AccC35D577B432C' },
  { codename: 'Alibi', address: '0x0483B7717C3f94fFac4aB92edac7226AB09bA6ec' },
  { codename: 'System', address: '0x31BE871cb8FdAC87e73836EFEfDc48Df47383729' },
  { codename: 'Bloom', address: '0xa78c8E485ffe510b60322C95e1E01010edFf524e' },
  { codename: 'Blade', address: '0x3505dCd7bF5b94e539D885304ce38bDd017f1d32' },
  { codename: 'Heidi', address: '0x7fCAf93cc92d51c490FFF701fb2C6197497a80db' },
  { codename: 'Prism', address: '0x07054053Fb2C01291CE983F60bE38942fBAAf0C0' },
  { codename: 'Kali', address: '0xf6B6F07862A02C85628B3A9688beae07fEA9C863' },
  { codename: 'Swarm', address: '0x24d016A2cd05E8a8ed253ec8D6D1Ee0eE0117122' },
  { codename: 'Strike', address: '0x94e53898c7ef5dfce27fd548d8da8098681097c1' },
  { codename: 'Satori', address: '0x55DC2D92ed5d1299D8EEd8EFeF37966c03d29D1B' },
  { codename: 'Totem', address: '0x4DD0BbA91C023a39E942533CC9DAEEf8f9F39dd6' },
  { codename: 'Grove', address: '0xf3eaB8c0E7E0756653fAA20300255cD0570DDDe5' },
  { codename: 'Magi', address: '0x24c47Db1Cc0Ba028836BF808175C044055d037EC' },
  { codename: 'Phantom', address: '0x5b77b967FC9e7Fb9132f88E00B7b23c64a345881' },
  { codename: 'Sensei', address: '0x5E595618047260D3d486522dBfd61095e64FD4e4' },
  { codename: 'Beam', address: '0xb6462b67fe692223dffb61c8dc8ad080cba180cc' },
  { codename: 'Vibe', address: '0xF5857956B7D19fC24DDe9D4178178C60c1d1Ad35' },
  { codename: 'Loki', address: '0xA51675839cA9cf9d241B609680b79E30bE7ac621' },
  { codename: 'Zoom', address: '0xa9d6B401F09f21BBADE40AC52e5ae3e723E6cB3a' },
  { codename: 'Flare', address: '0x93db1C4dE4409b2EAad58352097965aEbE3655A9' },
  { codename: 'Origami', address: '0x73ED1B6713299EF9F0D91923aA0E4c2E06AD1511' },
  { codename: 'Steam', address: '0x1429b9De0f289642E4686249ed795E62eFb033a1' },
  { codename: 'Kirbi', address: '0xb801F7EC399e0860BCbD2899da5b5dBe40D4466e' },
  { codename: 'Golem', address: '0x9F3d223CA31b758eB942c4665311DF1Ca142Eea1' },
  { codename: 'Surge', address: '0x81a68aCc498C2A34D8395992D4DFfA2a07B30475' },
  { codename: 'Navi', address: '0x9B22c5964696d87315D7a94C07D90243AfE7Ab8a' },
  { codename: 'Emblem', address: '0x0b81750655493EEe7a4c1f4E7e4FdB9536041720' },
  { codename: 'Tsunami', address: '0x06C48e3bb62Cb66a388e4475e394C375Dcb4Ff4A' },
  { codename: 'Modem', address: '0x4e393CAAD190e2A55399c8c113D13326780C2c2c' },
  { codename: 'Rhythm', address: '0xb936EAf67729F476d5396c91C4f2b23740C6ba0C' },
  { codename: 'Algorithm', address: '0x37D04A23485B55204E606C91D1F391048A4871b5' },
  { codename: 'Mechanism', address: '0x94E85EA46A9c4604d3c46E917629e92c6Ac2472E' },
]

// Randomize order using Fisher-Yates shuffle
const shuffleArray = <T,>(array: T[]): T[] => {
  const shuffled = [...array]
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]]
  }
  return shuffled
}

const recipients = shuffleArray(recipientsRaw)

type WalletSnapshot = {
  codename: string
  owner: `0x${string}`
  vestingWallet?: `0x${string}`
  version: 'V1' | 'V2' | 'None'
  token?: `0x${string}`
  symbol?: string
  decimals: number
  releasable: bigint
  released: bigint
  vestedAmount: bigint
  totalPlanned: bigint
  vested: bigint
  unvested: bigint
  goalTotal: bigint
  summerBalance: bigint
  xSummerBalance: bigint
  stakingBalance: bigint
  stakeCount: number
  governanceRewardsBalance: bigint
  stakes: StakeRow[]
  vestingWalletBalance: bigint
  unclaimedFromVesting: bigint
  inEscrow: boolean
  error?: string
}

type StakeRow = {
  amount: bigint
  lockupEndTime: bigint
  lockupPeriod: bigint
}

const MAX_GOAL_PROBE = 32

// --- Helpers ---

const toBigInt = (val: unknown): bigint => {
  if (typeof val === 'bigint') return val
  if (typeof val === 'string' || typeof val === 'number') {
    try {
      return BigInt(val)
    } catch {
      return 0n
    }
  }
  return 0n
}

const parseBigIntFromOutput = (value: unknown): bigint => {
  if (value === null || value === undefined) return 0n
  if (typeof value === 'bigint') return value
  if (Array.isArray(value) && value.length > 0) return toBigInt(value[0])
  if (typeof value === 'object') {
    const record = value as any
    if (record.amount) return toBigInt(record.amount)
    if (record[0]) return toBigInt(record[0])
  }
  return 0n
}

// --- Component ---

export default function VestingBatchPage({ params }: { params: { chainId: string } }) {
  const chainId = params.chainId as ChainId
  const chainIdNumber = useMemo(() => Number(chainId) || baseChain.id, [chainId])
  useSyncWalletChain(chainId)
  const { environment } = useEnvironment()
  const publicClient = usePublicClient({ chainId: chainIdNumber })

  // Contract Addresses
  const factoryAddress = SUMMER_VESTING_WALLET_FACTORY_ADDRESSES[environment]?.[chainIdNumber]
  const factoryV2Address = SUMMER_VESTING_WALLET_FACTORY_V2_ADDRESSES[environment]?.[chainIdNumber]
  const escrowAddress = SUMMER_VESTING_WALLETS_ESCROW_ADDRESSES[environment]?.[chainIdNumber]
  const summerTokenAddress = SUMMER_TOKEN_ADDRESSES[environment]?.[chainIdNumber]
  const xSummerTokenAddress = STAKED_SUMMER_TOKEN_ADDRESSES[environment]?.[chainIdNumber]
  const stakingAddress = SUMMER_STAKING_ADDRESSES[environment]?.[chainIdNumber]
  const governanceRewardsAddress = '0xDe61A0a49f48e108079bdE73caeA56E87FfeEF92'

  const [snapshots, setSnapshots] = useState<WalletSnapshot[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // --- Sorting State ---
  const [sortConfig, setSortConfig] = useState<{
    key: keyof WalletSnapshot
    direction: 'asc' | 'desc'
  } | null>(null)

  useEffect(() => {
    async function executeMegaCalls() {
      if (
        !publicClient ||
        !factoryAddress ||
        !factoryV2Address ||
        !summerTokenAddress ||
        !stakingAddress
      ) {
        setError('Missing on-chain configuration')
        return
      }

      setLoading(true)
      setError(null)

      try {
        const nowTs = BigInt(Math.floor(Date.now() / 1000))

        // ---------------------------------------------------------
        // MEGA CALL 1: DISCOVERY (Owners)
        // ---------------------------------------------------------
        const discoveryCalls: any[] = []

        recipients.forEach((r) => {
          discoveryCalls.push(
            {
              address: summerTokenAddress,
              abi: erc20Abi,
              functionName: 'balanceOf',
              args: [r.address],
            },
            xSummerTokenAddress
              ? {
                  address: xSummerTokenAddress,
                  abi: erc20Abi,
                  functionName: 'balanceOf',
                  args: [r.address],
                }
              : {
                  address: summerTokenAddress,
                  abi: erc20Abi,
                  functionName: 'balanceOf',
                  args: [r.address],
                }, // Filler
            {
              address: factoryAddress,
              abi: summerVestingWalletFactoryAbi,
              functionName: 'vestingWallets',
              args: [r.address],
            },
            {
              address: factoryV2Address,
              abi: summerVestingWalletFactoryV2Abi,
              functionName: 'vestingWallets',
              args: [r.address],
            },
            {
              address: stakingAddress,
              abi: summerStakingAbi,
              functionName: 'balanceOf',
              args: [r.address],
            },
            {
              address: stakingAddress,
              abi: summerStakingAbi,
              functionName: 'getUserStakesCount',
              args: [r.address],
            },
            {
              address: governanceRewardsAddress,
              abi: erc20Abi,
              functionName: 'balanceOf',
              args: [r.address],
            },
          )
        })
        // @ts-expect-error - wagmi types are not up to date
        const discoveryResults = await publicClient.multicall({
          contracts: discoveryCalls,
          allowFailure: true,
        })

        const tempSnapshots: WalletSnapshot[] = []
        const stride = 7

        for (let i = 0; i < recipients.length; i++) {
          const base = i * stride
          const sumrRes = discoveryResults[base]
          const xSumrRes = discoveryResults[base + 1]
          const v1Res = discoveryResults[base + 2]
          const v2Res = discoveryResults[base + 3]
          const stBalRes = discoveryResults[base + 4]
          const stCountRes = discoveryResults[base + 5]
          const govRes = discoveryResults[base + 6]

          const v1Addr =
            v1Res.status === 'success' &&
            v1Res.result !== '0x0000000000000000000000000000000000000000'
              ? getAddress(v1Res.result as string)
              : undefined
          const v2Addr =
            v2Res.status === 'success' &&
            v2Res.result !== '0x0000000000000000000000000000000000000000'
              ? getAddress(v2Res.result as string)
              : undefined

          const vestingWallet = v1Addr ?? v2Addr
          const version = vestingWallet ? (v2Addr ? 'V2' : 'V1') : 'None'
          const stakeCount = stCountRes.status === 'success' ? Number(stCountRes.result) : 0

          tempSnapshots.push({
            codename: recipients[i].codename,
            owner: recipients[i].address,
            vestingWallet,
            version,
            stakeCount,
            summerBalance: toBigInt(sumrRes.result),
            xSummerBalance: xSummerTokenAddress ? toBigInt(xSumrRes.result) : 0n,
            stakingBalance: toBigInt(stBalRes.result),
            governanceRewardsBalance: toBigInt(govRes.result),
            decimals: 18,
            releasable: 0n,
            released: 0n,
            vestedAmount: 0n,
            totalPlanned: 0n,
            vested: 0n,
            unvested: 0n,
            goalTotal: 0n,
            stakes: [],
            vestingWalletBalance: 0n,
            unclaimedFromVesting: 0n,
            inEscrow: false,
          })
        }

        // ---------------------------------------------------------
        // MEGA CALL 2: EVERYTHING ELSE
        // ---------------------------------------------------------
        const combinedCalls: any[] = []
        const resultMap = new Map<
          number,
          {
            walletStartIdx?: number
            stakesStartIdx?: number
            stakeCount: number
          }
        >()

        let cursor = 0

        tempSnapshots.forEach((snap, idx) => {
          const tracker: any = { stakeCount: snap.stakeCount }

          if (snap.vestingWallet) {
            tracker.walletStartIdx = cursor
            const isV2 = snap.version === 'V2'
            const abi = isV2 ? summerVestingWalletV2Abi : summerVestingWalletAbi
            const targetToken = snap.token || summerTokenAddress

            combinedCalls.push(
              { address: snap.vestingWallet, abi, functionName: 'token' },
              { address: snap.vestingWallet, abi: ownerAbi, functionName: 'owner' },
              isV2
                ? { address: snap.vestingWallet, abi, functionName: 'vestingParams' }
                : { address: snap.vestingWallet, abi, functionName: 'timeBasedVestingAmount' },
              { address: snap.vestingWallet, abi, functionName: 'releasable', args: [targetToken] },
              { address: snap.vestingWallet, abi, functionName: 'released', args: [targetToken] },
              {
                address: snap.vestingWallet,
                abi,
                functionName: 'vestedAmount',
                args: [targetToken, nowTs],
              },
              {
                address: targetToken,
                abi: erc20Abi,
                functionName: 'balanceOf',
                args: [snap.vestingWallet],
              },
            )
            cursor += 7

            for (let k = 0; k < MAX_GOAL_PROBE; k++) {
              if (isV2) {
                combinedCalls.push({
                  address: snap.vestingWallet,
                  abi,
                  functionName: 'performanceGoals',
                  args: [BigInt(k + 1)],
                })
              } else {
                combinedCalls.push({
                  address: snap.vestingWallet,
                  abi,
                  functionName: 'goalAmounts',
                  args: [BigInt(k)],
                })
              }
            }
            cursor += MAX_GOAL_PROBE
          }

          if (snap.stakeCount > 0) {
            tracker.stakesStartIdx = cursor
            for (let s = 0; s < snap.stakeCount; s++) {
              combinedCalls.push({
                address: stakingAddress,
                abi: summerStakingAbi,
                functionName: 'getUserStake',
                args: [snap.owner, BigInt(s)],
              })
            }
            cursor += snap.stakeCount
          }

          resultMap.set(idx, tracker)
        })

        const combinedResults =
          combinedCalls.length > 0
            ? // @ts-expect-error - wagmi types are not up to date
              await publicClient.multicall({ contracts: combinedCalls, allowFailure: true })
            : []

        // ---------------------------------------------------------
        // PROCESS RESULTS
        // ---------------------------------------------------------

        const finalSnapshots = tempSnapshots.map((snap, idx) => {
          const map = resultMap.get(idx)
          if (!map) return snap

          const newSnap = { ...snap }

          if (snap.vestingWallet && map.walletStartIdx !== undefined) {
            const start = map.walletStartIdx
            const tokenRes = combinedResults[start]
            const ownerRes = combinedResults[start + 1]
            const paramRes = combinedResults[start + 2]
            const relRes = combinedResults[start + 3]
            const rsdRes = combinedResults[start + 4]
            const vstRes = combinedResults[start + 5]
            const balRes = combinedResults[start + 6]

            if (tokenRes.status === 'success') newSnap.token = getAddress(tokenRes.result as string)

            if (ownerRes.status === 'success' && escrowAddress) {
              newSnap.inEscrow = getAddress(ownerRes.result as string) === getAddress(escrowAddress)
            }

            let baseAmount = 0n
            if (snap.version === 'V2') {
              const params = paramRes.result as any
              if (params && Array.isArray(params)) baseAmount = toBigInt(params[3])
            } else {
              baseAmount = toBigInt(paramRes.result)
            }

            newSnap.releasable = toBigInt(relRes.result)
            newSnap.released = toBigInt(rsdRes.result)

            let vestedAmount = toBigInt(vstRes.result)
            if (vestedAmount === 0n && (newSnap.releasable > 0n || newSnap.released > 0n)) {
              vestedAmount = newSnap.releasable + newSnap.released
            }
            newSnap.vestedAmount = vestedAmount
            newSnap.vested = vestedAmount
            newSnap.vestingWalletBalance = toBigInt(balRes.result)
            newSnap.unclaimedFromVesting = newSnap.releasable

            let goalsSum = 0n
            const goalsStart = start + 7
            for (let k = 0; k < MAX_GOAL_PROBE; k++) {
              const res = combinedResults[goalsStart + k]
              if (res.status === 'success') {
                goalsSum += parseBigIntFromOutput(res.result)
              }
            }
            newSnap.goalTotal = goalsSum
            newSnap.totalPlanned = baseAmount + goalsSum
            newSnap.unvested =
              newSnap.totalPlanned > vestedAmount ? newSnap.totalPlanned - vestedAmount : 0n
          }

          if (map.stakesStartIdx !== undefined) {
            const start = map.stakesStartIdx
            const stakes: StakeRow[] = []
            for (let s = 0; s < map.stakeCount; s++) {
              const res = combinedResults[start + s]
              if (res.status === 'success') {
                const [amt, , end, period] = res.result as [bigint, bigint, bigint, bigint]
                if (amt > 0n) {
                  stakes.push({ amount: amt, lockupEndTime: end, lockupPeriod: period })
                }
              }
            }
            newSnap.stakes = stakes
          }

          return newSnap
        })

        setSnapshots(finalSnapshots)
      } catch (err: any) {
        console.error(err)
        setError(err?.message || 'Failed to load batch data')
      } finally {
        setLoading(false)
      }
    }

    executeMegaCalls()
  }, [
    publicClient,
    factoryAddress,
    factoryV2Address,
    escrowAddress,
    summerTokenAddress,
    xSummerTokenAddress,
    stakingAddress,
    governanceRewardsAddress,
  ])

  // --- Sorting Logic ---
  const processedSnapshots = useMemo(() => {
    const data = [...snapshots]

    if (sortConfig) {
      data.sort((a, b) => {
        const valA = a[sortConfig.key] ?? 0
        const valB = b[sortConfig.key] ?? 0

        if (typeof valA === 'bigint' && typeof valB === 'bigint') {
          return sortConfig.direction === 'asc'
            ? valA < valB
              ? -1
              : valA > valB
                ? 1
                : 0
            : valA > valB
              ? -1
              : valA < valB
                ? 1
                : 0
        }
        if (typeof valA === 'number' && typeof valB === 'number') {
          return sortConfig.direction === 'asc' ? valA - valB : valB - valA
        }
        return 0
      })
    }
    return data
  }, [snapshots, sortConfig])

  const summaryTotals = useMemo(() => {
    return snapshots.reduce(
      (acc, s) => {
        acc.totalPlanned += s.totalPlanned || 0n
        acc.vested += s.vested || 0n
        acc.unvested += s.unvested || 0n
        return acc
      },
      { totalPlanned: 0n, vested: 0n, unvested: 0n },
    )
  }, [snapshots])

  const handleSort = (key: keyof WalletSnapshot) => {
    setSortConfig((current) => ({
      key,
      direction: current?.key === key && current.direction === 'asc' ? 'desc' : 'asc',
    }))
  }

  return (
    <main>
      <div className="max-w-9xl mx-auto space-y-6">
        <header className="space-y-4">
          <div className="flex flex-col md:flex-row justify-between md:items-end gap-4">
            <div>
              <h1 className="text-3xl md:text-4xl font-extrabold text-white">
                Batch Vesting Snapshot{' '}
                <span className="text-blue-500 text-2xl align-top">Ultra</span>
              </h1>
              <p className="text-gray-300 text-sm mt-1">
                Chain {chainIdNumber} • Staking {stakingAddress} • {recipients.length} Targets
              </p>
            </div>
            {!loading && snapshots.length > 0 && (
              <div className="text-right text-xs text-green-400 font-mono">
                Synced @ {new Date().toLocaleTimeString()}
              </div>
            )}
          </div>
        </header>

        {error && (
          <div className="p-4 rounded-lg border border-red-600 bg-red-900/40 text-red-200">
            {error}
          </div>
        )}

        <div className="rounded-2xl border border-gray-800 bg-gray-900/70 p-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-center">
            <StatCard
              label="Total Planned"
              value={formatDecimalOutput(summaryTotals.totalPlanned, 18)}
              suffix="SUMR"
            />
            <StatCard
              label="Vested (Available + Claimed)"
              value={formatDecimalOutput(summaryTotals.vested, 18)}
              suffix="SUMR"
            />
            <StatCard
              label="Unvested Future"
              value={formatDecimalOutput(summaryTotals.unvested, 18)}
              suffix="SUMR"
            />
          </div>
        </div>

        {/* Table Container - Fixed Height for sticky headers to work well */}
        <div className="rounded-2xl border border-gray-800 bg-gray-900/70 overflow-x-auto max-h-[70vh] relative shadow-2xl">
          <table className="min-w-full text-xs md:text-sm text-gray-200 whitespace-nowrap">
            <thead className="bg-gray-800 sticky top-0 z-20 shadow-md">
              <tr>
                <th className="px-3 py-3 text-left sticky left-0 bg-gray-800 z-30 shadow-[4px_0_8px_-4px_rgba(0,0,0,0.5)] border-b border-gray-700">
                  Codename
                </th>
                <th className="px-3 py-3 text-left border-b border-gray-700">Wallet / Owner</th>
                <SortableHeader
                  label="Planned"
                  sortKey="totalPlanned"
                  onClick={handleSort}
                  currentSort={sortConfig}
                />
                <SortableHeader
                  label="Vested"
                  sortKey="vested"
                  onClick={handleSort}
                  currentSort={sortConfig}
                />
                <SortableHeader
                  label="Releasable"
                  sortKey="releasable"
                  onClick={handleSort}
                  currentSort={sortConfig}
                />
                <SortableHeader
                  label="Unvested"
                  sortKey="unvested"
                  onClick={handleSort}
                  currentSort={sortConfig}
                />
                <SortableHeader
                  label="SUMR Bal"
                  sortKey="summerBalance"
                  onClick={handleSort}
                  currentSort={sortConfig}
                />
                <SortableHeader
                  label="xSUMR Bal"
                  sortKey="xSummerBalance"
                  onClick={handleSort}
                  currentSort={sortConfig}
                />
                <th className="px-3 py-3 text-right border-b border-gray-700">Staking V2</th>
                <SortableHeader
                  label="Staking V1"
                  sortKey="governanceRewardsBalance"
                  onClick={handleSort}
                  currentSort={sortConfig}
                />
                <th className="px-3 py-3 text-center border-b border-gray-700">Escrow</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-800/60">
              {loading && (
                <tr>
                  <td colSpan={12} className="px-3 py-16 text-center text-gray-400 animate-pulse">
                    Processing 2-Phase Multicall...
                  </td>
                </tr>
              )}
              {!loading &&
                processedSnapshots.map((snap) => {
                  return (
                    <tr key={snap.codename} className="hover:bg-white/5 transition-colors group">
                      <td className="px-3 py-3 font-semibold sticky left-0 bg-gray-900 group-hover:bg-gray-800 z-10 shadow-[4px_0_8px_-4px_rgba(0,0,0,0.5)] border-r border-gray-800/50">
                        <div className="text-white">
                          {snap.codename}
                          <div className="font-normal text-[9px] text-gray-500 mt-0.5 opacity-70 uppercase tracking-wider">
                            {snap.version}
                          </div>
                        </div>
                      </td>
                      <td className="px-3 py-3">
                        <div className="flex flex-col">
                          <span className="text-blue-300 font-mono text-[10px]">
                            {snap.owner.slice(0, 6)}...{snap.owner.slice(-4)}
                          </span>
                          {snap.vestingWallet ? (
                            <span className="text-green-300 font-mono text-[10px]">
                              {snap.vestingWallet.slice(0, 6)}...{snap.vestingWallet.slice(-4)}
                            </span>
                          ) : (
                            <span className="text-gray-600 text-[10px]">—</span>
                          )}
                        </div>
                      </td>
                      <td className="px-3 py-3 text-right font-medium text-gray-100">
                        {formatDecimalOutput(snap.totalPlanned, snap.decimals)}
                      </td>
                      <td className="px-3 py-3 text-right text-gray-300">
                        {formatDecimalOutput(snap.vested, snap.decimals)}
                      </td>
                      <td className="px-3 py-3 text-right text-yellow-200 font-bold">
                        {formatDecimalOutput(snap.releasable, snap.decimals)}
                      </td>
                      <td className="px-3 py-3 text-right text-gray-500">
                        {formatDecimalOutput(snap.unvested, snap.decimals)}
                      </td>
                      <td className="px-3 py-3 text-right">
                        {formatDecimalOutput(snap.summerBalance, snap.decimals)}
                      </td>
                      <td className="px-3 py-3 text-right">
                        {formatDecimalOutput(snap.xSummerBalance, snap.decimals)}
                      </td>
                      <td className="px-3 py-3 text-right min-w-[180px]">
                        <div className="flex flex-col items-end gap-0.5">
                          <span className="mb-1">
                            {formatDecimalOutput(snap.stakingBalance, 18)}
                          </span>
                          {snap.stakes.length > 0 && (
                            <div className="flex flex-col gap-1 w-full">
                              {snap.stakes.map((stake, idx) => (
                                <div
                                  key={idx}
                                  className="flex items-center justify-end gap-2 bg-gray-800/50 border border-gray-700/30 rounded px-1.5 py-0.5 text-[10px]"
                                >
                                  <span className="text-gray-500 font-mono">
                                    {new Date(
                                      Number(stake.lockupEndTime) * 1000,
                                    ).toLocaleDateString()}
                                  </span>
                                  <div className="flex items-baseline gap-1">
                                    <span className="text-gray-200 font-medium tabular-nums">
                                      {formatDecimalOutput(stake.amount, 18)}
                                    </span>
                                    <span className="text-gray-600 text-[9px] uppercase">SUMR</span>
                                  </div>
                                </div>
                              ))}
                            </div>
                          )}
                        </div>
                      </td>
                      <td className="px-3 py-3 text-right">
                        {formatDecimalOutput(snap.governanceRewardsBalance, 18)}
                      </td>
                      <td className="px-3 py-3 text-center">
                        {snap.inEscrow ? (
                          <span
                            className="inline-block w-2 h-2 rounded-full bg-green-500 ring-2 ring-green-900"
                            title="In Escrow"
                          />
                        ) : (
                          <span
                            className="inline-block w-2 h-2 rounded-full bg-gray-700"
                            title="Not Escrow"
                          />
                        )}
                      </td>
                    </tr>
                  )
                })}
            </tbody>
          </table>
        </div>
      </div>
    </main>
  )
}

function StatCard({ label, value, suffix }: { label: string; value: string; suffix?: string }) {
  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900/70 p-4 text-left space-y-1">
      <div className="text-[10px] uppercase tracking-wide text-gray-500">{label}</div>
      <div className="text-2xl font-bold text-white tracking-tight">
        {value} <span className="text-gray-500 text-sm font-normal">{suffix}</span>
      </div>
    </div>
  )
}

function SortableHeader({
  label,
  sortKey,
  onClick,
  currentSort,
}: {
  label: string
  sortKey: keyof WalletSnapshot
  onClick: (key: keyof WalletSnapshot) => void
  currentSort: { key: string; direction: 'asc' | 'desc' } | null
}) {
  return (
    <th
      className="px-3 py-3 text-right border-b border-gray-700 cursor-pointer hover:bg-gray-700/50 transition-colors group select-none"
      onClick={() => onClick(sortKey)}
    >
      <div className="flex items-center justify-end gap-1">
        {label}
        <span className="text-gray-600 text-[10px]">
          {currentSort?.key === sortKey ? (currentSort.direction === 'asc' ? '▲' : '▼') : '↕'}
        </span>
      </div>
    </th>
  )
}
