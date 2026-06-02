'use client'

import React, { useEffect, useMemo, useState } from 'react'
import ReactMarkdown from 'react-markdown'
import {
  AlertCircle,
  Bold,
  ChevronDown,
  Code,
  Download,
  Eye,
  FileText,
  Globe,
  Italic,
  Link as LinkIcon,
  List,
  Loader2,
  Network,
  Play,
  Plus,
  Quote,
  Settings,
  ShieldCheck,
  Table as TableIcon,
  Trash2,
  Type,
  Upload,
} from 'lucide-react'
import { useRouter } from 'next/navigation'
import remarkGfm from 'remark-gfm'
import {
  Abi,
  Address,
  decodeFunctionData,
  encodeFunctionData,
  Hex,
  isAddress,
  keccak256,
  stringToHex,
} from 'viem'
import { useConnection, useReadContract, useWriteContract } from 'wagmi'

import { SideNavBar } from '@/components/SideNavBar'
import { SimulationCenter } from '@/components/SimulationCenter/SimulationCenter'
import { TopNavBar } from '@/components/TopNavBar'
import { GOVERNOR_ABI as HUB_GOVERNOR_ABI } from '@/config/abis/governor'
import { CHAINS, HUB_CHAIN_ID, HUB_GOVERNOR_ADDRESS } from '@/config/chains'
import deploymentConfigRaw from '@/config/index.json'
import { useSimulation } from '@/hooks/useSimulation'
import { DeploymentConfig } from '@/types/deployment'
import { AbiInput, AbiItem, ProposalAction } from '@/types/governance'
import { Action } from '@/types/tenderly'
import { constructLzOptions } from '@/utils/layerzero-options'
import {
  bigIntSafeReplacer,
  buildActionCalldata,
  computeGasRatio,
  computeGasSeverity,
  DEFAULT_LZ_GAS_LIMIT,
  GasSeverityOrIdle,
  LZ_GAS_HEADROOM_PERCENT,
  parseLzGas,
  worstSeverity,
  ZERO_BYTES32,
} from '@/utils/proposal-encoding'

// --- Types ---

const deploymentConfig = deploymentConfigRaw as DeploymentConfig

// --- Helper Functions ---

const getContractTag = (address: string, chainKey: string) => {
  if (!address || !isAddress(address)) return null
  const chainData = deploymentConfig[chainKey]
  if (!chainData?.deployedContracts) return null

  const searchInObject = (obj: Record<string, unknown>): string | null => {
    for (const key in obj) {
      const value = obj[key]
      if (typeof value === 'object' && value !== null) {
        const valObj = value as Record<string, unknown>
        if ('address' in valObj && String(valObj.address).toLowerCase() === address.toLowerCase()) {
          return key.charAt(0).toUpperCase() + key.slice(1).replace(/([A-Z])/g, ' $1')
        }
        const result = searchInObject(valObj)
        if (result) return result
      }
    }
    return null
  }

  return searchInObject(chainData.deployedContracts as Record<string, unknown>)
}

// --- Components ---

interface ArgumentFieldProps {
  param: AbiInput
  value: unknown
  onChange: (val: unknown) => void
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
    const arrayValue = Array.isArray(value) ? (value as unknown[]) : []
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
    const tupleValue =
      typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {}
    return (
      <div className="space-y-4 p-4 bg-surface-variant/20 rounded-2xl border border-outline-variant/50">
        <label className="text-[10px] font-bold text-on-surface-variant tracking-widest uppercase">
          {label} (Tuple)
        </label>
        <div className="space-y-4">
          {param.components?.map((comp, idx: number) => (
            <DynamicArgumentField
              key={`${comp.name}-${idx}`}
              param={comp}
              value={tupleValue[comp.name]}
              onChange={(val) => onChange({ ...tupleValue, [comp.name]: val })}
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
        value={typeof value === 'string' || typeof value === 'number' ? value : ''}
        onChange={(e) => onChange(e.target.value)}
        className="w-full bg-surface-container-low border border-outline-variant rounded-xl p-3 text-sm focus:outline-none focus:ring-1 focus:ring-primary/50 transition-all placeholder:text-on-surface-variant/20"
      />
    </div>
  )
}

// --- Main Component ---

export default function CreateProposalPage() {
  const router = useRouter()
  const { address: userAddress, isConnected } = useConnection()
  const { mutateAsync: writeContractAsync } = useWriteContract()

  // --- Proposal State ---
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const { results, isSimulating, triggerSimulation, setResults } = useSimulation()
  const [actions, setActions] = useState<ProposalAction[]>([
    {
      id: Math.random().toString(36).substr(2, 9),
      chainId: HUB_CHAIN_ID,
      target: '',
      abi: [],
      method: '',
      args: {},
      isValid: false,
    },
  ])
  const [activeTab, setActiveTab] = useState<'editor' | 'preview'>('editor')
  const [isFetchingAbi, setIsFetchingAbi] = useState<Record<string, boolean>>({})
  const [failedAbiFetchIds, setFailedAbiFetchIds] = useState<Set<string>>(new Set())
  const [isDecodingImport, setIsDecodingImport] = useState(false)
  const [decodeErrors, setDecodeErrors] = useState<Record<string, string>>({})
  // Per‑destination LayerZero executor gas limit (encoded into `_options`).
  // Stored as strings so the input stays controllable; parsed to bigint on use.
  // Once the proposal is queued in the timelock these values are frozen, so
  // we surface a warning below if simulated gasUsed approaches them.
  const [lzGasLimits, setLzGasLimits] = useState<Record<string, string>>({})
  const descriptionRef = React.useRef<HTMLTextAreaElement>(null)

  const satelliteChainIds = useMemo(
    () => Array.from(new Set(actions.map((a) => a.chainId).filter((id) => id !== HUB_CHAIN_ID))),
    [actions],
  )

  // Expected sim targets = hub + every chain referenced by an action. Used by
  // the simulation gate so we validate against the chains we *expected*, not
  // just the ones that happened to show up in `results`.
  const expectedChainIds = useMemo(
    () => Array.from(new Set([HUB_CHAIN_ID, ...actions.map((a) => a.chainId)])),
    [actions],
  )

  // Signature of every input that affects encodeProposal's output. Any change
  // invalidates the previous run so the user cannot edit actions after a green
  // simulation and submit with stale results. `abi` must be included because
  // calldata derivation depends on it — without it, an ABI fetched after the
  // sim would change proposal bytes without busting the gate.
  const actionsSignature = useMemo(
    () =>
      JSON.stringify(
        {
          title,
          description,
          actions: actions.map((a) => ({
            chainId: a.chainId,
            target: a.target,
            method: a.method,
            abi: a.abi,
            args: a.args,
            rawCalldata: a.rawCalldata ?? null,
            rawValue: a.rawValue ?? null,
          })),
          lzGasLimits,
        },
        bigIntSafeReplacer,
      ),
    [actions, lzGasLimits, title, description],
  )

  // Signature captured at the last triggerSimulation call. The gate compares
  // it against the live actionsSignature so even within the one-render window
  // before the invalidation effect runs, stale results don't count.
  const lastSimSignatureRef = React.useRef<string | null>(null)

  useEffect(() => {
    setResults({})
    lastSimSignatureRef.current = null
    // intentionally only re-run on actionsSignature change
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [actionsSignature])

  const simulationPassed =
    lastSimSignatureRef.current === actionsSignature &&
    expectedChainIds.every((cid) => results[cid]?.status === 'success')

  interface GasInsight {
    chainId: string
    encodedGas: bigint
    gasUsed?: number
    ratio?: number
    severity: GasSeverityOrIdle
  }

  const gasInsights: GasInsight[] = useMemo(() => {
    return satelliteChainIds.map((cid) => {
      const encodedGas = parseLzGas(lzGasLimits[cid])
      const gasUsed = results[cid]?.gasUsed
      if (gasUsed === undefined || results[cid]?.status !== 'success') {
        return { chainId: cid, encodedGas, severity: 'idle' }
      }
      return {
        chainId: cid,
        encodedGas,
        gasUsed,
        ratio: computeGasRatio(gasUsed, encodedGas),
        severity: computeGasSeverity(gasUsed, encodedGas),
      }
    })
  }, [satelliteChainIds, lzGasLimits, results])

  const worstGasSeverity: GasSeverityOrIdle = worstSeverity(gasInsights.map((i) => i.severity))

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
      const shouldFetch =
        isAddress(action.target) &&
        action.abi.length === 0 &&
        !action.rawCalldata && // Skip ABI fetch for actions with raw calldata (handled by import decoder)
        !isFetchingAbi[action.id] &&
        !failedAbiFetchIds.has(action.id) &&
        action.chainId !== '999' // HyperLiquid not supported for ABI fetching

      if (shouldFetch) {
        setIsFetchingAbi((prev) => ({ ...prev, [action.id]: true }))
        try {
          const res = await fetch(`/api/abi?address=${action.target}&chainId=${action.chainId}`)
          const data = await res.json()
          if (data.abi && data.abi.length > 0) {
            updateAction(action.id, { abi: data.abi })
          } else {
            setFailedAbiFetchIds((prev) => new Set(prev).add(action.id))
          }
        } catch (err) {
          console.error('Failed to fetch ABI:', err)
          setFailedAbiFetchIds((prev) => new Set(prev).add(action.id))
        } finally {
          setIsFetchingAbi((prev) => ({ ...prev, [action.id]: false }))
        }
      }
    })
  }, [actions, isFetchingAbi, failedAbiFetchIds])

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
      {} as Record<string, ProposalAction[]>,
    )

    // 2. Process each chain
    Object.entries(chainGroups).forEach(([chainId, groupActions]) => {
      const isHub = chainId === HUB_CHAIN_ID

      const targets = groupActions.map((a) => a.target as Address)
      const values = groupActions.map((a) => {
        if (a.rawValue) return BigInt(a.rawValue)
        return 0n
      })
      const calldatas = groupActions.map((a) => buildActionCalldata(a))

      if (isHub) {
        hubTargets.push(...targets)
        hubValues.push(...values)
        hubCalldatas.push(...(calldatas as Hex[]))
      } else {
        // Wrap in cross-chain call
        const chainInfo = CHAINS.find((c) => c.id === chainId)
        const eID = chainInfo?.eID
        if (!eID) {
          throw new Error(`Chain ${chainId} not found in CHAINS config`)
        }
        const dstDescription = `SIPX.Y.Z Cross-Chain Actions for ${chainInfo?.name}`
        const lzOptions = constructLzOptions(parseLzGas(lzGasLimits[chainId]))

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

  // --- Import / Export ---
  const fileInputRef = React.useRef<HTMLInputElement>(null)

  interface ProposalJsonCrossChainEntry {
    name: string
    chainId: number
    targets: string[]
    values: string[]
    datas: string[]
  }

  interface ProposalJson {
    title?: string
    description?: string
    targets?: string[]
    values?: string[]
    calldatas?: string[]
    crossChainExecution?: ProposalJsonCrossChainEntry[]
  }

  const handleImportProposal = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = async (e) => {
      try {
        const json = JSON.parse(e.target?.result as string) as ProposalJson
        const importedActions: ProposalAction[] = []

        // Set title and description
        if (json.title) setTitle(json.title)
        if (json.description) setDescription(json.description)

        // Import cross-chain execution entries (per-chain raw actions)
        if (json.crossChainExecution && Array.isArray(json.crossChainExecution)) {
          for (const entry of json.crossChainExecution) {
            const chainInfo = CHAINS.find((c) => c.id === String(entry.chainId))
            const chainId = chainInfo?.id || String(entry.chainId)

            for (let i = 0; i < entry.targets.length; i++) {
              importedActions.push({
                id: Math.random().toString(36).substr(2, 9),
                chainId,
                target: entry.targets[i],
                abi: [],
                method: '',
                args: {},
                isValid: true,
                rawCalldata: entry.datas[i],
                rawValue: entry.values[i],
              })
            }
          }
        }

        // If no cross-chain entries, fall back to top-level targets/values/calldatas (hub actions)
        if (importedActions.length === 0 && json.targets && json.calldatas) {
          for (let i = 0; i < json.targets.length; i++) {
            importedActions.push({
              id: Math.random().toString(36).substr(2, 9),
              chainId: HUB_CHAIN_ID,
              target: json.targets[i],
              abi: [],
              method: '',
              args: {},
              isValid: true,
              rawCalldata: json.calldatas[i],
              rawValue: json.values?.[i] || '0',
            })
          }
        }

        if (importedActions.length > 0) {
          setActions(importedActions)
          setDecodeErrors({})

          // Async: try to fetch ABI and decode each action's raw calldata
          setIsDecodingImport(true)
          const newDecodeErrors: Record<string, string> = {}

          const decodedActions = await Promise.all(
            importedActions.map(async (action) => {
              if (!action.rawCalldata || !isAddress(action.target)) return action

              try {
                // Fetch ABI via the existing API endpoint
                const res = await fetch(
                  `/api/abi?address=${action.target}&chainId=${action.chainId}`,
                )
                const data = await res.json()

                if (!data.abi || data.abi.length === 0) {
                  newDecodeErrors[action.id] =
                    'ABI not found — contract may not be verified on the explorer'
                  return action
                }

                const abi = data.abi as Abi

                // Try to decode the raw calldata against the fetched ABI
                const decoded = decodeFunctionData({
                  abi,
                  data: action.rawCalldata as Hex,
                })

                // Find the matching ABI item to get input names
                const abiItem = (abi as AbiItem[]).find(
                  (item) => item.type === 'function' && item.name === decoded.functionName,
                )

                // Build args map from decoded values
                // Need to recursively convert BigInts to strings for form display
                // (tuples like _sendParam contain nested BigInt values)
                const convertBigInts = (v: unknown): unknown => {
                  if (typeof v === 'bigint') return v.toString()
                  if (Array.isArray(v)) return v.map(convertBigInts)
                  if (typeof v === 'object' && v !== null) {
                    const result: Record<string, unknown> = {}
                    for (const [key, val] of Object.entries(v)) {
                      result[key] = convertBigInts(val)
                    }
                    return result
                  }
                  return v
                }

                const args: Record<string, unknown> = {}
                if (abiItem?.inputs && decoded.args) {
                  abiItem.inputs.forEach((input, idx) => {
                    const val = (decoded.args as unknown[])[idx]
                    args[input.name] = convertBigInts(val)
                  })
                }

                // Successfully decoded — return a fully populated action
                return {
                  ...action,
                  abi: data.abi as AbiItem[],
                  method: decoded.functionName,
                  args,
                  rawCalldata: undefined,
                  isValid: true,
                }
              } catch (err) {
                const message = err instanceof Error ? err.message : 'Unknown decoding error'
                newDecodeErrors[action.id] = `Could not decode calldata: ${message}`
                return action
              }
            }),
          )

          setActions(decodedActions)
          setDecodeErrors(newDecodeErrors)
          setIsDecodingImport(false)
        }
      } catch (err) {
        console.error('Failed to parse proposal JSON:', err)
        alert('Failed to parse proposal JSON. Please check the file format.')
        setIsDecodingImport(false)
      }
    }
    reader.readAsText(file)

    // Reset file input so the same file can be re-imported
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  const handleExportProposal = () => {
    const crossChainExecution: ProposalJsonCrossChainEntry[] = []

    // Group actions by chain
    const chainGroups = actions.reduce(
      (acc, action) => {
        acc[action.chainId] = acc[action.chainId] || []
        acc[action.chainId].push(action)
        return acc
      },
      {} as Record<string, ProposalAction[]>,
    )

    Object.entries(chainGroups).forEach(([chainId, groupActions]) => {
      if (chainId === HUB_CHAIN_ID) return // Hub actions go in top-level

      const chainInfo = CHAINS.find((c) => c.id === chainId)
      crossChainExecution.push({
        name: chainInfo?.key || chainId,
        chainId: Number(chainId),
        targets: groupActions.map((a) => a.target),
        values: groupActions.map((a) => a.rawValue || '0'),
        datas: groupActions.map((a) => {
          if (a.rawCalldata) return a.rawCalldata
          const methodObj = a.abi.find((m) => m.name === a.method)
          if (!methodObj) return '0x'
          return encodeFunctionData({
            abi: [methodObj],
            functionName: a.method,
            args: methodObj.inputs?.map((i) => a.args[i.name]) || [],
          })
        }),
      })
    })

    // Hub actions
    const hubActions = chainGroups[HUB_CHAIN_ID] || []

    const proposalJson = {
      title,
      description,
      targets: hubActions.map((a) => a.target),
      values: hubActions.map((a) => a.rawValue || '0'),
      calldatas: hubActions.map((a) => {
        if (a.rawCalldata) return a.rawCalldata
        const methodObj = a.abi.find((m) => m.name === a.method)
        if (!methodObj) return '0x'
        return encodeFunctionData({
          abi: [methodObj],
          functionName: a.method,
          args: methodObj.inputs?.map((i) => a.args[i.name]) || [],
        })
      }),
      timestamp: Date.now(),
      crossChainExecution: crossChainExecution.length > 0 ? crossChainExecution : undefined,
    }

    const blob = new Blob([JSON.stringify(proposalJson, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `proposal_${new Date().toISOString().replace(/[:.]/g, '-')}.json`
    a.click()
    URL.revokeObjectURL(url)
  }

  // --- Handlers ---
  const addAction = () => {
    setActions([
      ...actions,
      {
        id: Math.random().toString(36).substr(2, 9),
        chainId: HUB_CHAIN_ID,
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

  const updateAction = (id: string, updates: Partial<ProposalAction>) => {
    setActions(actions.map((a) => (a.id === id ? { ...a, ...updates } : a)))
  }

  const handleSimulate = async () => {
    const encoded = encodeProposal()
    const simActions: Action[] = []

    // 1. Add all encoded Hub actions (which includes Base actions + sendProposalToTargetChain calls)
    encoded.targets.forEach((target, i) => {
      simActions.push({
        chainId: HUB_CHAIN_ID,
        target,
        method: 'unknown',
        calldata: encoded.calldatas[i],
        salt: ZERO_BYTES32,
        value: encoded.values[i].toString(),
      })
    })

    // 2. Add raw satellite actions for their direct simulations on their respective chains
    actions.forEach((a) => {
      if (a.chainId !== HUB_CHAIN_ID) {
        simActions.push({
          chainId: a.chainId,
          target: a.target,
          method: a.rawCalldata ? 'raw' : a.method,
          calldata: buildActionCalldata(a),
          salt: ZERO_BYTES32,
          value: a.rawValue || '0',
        })
      }
    })

    // Capture the signature of the inputs we're simulating. simulationPassed
    // only goes true again when the live actionsSignature still matches this.
    lastSimSignatureRef.current = actionsSignature
    await triggerSimulation(simActions)
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
                Submit a proposal to execute actions across the Lazy Summer DAO ecosystem. SIPs can
                include local Hub actions and cross-chain transactions via LayerZero.
              </p>
            </div>

            <div className="flex items-center gap-3">
              {/* Hidden file input for import */}
              <input
                ref={fileInputRef}
                type="file"
                accept=".json"
                onChange={handleImportProposal}
                className="hidden"
              />
              <button
                onClick={() => fileInputRef.current?.click()}
                disabled={isDecodingImport}
                className="flex items-center gap-2 px-4 py-2.5 rounded-xl border border-outline-variant text-on-surface-variant hover:text-primary hover:border-primary/50 hover:bg-primary/5 transition-all font-bold text-sm disabled:opacity-50"
                title="Import proposal from JSON"
              >
                {isDecodingImport ? (
                  <Loader2 className="animate-spin" size={16} />
                ) : (
                  <Upload size={16} />
                )}
                {isDecodingImport ? 'Decoding...' : 'Import'}
              </button>
              <button
                onClick={handleExportProposal}
                className="flex items-center gap-2 px-4 py-2.5 rounded-xl border border-outline-variant text-on-surface-variant hover:text-primary hover:border-primary/50 hover:bg-primary/5 transition-all font-bold text-sm"
                title="Export proposal to JSON"
              >
                <Download size={16} />
                Export
              </button>
              <div className="w-px h-6 bg-outline-variant mx-1" />
              <button
                onClick={handleSimulate}
                disabled={isSimulating || actions.some((a) => !a.method && !a.rawCalldata)}
                className="flex items-center gap-2 px-6 py-2.5 rounded-xl border border-primary/30 text-primary hover:bg-primary/10 transition-all font-bold disabled:opacity-50"
              >
                {isSimulating ? <Loader2 className="animate-spin" size={16} /> : <Play size={16} />}
                Simulate
              </button>
              <button
                onClick={handlePropose}
                disabled={
                  !isEligible || !title || isSubmitting || isSimulating || !simulationPassed
                }
                title={
                  isSimulating
                    ? 'Simulation running…'
                    : !simulationPassed
                      ? lastSimSignatureRef.current !== actionsSignature
                        ? 'Run simulation against the current actions before submitting'
                        : 'Simulation has reverts or errors — fix and re-simulate before submitting'
                      : worstGasSeverity === 'critical'
                        ? 'Warning: simulated gas exceeds encoded _options gas on at least one chain'
                        : worstGasSeverity === 'warning'
                          ? `Warning: less than ${LZ_GAS_HEADROOM_PERCENT}% gas headroom on at least one chain`
                          : undefined
                }
                className={`px-8 py-2.5 rounded-xl font-bold flex items-center gap-2 transition-all active:scale-95 shadow-lg ${
                  isEligible && title && simulationPassed && !isSimulating
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

          {/* Cross-Chain Gas Limits */}
          {satelliteChainIds.length > 0 && (
            <section className="mb-10 space-y-6">
              <div className="flex items-center gap-3">
                <Settings className="text-primary" size={20} />
                <h2 className="text-xl font-bold">LayerZero Gas Limits</h2>
              </div>
              <p className="text-xs text-on-surface-variant max-w-3xl">
                Executor gas limit baked into <code className="font-mono">_options</code> per
                destination. Frozen at queue time — once the proposal is in the timelock you
                can&apos;t bump it. Re-run the simulation after editing.
              </p>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {gasInsights.map((insight) => {
                  const chain = CHAINS.find((c) => c.id === insight.chainId)
                  const severity = insight.severity
                  const badge =
                    severity === 'critical'
                      ? { label: 'OVER LIMIT', className: 'text-error border-error/30 bg-error/10' }
                      : severity === 'warning'
                        ? {
                            label: 'TIGHT',
                            className: 'text-warning border-warning/30 bg-warning/10',
                          }
                        : severity === 'ok'
                          ? {
                              label: 'OK',
                              className: 'text-success border-success/30 bg-success/10',
                            }
                          : {
                              label: 'NOT SIMULATED',
                              className:
                                'text-on-surface-variant border-outline-variant bg-surface-container-low',
                            }
                  const ratioPct =
                    insight.ratio !== undefined
                      ? Number.isFinite(insight.ratio)
                        ? Math.round(insight.ratio * 100)
                        : Infinity
                      : null
                  return (
                    <div
                      key={insight.chainId}
                      className={`p-5 rounded-2xl border bg-surface-container-lowest space-y-3 ${
                        severity === 'critical'
                          ? 'border-error/40'
                          : severity === 'warning'
                            ? 'border-warning/40'
                            : 'border-outline-variant'
                      }`}
                    >
                      <div className="flex items-center justify-between gap-2">
                        <span className="font-bold text-sm">{chain?.name ?? insight.chainId}</span>
                        <span
                          className={`text-[9px] font-black uppercase tracking-widest px-2 py-1 rounded-md border ${badge.className}`}
                        >
                          {badge.label}
                        </span>
                      </div>
                      <label className="block">
                        <span className="text-[10px] font-bold text-on-surface-variant tracking-widest uppercase ml-1">
                          Executor Gas
                        </span>
                        <input
                          type="text"
                          inputMode="numeric"
                          value={lzGasLimits[insight.chainId] ?? DEFAULT_LZ_GAS_LIMIT}
                          onChange={(e) =>
                            setLzGasLimits((prev) => ({
                              ...prev,
                              [insight.chainId]: e.target.value,
                            }))
                          }
                          className="mt-1 w-full bg-surface-container-low border border-outline-variant rounded-xl p-3 text-sm font-mono focus:outline-none focus:ring-1 focus:ring-primary/50 transition-all"
                          placeholder={DEFAULT_LZ_GAS_LIMIT}
                        />
                      </label>
                      <div className="flex justify-between text-[10px] font-medium text-on-surface-variant uppercase tracking-wider">
                        <span>Simulated Gas</span>
                        <span className="font-mono text-on-surface">
                          {insight.gasUsed !== undefined ? insight.gasUsed.toLocaleString() : '—'}
                        </span>
                      </div>
                      {ratioPct !== null && (
                        <div className="flex justify-between text-[10px] font-medium text-on-surface-variant uppercase tracking-wider">
                          <span>Headroom</span>
                          <span
                            className={`font-mono ${
                              severity === 'critical'
                                ? 'text-error'
                                : severity === 'warning'
                                  ? 'text-warning'
                                  : 'text-success'
                            }`}
                          >
                            {ratioPct === Infinity ? '∞' : ratioPct}% used
                          </span>
                        </div>
                      )}
                      {severity === 'critical' && (
                        <p className="text-[10px] text-error">
                          Simulated execution exceeds encoded gas. Raise the limit before
                          submitting.
                        </p>
                      )}
                      {severity === 'warning' && (
                        <p className="text-[10px] text-warning">
                          Less than {LZ_GAS_HEADROOM_PERCENT}% headroom. Consider raising the limit
                          before submitting.
                        </p>
                      )}
                    </div>
                  )
                })}
              </div>
            </section>
          )}

          {/* Simulation Center */}
          <section className="mb-10 space-y-6">
            <div className="flex items-center gap-3">
              <Network className="text-primary" size={20} />
              <h2 className="text-xl font-bold">Simulation Center</h2>
            </div>
            <SimulationCenter
              results={results}
              targetChainIds={Array.from(new Set([HUB_CHAIN_ID, ...actions.map((a) => a.chainId)]))}
            />
          </section>

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
                    placeholder="SIPX.Y.Z: Proposal Title"
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

              <div className="p-5 space-y-8">
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
                                {selectedMethodObj.inputs && selectedMethodObj.inputs.length > 0 ? (
                                  selectedMethodObj.inputs.map((input, idx: number) => (
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

                        {/* Imported raw calldata display (shown when ABI decode failed) */}
                        {action.rawCalldata && (
                          <div className="space-y-4 animate-in fade-in slide-in-from-top-2 duration-300">
                            <div className="flex items-center gap-2 flex-wrap">
                              <FileText size={14} className="text-primary" />
                              <span className="text-[10px] font-bold text-primary tracking-widest uppercase">
                                Imported Raw Calldata
                              </span>
                              {action.rawValue && action.rawValue !== '0' && (
                                <span className="bg-yellow-500/10 text-yellow-500 text-[10px] font-bold px-2 py-0.5 rounded-lg border border-yellow-500/20">
                                  Value: {action.rawValue} wei
                                </span>
                              )}
                            </div>
                            {decodeErrors[action.id] && (
                              <div className="p-3 bg-error/5 border border-error/20 rounded-xl flex items-start gap-2">
                                <AlertCircle size={14} className="text-error/60 mt-0.5 shrink-0" />
                                <p className="text-[11px] text-error/80">
                                  {decodeErrors[action.id]}
                                </p>
                              </div>
                            )}
                            <div className="bg-surface-container-lowest border border-outline-variant rounded-xl p-4 overflow-x-auto">
                              <code className="text-[11px] font-mono text-on-surface-variant break-all leading-relaxed">
                                {action.rawCalldata.slice(0, 10)}
                                <span className="opacity-40">
                                  {action.rawCalldata.slice(10, 74)}...
                                </span>
                              </code>
                              <div className="mt-2 flex items-center gap-2">
                                <span className="text-[9px] text-on-surface-variant/40">
                                  {action.rawCalldata.length} chars
                                </span>
                                <button
                                  onClick={() => {
                                    navigator.clipboard.writeText(action.rawCalldata || '')
                                  }}
                                  className="text-[9px] text-primary hover:text-primary-fixed transition-colors"
                                >
                                  Copy full calldata
                                </button>
                              </div>
                            </div>
                          </div>
                        )}

                        {action.abi.length === 0 &&
                          !isFetchingAbi[action.id] &&
                          !action.rawCalldata &&
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

                        {(!action.target || !isAddress(action.target)) && !action.rawCalldata && (
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
