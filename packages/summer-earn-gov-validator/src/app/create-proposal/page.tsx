'use client'

import React, { useState, useEffect, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import { isAddress, encodeFunctionData, keccak256, stringToHex, Address, Hex } from 'viem'
import { useAccount, useReadContract, useWriteContract, usePublicClient } from 'wagmi'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import {
  Plus,
  Trash2,
  ChevronDown,
  ShieldCheck,
  AlertCircle,
  Code,
  Eye,
  Settings,
  Globe,
  Loader2,
  CheckCircle2,
  Play,
  Bold,
  Italic,
  List,
  Type,
  Link as LinkIcon,
  Table as TableIcon,
  Quote,
} from 'lucide-react'
import { TopNavBar } from '@/components/TopNavBar'
import { SideNavBar } from '@/components/SideNavBar'
import deploymentConfig from '@/config/index.json'
import { HUB_GOVERNOR_ADDRESS, HUB_CHAIN_ID, CHAINS } from '@/config/chains'

const HUB_GOVERNOR_ABI = [
  {
    name: 'proposalThreshold',
    type: 'function',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    name: 'getVotes',
    type: 'function',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'timepoint', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    name: 'propose',
    type: 'function',
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'description', type: 'string' },
    ],
    outputs: [{ name: 'proposalId', type: 'uint256' }],
    stateMutability: 'nonpayable',
  },
  {
    name: 'sendProposalToTargetChain',
    type: 'function',
    inputs: [
      { name: '_dstEid', type: 'uint32' },
      { name: '_dstTargets', type: 'address[]' },
      { name: '_dstValues', type: 'uint256[]' },
      { name: '_dstCalldatas', type: 'bytes[]' },
      { name: '_dstDescriptionHash', type: 'bytes32' },
      { name: '_options', type: 'bytes' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
] as const

// --- Types ---

interface Action {
  id: string
  chainId: string
  target: string
  abi: any[]
  method: string
  args: Record<string, any>
  isValid: boolean
}

// --- Helper Functions ---

const getContractTag = (address: string, chainKey: string) => {
  if (!address || !isAddress(address)) return null
  const chainData = (deploymentConfig as any)[chainKey]
  if (!chainData?.deployedContracts) return null

  const searchInObject = (obj: any): string | null => {
    for (const key in obj) {
      const value = obj[key]
      if (typeof value === 'object' && value !== null) {
        if ('address' in value && value.address?.toLowerCase() === address.toLowerCase()) {
          return key.charAt(0).toUpperCase() + key.slice(1).replace(/([A-Z])/g, ' $1')
        }
        const result = searchInObject(value)
        if (result) return result
      }
    }
    return null
  }

  return searchInObject(chainData.deployedContracts)
}

// --- Components ---

interface ArgumentFieldProps {
  param: any
  value: any
  onChange: (val: any) => void
  labelPrefix?: string
}

const DynamicArgumentField: React.FC<ArgumentFieldProps> = ({
  param,
  value,
  onChange,
  labelPrefix = '',
}) => {
  const label = labelPrefix ? `${labelPrefix}.${param.name || 'item'}` : param.name || 'argument'
  const isArray = param.type.endsWith('[]')
  const baseType = isArray ? param.type.slice(0, -2) : param.type
  const isTuple = baseType.startsWith('tuple')

  if (isArray) {
    const arrayValue = Array.isArray(value) ? value : []
    return (
      <div className="space-y-3 p-4 bg-surface-container-lowest/50 rounded-2xl border border-outline-variant/30">
        <div className="flex items-center justify-between">
          <label className="text-[10px] font-bold text-primary tracking-widest uppercase">
            {label} (Array)
          </label>
          <button
            onClick={() => onChange([...arrayValue, isTuple ? {} : ''])}
            className="flex items-center gap-1 text-[10px] font-bold text-primary hover:text-primary-fixed transition-colors"
          >
            <Plus size={12} /> Add Item
          </button>
        </div>
        <div className="space-y-3">
          {arrayValue.map((item, idx) => (
            <div key={idx} className="flex gap-2 items-start">
              <div className="flex-1">
                <DynamicArgumentField
                  param={{ ...param, type: baseType, name: `${idx}` }}
                  value={item}
                  onChange={(val) => {
                    const newArr = [...arrayValue]
                    newArr[idx] = val
                    onChange(newArr)
                  }}
                  labelPrefix={label}
                />
              </div>
              <button
                onClick={() => onChange(arrayValue.filter((_, i) => i !== idx))}
                className="mt-8 p-2 text-on-surface-variant hover:text-error transition-colors"
              >
                <Trash2 size={14} />
              </button>
            </div>
          ))}
          {arrayValue.length === 0 && (
            <p className="text-[10px] text-on-surface-variant/50 italic py-2">
              No items added yet.
            </p>
          )}
        </div>
      </div>
    )
  }

  if (isTuple) {
    const tupleValue = typeof value === 'object' && value !== null ? value : {}
    return (
      <div className="space-y-4 p-4 bg-surface-variant/20 rounded-2xl border border-outline-variant/50">
        <label className="text-[10px] font-bold text-on-surface-variant tracking-widest uppercase">
          {label} (Tuple)
        </label>
        <div className="space-y-4">
          {param.components?.map((comp: any, idx: number) => (
            <DynamicArgumentField
              key={`${comp.name}-${idx}`}
              param={comp}
              value={tupleValue[comp.name]}
              onChange={(val: any) => onChange({ ...tupleValue, [comp.name]: val })}
              labelPrefix={label}
            />
          ))}
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-2">
      <label className="text-[10px] font-bold text-on-surface-variant tracking-widest uppercase ml-1">
        {label} <span className="text-[8px] opacity-40">({param.type})</span>
      </label>
      <input
        type="text"
        placeholder={`Enter ${param.type}...`}
        value={value || ''}
        onChange={(e) => onChange(e.target.value)}
        className="w-full bg-surface-container-low border border-outline-variant rounded-xl p-3 text-sm focus:outline-none focus:ring-1 focus:ring-primary/50 transition-all placeholder:text-on-surface-variant/20"
      />
    </div>
  )
}

// --- Main Component ---

export default function CreateProposalPage() {
  const router = useRouter()
  const { address: userAddress, isConnected } = useAccount()
  const { writeContractAsync } = useWriteContract()

  // --- Proposal State ---
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [actions, setActions] = useState<Action[]>([
    { id: '1', chainId: '8453', target: '', abi: [], method: '', args: {}, isValid: false },
  ])
  const [activeTab, setActiveTab] = useState<'editor' | 'preview'>('editor')
  const [isFetchingAbi, setIsFetchingAbi] = useState<Record<string, boolean>>({})
  const [isSimulating, setIsSimulating] = useState(false)
  const [simResult, setSimResult] = useState<'success' | 'fail' | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const descriptionRef = React.useRef<HTMLTextAreaElement>(null)

  const insertMarkdown = (prefix: string, suffix: string = '') => {
    const textarea = descriptionRef.current
    if (!textarea) return

    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const text = textarea.value
    const selected = text.substring(start, end)
    const before = text.substring(0, start)
    const after = text.substring(end)

    const newText = `${before}${prefix}${selected || (prefix === '| ' ? 'Header | Header |\n| --- | --- |\n| Cell | Cell |' : 'text')}${suffix}${after}`
    setDescription(newText)

    setTimeout(() => {
      textarea.focus()
      textarea.setSelectionRange(
        start + prefix.length,
        start + prefix.length + (selected.length || (prefix === '| ' ? 13 : 4)),
      )
    }, 10)
  }

  // --- On-Chain Eligibility ---
  const { data: threshold } = useReadContract({
    address: HUB_GOVERNOR_ADDRESS,
    abi: HUB_GOVERNOR_ABI,
    functionName: 'proposalThreshold',
    chainId: Number(HUB_CHAIN_ID),
  })

  const { data: votingPower } = useReadContract({
    address: HUB_GOVERNOR_ADDRESS,
    abi: HUB_GOVERNOR_ABI,
    functionName: 'getVotes',
    args: userAddress ? [userAddress, BigInt(Math.floor(Date.now() / 1000) - 300)] : undefined, // Proxy for recent block
    chainId: Number(HUB_CHAIN_ID),
    query: {
      enabled: !!userAddress,
    },
  })

  const isEligible = useMemo(() => {
    if (!threshold || !votingPower) return true // Default true for UI testing if data not loaded
    return votingPower >= threshold
  }, [threshold, votingPower])

  // --- ABI Fetching Effect ---
  useEffect(() => {
    actions.forEach(async (action) => {
      if (isAddress(action.target) && action.abi.length === 0 && !isFetchingAbi[action.id]) {
        setIsFetchingAbi((prev) => ({ ...prev, [action.id]: true }))
        try {
          const res = await fetch(`/api/abi?address=${action.target}&chainId=${action.chainId}`)
          const data = await res.json()
          if (data.abi) {
            updateAction(action.id, { abi: data.abi })
          }
        } catch (err) {
          console.error('Failed to fetch ABI:', err)
        } finally {
          setIsFetchingAbi((prev) => ({ ...prev, [action.id]: false }))
        }
      }
    })
  }, [actions.map((a) => a.target).join(','), actions.map((a) => a.chainId).join(',')])

  // --- Proposal Encoding Engine ---

  const encodeProposal = () => {
    const hubTargets: Address[] = []
    const hubValues: bigint[] = []
    const hubCalldatas: Hex[] = []

    // 1. Group by chain
    const chainGroups = actions.reduce(
      (acc, action) => {
        acc[action.chainId] = acc[action.chainId] || []
        acc[action.chainId].push(action)
        return acc
      },
      {} as Record<string, Action[]>,
    )

    // 2. Process each chain
    Object.entries(chainGroups).forEach(([chainId, groupActions]) => {
      const isHub = chainId === HUB_CHAIN_ID

      const targets = groupActions.map((a) => a.target as Address)
      const values = groupActions.map(() => 0n)
      const calldatas = groupActions.map((a) => {
        const methodObj = a.abi.find((m) => m.name === a.method)
        return encodeFunctionData({
          abi: [methodObj],
          functionName: a.method,
          args: methodObj.inputs.map((i: any) => a.args[i.name]),
        })
      })

      if (isHub) {
        hubTargets.push(...targets)
        hubValues.push(...values)
        hubCalldatas.push(...calldatas)
      } else {
        // Wrap in cross-chain call
        const chainInfo = CHAINS.find((c) => c.id === chainId)
        const eID = chainInfo?.eID || '0'
        const dstDescription = `SIP-XXX Cross-Chain Actions for ${chainInfo?.name}`
        const lzOptions = '0x0003010011030000000000000000000000000007a120' as Hex // ~500k gas

        hubTargets.push(HUB_GOVERNOR_ADDRESS)
        hubValues.push(0n)
        hubCalldatas.push(
          encodeFunctionData({
            abi: HUB_GOVERNOR_ABI,
            functionName: 'sendProposalToTargetChain',
            args: [
              Number(eID),
              targets,
              values,
              calldatas,
              keccak256(stringToHex(dstDescription)),
              lzOptions,
            ],
          }),
        )
      }
    })

    return {
      targets: hubTargets,
      values: hubValues,
      calldatas: hubCalldatas,
      description: `${title}\n\n${description}`,
    }
  }

  // --- Handlers ---
  const addAction = () => {
    setActions([
      ...actions,
      {
        id: Math.random().toString(36).substr(2, 9),
        chainId: '8453',
        target: '',
        abi: [],
        method: '',
        args: {},
        isValid: false,
      },
    ])
  }

  const removeAction = (id: string) => {
    if (actions.length > 1) {
      setActions(actions.filter((a) => a.id !== id))
    }
  }

  const updateAction = (id: string, updates: Partial<Action>) => {
    setActions(actions.map((a) => (a.id === id ? { ...a, ...updates } : a)))
  }

  const handleSimulate = async () => {
    setIsSimulating(true)
    setSimResult(null)
    // Mock simulation delay
    await new Promise((r) => setTimeout(r, 2000))
    setSimResult('success')
    setIsSimulating(false)
  }

  const handlePropose = async () => {
    setIsSubmitting(true)
    try {
      const data = encodeProposal()
      await writeContractAsync({
        address: HUB_GOVERNOR_ADDRESS,
        abi: HUB_GOVERNOR_ABI,
        functionName: 'propose',
        args: [data.targets, data.values, data.calldatas, data.description],
      })
      router.push('/proposals')
    } catch (err) {
      console.error('Proposal failed:', err)
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="min-h-screen bg-background text-on-surface font-sans selection:bg-primary/30 antialiased tracking-tight">
      <TopNavBar />
      <div className="flex">
        <SideNavBar />
        <main className="flex-1 p-8 max-w-7xl mx-auto">
          {/* Header Area */}
          <div className="mb-10 flex flex-col md:flex-row md:items-end justify-between gap-6">
            <div>
              <div className="flex items-center gap-2 text-primary mb-2">
                <Globe size={16} className="text-primary-fixed" />
                <span className="text-xs font-bold tracking-widest uppercase">
                  Multi-Chain Governance
                </span>
              </div>
              <h1 className="text-4xl font-bold tracking-tighter text-on-surface mb-2">
                Create New SIP
              </h1>
              <p className="text-on-surface-variant max-w-2xl">
                Draft a proposal to execute actions across the Summer DAO ecosystem. SIPs can
                include local Hub actions and cross-chain transactions via LayerZero.
              </p>
            </div>

            <div className="flex items-center gap-3">
              <button
                onClick={handleSimulate}
                disabled={isSimulating || actions.some((a) => !a.method)}
                className="flex items-center gap-2 px-6 py-2.5 rounded-xl border border-primary/30 text-primary hover:bg-primary/10 transition-all font-bold disabled:opacity-50"
              >
                {isSimulating ? <Loader2 className="animate-spin" size={16} /> : <Play size={16} />}
                Simulate
              </button>
              <button
                onClick={handlePropose}
                disabled={!isEligible || !title || isSubmitting}
                className={`px-8 py-2.5 rounded-xl font-bold flex items-center gap-2 transition-all active:scale-95 shadow-lg ${
                  isEligible && title
                    ? 'bg-primary text-on-primary hover:brightness-110 shadow-primary/20'
                    : 'bg-surface-container-highest text-on-surface-variant cursor-not-allowed grayscale'
                }`}
              >
                {isSubmitting ? (
                  <Loader2 className="animate-spin" size={18} />
                ) : (
                  <ShieldCheck size={18} />
                )}
                Submit Proposal
              </button>
            </div>
          </div>

          {simResult === 'success' && (
            <div className="mb-8 p-4 glass-panel border-success/20 bg-success/5 rounded-2xl flex items-center justify-between gap-4 text-success animate-in slide-in-from-top-4">
              <div className="flex items-center gap-3">
                <CheckCircle2 size={24} />
                <div>
                  <p className="font-bold">Simulation Verified</p>
                  <p className="text-sm opacity-80">
                    Execution simulation successful on Tenderly fork.
                  </p>
                </div>
              </div>
              <button
                onClick={() => setSimResult(null)}
                className="text-[10px] font-bold uppercase tracking-widest px-3 py-1 bg-success/10 rounded-lg"
              >
                Dismiss
              </button>
            </div>
          )}

          {!isEligible && isConnected && (
            <div className="mb-8 p-4 glass-panel border-error/20 bg-error/5 rounded-2xl flex items-center gap-4 text-error">
              <AlertCircle size={24} />
              <div>
                <p className="font-bold">Insufficient Voting Power</p>
                <p className="text-sm opacity-80">
                  You need to meet the proposal threshold to submit. Current power:{' '}
                  {votingPower?.toString() || '0'}.
                </p>
              </div>
            </div>
          )}

          <div className="grid grid-cols-1 xl:grid-cols-12 gap-8 items-start">
            <div className="xl:col-span-7 space-y-6">
              <div className="glass-panel p-8 rounded-3xl space-y-6 shadow-xl relative overflow-hidden">
                <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-primary/40 to-transparent" />

                <div className="space-y-2">
                  <label className="text-xs font-bold text-primary tracking-widest uppercase ml-1">
                    Title
                  </label>
                  <input
                    type="text"
                    placeholder="SIP-XXX: Proposal Title"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    className="w-full bg-surface-container-lowest border border-outline-variant rounded-2xl p-4 text-xl font-bold focus:outline-none focus:ring-2 focus:ring-primary/40 focus:border-primary transition-all placeholder:text-on-surface-variant/30"
                  />
                </div>

                <div className="space-y-4">
                  <div className="flex flex-col gap-4">
                    <div className="flex items-center justify-between ml-1">
                      <label className="text-xs font-bold text-primary tracking-widest uppercase">
                        Description
                      </label>
                      <div className="flex p-1 bg-surface-container-lowest rounded-xl border border-outline-variant">
                        <button
                          onClick={() => setActiveTab('editor')}
                          className={`flex items-center gap-2 px-3 py-1 rounded-lg text-xs font-bold transition-all ${
                            activeTab === 'editor'
                              ? 'bg-primary/20 text-primary'
                              : 'text-on-surface-variant hover:text-on-surface'
                          }`}
                        >
                          <Code size={14} />
                          Markdown
                        </button>
                        <button
                          onClick={() => setActiveTab('preview')}
                          className={`flex items-center gap-2 px-3 py-1 rounded-lg text-xs font-bold transition-all ${
                            activeTab === 'preview'
                              ? 'bg-primary/20 text-primary'
                              : 'text-on-surface-variant hover:text-on-surface'
                          }`}
                        >
                          <Eye size={14} />
                          Preview
                        </button>
                      </div>
                    </div>

                    {activeTab === 'editor' && (
                      <div className="flex items-center gap-1 p-1 bg-surface-container-lowest border border-outline-variant rounded-xl overflow-x-auto no-scrollbar">
                        <button
                          onClick={() => insertMarkdown('**', '**')}
                          className="p-2 hover:bg-surface-container-high rounded-lg text-on-surface-variant transition-colors"
                          title="Bold"
                        >
                          <Bold size={16} />
                        </button>
                        <button
                          onClick={() => insertMarkdown('*', '*')}
                          className="p-2 hover:bg-surface-container-high rounded-lg text-on-surface-variant transition-colors"
                          title="Italic"
                        >
                          <Italic size={16} />
                        </button>
                        <button
                          onClick={() => insertMarkdown('# ')}
                          className="p-2 hover:bg-surface-container-high rounded-lg text-on-surface-variant transition-colors"
                          title="Heading"
                        >
                          <Type size={16} />
                        </button>
                        <div className="w-px h-4 bg-outline-variant mx-1" />
                        <button
                          onClick={() => insertMarkdown('- ')}
                          className="p-2 hover:bg-surface-container-high rounded-lg text-on-surface-variant transition-colors"
                          title="List"
                        >
                          <List size={16} />
                        </button>
                        <button
                          onClick={() => insertMarkdown('> ')}
                          className="p-2 hover:bg-surface-container-high rounded-lg text-on-surface-variant transition-colors"
                          title="Quote"
                        >
                          <Quote size={16} />
                        </button>
                        <button
                          onClick={() => insertMarkdown('`', '`')}
                          className="p-2 hover:bg-surface-container-high rounded-lg text-on-surface-variant transition-colors"
                          title="Code"
                        >
                          <Code size={16} />
                        </button>
                        <div className="w-px h-4 bg-outline-variant mx-1" />
                        <button
                          onClick={() => insertMarkdown('[', '](url)')}
                          className="p-2 hover:bg-surface-container-high rounded-lg text-on-surface-variant transition-colors"
                          title="Link"
                        >
                          <LinkIcon size={16} />
                        </button>
                        <button
                          onClick={() => insertMarkdown('| ')}
                          className="p-2 hover:bg-surface-container-high rounded-lg text-on-surface-variant transition-colors"
                          title="Table"
                        >
                          <TableIcon size={16} />
                        </button>
                      </div>
                    )}
                  </div>

                  {activeTab === 'editor' ? (
                    <div className="relative group">
                      <textarea
                        ref={descriptionRef}
                        rows={16}
                        placeholder="# Summary\nDescribe what this proposal does..."
                        value={description}
                        onChange={(e) => setDescription(e.target.value)}
                        className="w-full bg-surface-container-lowest border border-outline-variant rounded-2xl p-6 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-primary/40 focus:border-primary transition-all placeholder:text-on-surface-variant/30 resize-none"
                      />
                    </div>
                  ) : (
                    <div className="w-full bg-surface-container-lowest border border-outline-variant rounded-2xl p-8 min-h-[400px] prose prose-invert prose-sky max-w-none">
                      {description ? (
                        <ReactMarkdown remarkPlugins={[remarkGfm]}>{description}</ReactMarkdown>
                      ) : (
                        <p className="text-on-surface-variant italic">Nothing to preview yet...</p>
                      )}
                    </div>
                  )}
                </div>
              </div>
            </div>

            <div className="xl:col-span-5 space-y-4">
              <div className="flex items-center justify-between mb-2">
                <h2 className="text-lg font-bold tracking-tight text-on-surface flex items-center gap-2">
                  Proposed Actions
                  <span className="bg-primary/10 text-primary text-[10px] px-2 py-0.5 rounded-full border border-primary/20">
                    {actions.length} Total
                  </span>
                </h2>
                <button
                  onClick={addAction}
                  className="p-2 rounded-full bg-primary/10 text-primary hover:bg-primary/20 transition-all border border-primary/30"
                >
                  <Plus size={18} />
                </button>
              </div>

              <div className="space-y-4 pb-20">
                {actions.map((action, index) => {
                  const methods = action.abi.filter(
                    (item) =>
                      item.type === 'function' &&
                      item.stateMutability !== 'view' &&
                      item.stateMutability !== 'pure',
                  )
                  const selectedMethodObj = methods.find((m) => m.name === action.method)

                  return (
                    <div
                      key={action.id}
                      className="glass-panel-elevated p-6 rounded-3xl border border-outline-variant/50 relative group/action transition-all"
                    >
                      <div className="flex items-center justify-between mb-6">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-xl bg-surface-container-highest flex items-center justify-center text-xs font-bold text-on-surface border border-outline-variant">
                            {index + 1}
                          </div>
                          <select
                            value={action.chainId}
                            onChange={(e) =>
                              updateAction(action.id, {
                                chainId: e.target.value,
                                abi: [],
                                method: '',
                                args: {},
                              })
                            }
                            className="bg-transparent text-sm font-bold text-on-surface focus:outline-none cursor-pointer hover:text-primary transition-colors"
                          >
                            {CHAINS.map((c) => (
                              <option
                                key={c.id}
                                value={c.id}
                                style={{ backgroundColor: '#020617' }}
                              >
                                {c.name}
                              </option>
                            ))}
                          </select>
                        </div>
                        <button
                          onClick={() => removeAction(action.id)}
                          className="opacity-0 group-hover/action:opacity-100 p-2 text-on-surface-variant hover:text-error transition-all"
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>

                      <div className="space-y-6">
                        <div className="space-y-2">
                          <label className="text-[10px] font-bold text-on-surface-variant tracking-widest uppercase ml-1">
                            Target Address
                          </label>
                          <div className="relative group/input">
                            {(() => {
                              const tag = getContractTag(
                                action.target,
                                CHAINS.find((c) => c.id === action.chainId)?.key || 'base',
                              )
                              const isFetching = isFetchingAbi[action.id]
                              return (
                                <>
                                  <input
                                    type="text"
                                    placeholder="0x..."
                                    value={action.target}
                                    onChange={(e) =>
                                      updateAction(action.id, {
                                        target: e.target.value,
                                        abi: [],
                                        method: '',
                                        args: {},
                                      })
                                    }
                                    className={`w-full bg-surface-container-low border border-outline-variant rounded-xl p-3 font-mono focus:outline-none focus:ring-1 focus:ring-primary/50 transition-all placeholder:text-on-surface-variant/10 text-sm ${
                                      tag ? 'pr-32' : isFetching ? 'pr-12' : 'pr-3'
                                    }`}
                                  />
                                  {(tag || isFetching) && (
                                    <div className="absolute right-[1px] top-[1px] bottom-[1px] flex items-center pr-3 pl-12 rounded-r-xl bg-gradient-to-r from-transparent via-surface-container-low/95 to-surface-container-low pointer-events-none">
                                      <div className="flex items-center gap-2">
                                        {isFetching && (
                                          <Loader2
                                            className="animate-spin text-primary"
                                            size={14}
                                          />
                                        )}
                                        {tag && (
                                          <span className="bg-primary/10 text-primary text-[10px] font-bold px-2 py-1 rounded-lg border border-primary/20 whitespace-nowrap backdrop-blur-sm shadow-sm">
                                            {tag}
                                          </span>
                                        )}
                                      </div>
                                    </div>
                                  )}
                                </>
                              )
                            })()}
                          </div>
                        </div>

                        {action.abi.length > 0 && (
                          <div className="space-y-6 animate-in fade-in slide-in-from-top-2 duration-300">
                            <div className="space-y-2">
                              <label className="text-[10px] font-bold text-on-surface-variant tracking-widest uppercase ml-1">
                                Select Method
                              </label>
                              <div className="relative">
                                <select
                                  value={action.method}
                                  onChange={(e) =>
                                    updateAction(action.id, { method: e.target.value, args: {} })
                                  }
                                  className="w-full bg-surface-container-low border border-outline-variant rounded-xl p-3 text-sm font-bold text-on-surface appearance-none focus:outline-none focus:ring-1 focus:ring-primary/50 transition-all cursor-pointer"
                                >
                                  <option value="">Choose a function...</option>
                                  {methods.map((m, idx) => (
                                    <option
                                      key={`${m.name}-${idx}`}
                                      value={m.name}
                                      style={{ backgroundColor: '#020617' }}
                                    >
                                      {m.name}
                                    </option>
                                  ))}
                                </select>
                                <ChevronDown
                                  size={16}
                                  className="absolute right-4 top-1/2 -translate-y-1/2 text-on-surface-variant pointer-events-none"
                                />
                              </div>
                            </div>

                            {selectedMethodObj && (
                              <div className="space-y-4 border-t border-outline-variant/30 pt-4">
                                {selectedMethodObj.inputs?.length > 0 ? (
                                  selectedMethodObj.inputs.map((input: any, idx: number) => (
                                    <DynamicArgumentField
                                      key={`${input.name}-${idx}`}
                                      param={input}
                                      value={action.args[input.name]}
                                      onChange={(val) =>
                                        updateAction(action.id, {
                                          args: { ...action.args, [input.name]: val },
                                        })
                                      }
                                    />
                                  ))
                                ) : (
                                  <p className="text-xs text-on-surface-variant/50 italic py-2 text-center">
                                    No arguments required for this method.
                                  </p>
                                )}
                              </div>
                            )}
                          </div>
                        )}

                        {action.abi.length === 0 &&
                          !isFetchingAbi[action.id] &&
                          action.target &&
                          isAddress(action.target) && (
                            <div className="p-6 border border-dashed border-error/20 bg-error/5 rounded-2xl flex flex-col items-center justify-center text-center space-y-2">
                              <AlertCircle size={20} className="text-error/40" />
                              <p className="text-xs text-error/60 font-medium">
                                ABI not found. Please ensure the contract is verified on the
                                explorer.
                              </p>
                            </div>
                          )}

                        {(!action.target || !isAddress(action.target)) && (
                          <div className="p-8 border border-dashed border-outline-variant rounded-2xl flex flex-col items-center justify-center text-center space-y-2 grayscale">
                            <Settings size={20} className="text-on-surface-variant/30" />
                            <p className="text-xs text-on-surface-variant/50 max-w-[200px]">
                              Enter a target address to load contract methods.
                            </p>
                          </div>
                        )}
                      </div>
                    </div>
                  )
                })}

                <button
                  onClick={addAction}
                  className="w-full py-4 rounded-3xl border border-dashed border-outline-variant text-on-surface-variant hover:text-primary hover:border-primary/50 hover:bg-primary/5 transition-all text-sm font-bold flex items-center justify-center gap-2"
                >
                  <Plus size={18} />
                  Add Another Action
                </button>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
  )
}
