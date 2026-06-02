import { encodeFunctionData, keccak256 } from 'viem'

import { COMBINED_ABI } from '@/config/abis/combined'
import config from '@/config/index.json'
import {
  addresToContractName,
  CANCELLER_ROLE,
  decodeAddress,
  decodeCalldata,
  decodeCrossChainCalldata,
  DEFAULT_ADMIN_ROLE,
  EXECUTOR_ROLE,
  getRoleTags,
  isCrossChainExecution,
  PROPOSER_ROLE,
  SupportedNetworks,
  validateCalldatas,
  validateTargets,
  validateValues,
  WAD,
} from '@/services/validation'

const cfg = config as Record<string, any>
const BASE_USDC = cfg.base.tokens.usdc as string
// govV2 summerGovernor is recognized by isCrossChainExecution
const BASE_GOVERNOR_V2 = cfg.base.deployedContracts.govV2.summerGovernor.address as string
// govV1 summerGovernor also recognized
const BASE_GOVERNOR_V1 = cfg.base.deployedContracts.gov.summerGovernor.address as string
const ZERO_ADDR = '0x0000000000000000000000000000000000000000'
const UNKNOWN_ADDR = '0x1234567890123456789012345678901234567890'

// ---------------------------------------------------------------------------
// role + math constants
// ---------------------------------------------------------------------------

describe('role + math constants', () => {
  it('exposes the canonical role hashes', () => {
    expect(PROPOSER_ROLE).toBe(keccak256(new TextEncoder().encode('PROPOSER_ROLE')))
    expect(EXECUTOR_ROLE).toBe(keccak256(new TextEncoder().encode('EXECUTOR_ROLE')))
    expect(CANCELLER_ROLE).toBe(keccak256(new TextEncoder().encode('CANCELLER_ROLE')))
    expect(DEFAULT_ADMIN_ROLE).toBe(`0x${'0'.repeat(64)}`)
  })
  it('exposes WAD as 10^18', () => {
    expect(WAD).toBe(10n ** 18n)
  })
})

// ---------------------------------------------------------------------------
// getRoleTags
// ---------------------------------------------------------------------------

describe('getRoleTags', () => {
  it('returns empty when roleInfo is undefined', () => {
    expect(getRoleTags('0x', undefined)).toEqual([])
  })
  it('returns empty when no roles are set', () => {
    expect(getRoleTags('0x', {})).toEqual([])
  })
  it('returns PROPOSER tag when proposer is true', () => {
    expect(getRoleTags('0x', { proposer: true })).toEqual(['PROPOSER'])
  })
  it('returns EXECUTOR tag when executor is true', () => {
    expect(getRoleTags('0x', { executor: true })).toEqual(['EXECUTOR'])
  })
  it('returns CANCELLER tag when canceller is true', () => {
    expect(getRoleTags('0x', { canceller: true })).toEqual(['CANCELLER'])
  })
  it('returns all three tags in canonical order when all true', () => {
    expect(getRoleTags('0x', { proposer: true, executor: true, canceller: true })).toEqual([
      'PROPOSER',
      'EXECUTOR',
      'CANCELLER',
    ])
  })
})

// ---------------------------------------------------------------------------
// addresToContractName
// ---------------------------------------------------------------------------

describe('addresToContractName', () => {
  it('resolves a known token under tokens.*', () => {
    // BASE_USDC is stored under tokens.usdc → returns "token.usdc"
    expect(addresToContractName(BASE_USDC, SupportedNetworks.BASE)).toBe('token.usdc')
  })
  it('resolves govV2 summerGovernor under deployedContracts', () => {
    // deployedContracts.govV2.summerGovernor → category="govV2", name="summerGovernor"
    // lowercased → "govv2.summergovernor"
    expect(addresToContractName(BASE_GOVERNOR_V2, SupportedNetworks.BASE)).toBe(
      'govv2.summergovernor',
    )
  })
  it('returns "unknown" for an unknown address', () => {
    expect(addresToContractName(UNKNOWN_ADDR, SupportedNetworks.BASE)).toBe('unknown')
  })
  it('matches case-insensitively (upper-cased input)', () => {
    expect(addresToContractName(BASE_USDC.toUpperCase(), SupportedNetworks.BASE)).toBe('token.usdc')
  })
})

// ---------------------------------------------------------------------------
// decodeAddress
// ---------------------------------------------------------------------------

describe('decodeAddress', () => {
  it('returns network-prefixed name for a known token address', () => {
    const result = decodeAddress(BASE_USDC, SupportedNetworks.BASE)
    expect(result.address).toBe(BASE_USDC)
    expect(result.name).toBe(`${SupportedNetworks.BASE}:token.usdc`)
    expect(result.explorerUrl).toBe(`https://basescan.org/address/${BASE_USDC}`)
  })
  it('returns "unknown" name (no network prefix) for an unknown address', () => {
    // Source: name !== 'unknown' → `${targetNetwork}:${name}`, else → 'unknown'
    expect(decodeAddress(UNKNOWN_ADDR, SupportedNetworks.BASE).name).toBe('unknown')
  })
  it('defaults to Base network when no network arg provided', () => {
    expect(decodeAddress(BASE_USDC).explorerUrl).toBe(`https://basescan.org/address/${BASE_USDC}`)
  })
  it('uses the mainnet explorer URL when network=MAINNET', () => {
    expect(decodeAddress(UNKNOWN_ADDR, SupportedNetworks.MAINNET).explorerUrl).toBe(
      `https://etherscan.io/address/${UNKNOWN_ADDR}`,
    )
  })
  it('uses the Arbitrum explorer URL when network=ARBITRUM', () => {
    expect(decodeAddress(UNKNOWN_ADDR, SupportedNetworks.ARBITRUM).explorerUrl).toBe(
      `https://arbiscan.io/address/${UNKNOWN_ADDR}`,
    )
  })
  it('uses the Sonic explorer URL when network=SONIC', () => {
    expect(decodeAddress(UNKNOWN_ADDR, SupportedNetworks.SONIC).explorerUrl).toBe(
      `https://sonicscan.org/address/${UNKNOWN_ADDR}`,
    )
  })
})

// ---------------------------------------------------------------------------
// decodeCalldata
// ---------------------------------------------------------------------------

describe('decodeCalldata', () => {
  it('round-trips an ERC20 transfer, returning functionName and paramNames', () => {
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'transfer',
      args: [UNKNOWN_ADDR, 1_000_000n],
    })
    const decoded = decodeCalldata(data, BASE_USDC, SupportedNetworks.BASE)
    expect(decoded).not.toBeNull()
    expect(decoded!.functionName).toBe('transfer')
    expect(decoded!.paramNames).toEqual(['to', 'amount'])
  })

  it('formats transfer amount with USDC decimals (6) when target is BASE_USDC', () => {
    // 1_000_000 raw units at 6 decimals = 1.0 USDC
    // format: "${bigint} [formatted:${formatted} USDC]"
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'transfer',
      args: [UNKNOWN_ADDR, 1_000_000n],
    })
    const decoded = decodeCalldata(data, BASE_USDC, SupportedNetworks.BASE)
    expect(decoded).not.toBeNull()
    const amountStr = String(decoded!.args[1])
    expect(amountStr).toMatch(/1000000 \[formatted:1 USDC\]/)
  })

  it('falls back to "Tokens:fallback" when target address is unknown (18 decimals)', () => {
    // Unknown target → currentUsedFallback = true, currentTokenSymbol = 'Tokens'
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'transfer',
      args: [UNKNOWN_ADDR, 10n ** 18n],
    })
    const decoded = decodeCalldata(data, UNKNOWN_ADDR, SupportedNetworks.BASE)
    expect(decoded).not.toBeNull()
    const amountStr = String(decoded!.args[1])
    expect(amountStr).toMatch(/Tokens:fallback/)
  })

  it('returns null when the calldata cannot be decoded against COMBINED_ABI', () => {
    expect(decodeCalldata('0xdeadbeef')).toBeNull()
  })

  it('decodes grantRole, formatting the bytes32 role hash', () => {
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'grantRole',
      args: [PROPOSER_ROLE as `0x${string}`, UNKNOWN_ADDR],
    })
    const decoded = decodeCalldata(data, UNKNOWN_ADDR, SupportedNetworks.BASE)
    expect(decoded).not.toBeNull()
    expect(decoded!.functionName).toBe('grantRole')
    // role arg should be decoded as "PROPOSER_ROLE (0x...)"
    expect(String(decoded!.args[0])).toMatch(/PROPOSER_ROLE/)
  })

  it('decodes setTipRate with Percentage internalType', () => {
    // setTipRate has a uint256 with internalType: 'Percentage'
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'setTipRate',
      args: [WAD / 10n], // 10% expressed as WAD/10
    })
    const decoded = decodeCalldata(data)
    expect(decoded).not.toBeNull()
    expect(decoded!.functionName).toBe('setTipRate')
    // Should contain a percentage representation
    expect(String(decoded!.args[0])).toMatch(/%/)
  })

  it('decodes addTipStream with a tuple containing Percentage allocation', () => {
    // addTipStream has a tuple with internalType: 'struct ITipJar.TipStream'
    // and allocation field has internalType: 'Percentage'
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'addTipStream',
      args: [
        {
          recipient: UNKNOWN_ADDR,
          allocation: WAD / 10n,
          lockedUntilEpoch: 0n,
        },
      ],
    })
    const decoded = decodeCalldata(data)
    expect(decoded).not.toBeNull()
    expect(decoded!.functionName).toBe('addTipStream')
  })

  it('decodes notifyRewardAmount where reward param triggers amount formatting', () => {
    // notifyRewardAmount has params: (address rewardToken, uint256 reward, uint256 newRewardsDuration)
    // "reward" param name triggers amount formatting
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'notifyRewardAmount',
      args: [BASE_USDC, 1_000_000n, 604800n],
    })
    const decoded = decodeCalldata(data, BASE_USDC, SupportedNetworks.BASE)
    expect(decoded).not.toBeNull()
    expect(decoded!.functionName).toBe('notifyRewardAmount')
    // "rewardToken" param is an address named with "reward" so it updates context
    // "reward" param is uint256 named "reward" → triggers formatting
    expect(String(decoded!.args[1])).toMatch(/formatted/)
  })

  it('decodes approve with "amount" param', () => {
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'approve',
      args: [UNKNOWN_ADDR, 500_000n],
    })
    const decoded = decodeCalldata(data, BASE_USDC, SupportedNetworks.BASE)
    expect(decoded).not.toBeNull()
    expect(decoded!.functionName).toBe('approve')
    expect(String(decoded!.args[1])).toMatch(/500000 \[formatted:/)
  })

  it('updates context to SUMMER when target is gov.summerToken address', () => {
    // gov.summerToken → addresToContractName → "gov.summertoken" → updateContextFromAddress
    // sets currentTokenSymbol = 'SUMMER', currentUsedFallback = false
    const SUMMER_TOKEN = cfg.base.deployedContracts.gov.summerToken.address as string
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'transfer',
      args: [UNKNOWN_ADDR, WAD],
    })
    const decoded = decodeCalldata(data, SUMMER_TOKEN, SupportedNetworks.BASE)
    expect(decoded).not.toBeNull()
    expect(String(decoded!.args[1])).toMatch(/SUMMER/)
    expect(String(decoded!.args[1])).not.toMatch(/:fallback/)
  })

  it('updates context to fleet shares when target is a FleetCommander address', () => {
    // FleetModule_LazyVault_LowerRisk_USDC#FleetCommander in deployed/base.json
    // name includes 'fleetcommander' and 'usdc' → sets decimals=6, symbol includes 'shares'
    const FC_USDC = '0x98C49e13bf99D7CAd8069faa2A370933EC9EcF17' // base USDC FleetCommander
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'transfer',
      args: [UNKNOWN_ADDR, 1_000_000n],
    })
    const decoded = decodeCalldata(data, FC_USDC, SupportedNetworks.BASE)
    expect(decoded).not.toBeNull()
    // Should use 6 decimals (usdc) and symbol derived from fleet name
    expect(String(decoded!.args[1])).toMatch(/formatted:1/)
    expect(String(decoded!.args[1])).not.toMatch(/:fallback/)
  })

  it('resolves a common-section address via addresToContractName', () => {
    // base.common.foundation → returns "foundation" (line 161 branch)
    const FOUNDATION = cfg.base.common.foundation as string
    expect(addresToContractName(FOUNDATION, SupportedNetworks.BASE)).toBe('foundation')
  })

  it('resolves a deployed-only address (not in deployedContracts or tokens)', () => {
    // CoreModule#DutchAuctionLibrary only exists in deployed/base.json, not in index.json
    // exercises line 180 (return from deployedAddresses loop)
    const DUTCH_AUCTION = '0x7EE9e86b6718863B52fb1f91366935d6bDC1aA8e'
    const result = addresToContractName(DUTCH_AUCTION, SupportedNetworks.BASE)
    // Returns lowercase key from deployed JSON
    expect(result).not.toBe('unknown')
    expect(result.toLowerCase()).toContain('dutchauction')
  })

  it('decodes sweep with address[] arg, exercising the array processArg branch', () => {
    // sweep(address ark, address[] tokens) has an array param
    // This exercises lines 308-311 (Array.isArray branch in processArg)
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'sweep',
      args: [UNKNOWN_ADDR, [BASE_USDC, UNKNOWN_ADDR]],
    })
    const decoded = decodeCalldata(data, UNKNOWN_ADDR, SupportedNetworks.BASE)
    expect(decoded).not.toBeNull()
    expect(decoded!.functionName).toBe('sweep')
    // tokens arg is an array → processArg returns array
    expect(Array.isArray(decoded!.args[1])).toBe(true)
    expect((decoded!.args[1] as any[]).length).toBe(2)
  })
})

// ---------------------------------------------------------------------------
// decodeCrossChainCalldata
// ---------------------------------------------------------------------------

describe('decodeCrossChainCalldata', () => {
  it('round-trips a sendProposalToTargetChain call into its component fields', () => {
    const options = '0x0003010011010000000000000000000000000007a120' as const
    const calldata = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'sendProposalToTargetChain',
      args: [30110, [UNKNOWN_ADDR], [0n], ['0x'], `0x${'a'.repeat(64)}` as `0x${string}`, options],
    })
    const decoded = decodeCrossChainCalldata(calldata)
    expect(decoded).not.toBeNull()
    // dstEid is the network string, not the numeric eid
    // dstEidToChainIdMap['30110'] = SupportedNetworks.ARBITRUM = 'arbitrum'
    expect(decoded!.dstEid).toBe(SupportedNetworks.ARBITRUM)
    expect(decoded!.dstTargets[0]).toBe(UNKNOWN_ADDR.toLowerCase())
    expect(decoded!.dstValues[0]).toBe('0')
    expect(decoded!.options).toBe(options)
  })

  it('includes formattedProposals in the output', () => {
    const options = '0x0003010011010000000000000000000000000007a120' as const
    const calldata = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'sendProposalToTargetChain',
      args: [30110, [UNKNOWN_ADDR], [0n], ['0x'], `0x${'a'.repeat(64)}` as `0x${string}`, options],
    })
    const decoded = decodeCrossChainCalldata(calldata)
    expect(decoded).not.toBeNull()
    expect(Array.isArray(decoded!.formattedProposals)).toBe(true)
    expect(decoded!.formattedProposals![0].target).toBe(UNKNOWN_ADDR.toLowerCase())
    expect(decoded!.formattedProposals![0].value).toBe('0')
  })

  it('returns null when calldata is not a sendProposalToTargetChain call', () => {
    const calldata = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'transfer',
      args: [UNKNOWN_ADDR, 1n],
    })
    expect(decodeCrossChainCalldata(calldata)).toBeNull()
  })

  it('returns null for garbage input', () => {
    expect(decodeCrossChainCalldata('0xdeadbeef')).toBeNull()
  })
})

// ---------------------------------------------------------------------------
// validateTargets
// ---------------------------------------------------------------------------

describe('validateTargets', () => {
  it('flags empty target slots', () => {
    const r = validateTargets([''])
    expect(r.isValid).toBe(false)
    expect(r.errors[0]).toMatch(/empty/i)
    // Source line 475: contractNames[index] = 'unknown'
    expect(r.contractNames[0]).toBe('unknown')
  })

  it('flags malformed addresses (not 0x + 40 hex chars)', () => {
    const r = validateTargets(['nothex'])
    expect(r.isValid).toBe(false)
    expect(r.errors[0]).toMatch(/not a valid Ethereum address/i)
    expect(r.contractNames[0]).toBe('Invalid')
  })

  it('accepts a known token address and labels it with network prefix and address', () => {
    const r = validateTargets([BASE_USDC], SupportedNetworks.BASE)
    expect(r.isValid).toBe(true)
    // Source: `${network}:${contractName}(${normalizedTarget})`
    expect(r.contractNames[0]).toMatch(/base:token\.usdc/)
  })

  it('flags an unknown address not present in the network config', () => {
    const r = validateTargets([UNKNOWN_ADDR], SupportedNetworks.BASE)
    expect(r.isValid).toBe(false)
    expect(r.errors[0]).toMatch(/not a known contract address/i)
  })

  it('defaults to BASE network when no network arg provided', () => {
    const r = validateTargets([BASE_USDC])
    expect(r.isValid).toBe(true)
    expect(r.contractNames[0]).toMatch(/base:token\.usdc/)
  })

  it('handles multiple targets with mixed validity', () => {
    const r = validateTargets([BASE_USDC, UNKNOWN_ADDR], SupportedNetworks.BASE)
    expect(r.isValid).toBe(false)
    expect(r.errors).toHaveLength(1)
    expect(r.contractNames[0]).toMatch(/base:token\.usdc/)
  })
})

// ---------------------------------------------------------------------------
// validateValues
// ---------------------------------------------------------------------------

describe('validateValues', () => {
  it('accepts non-negative numeric strings', () => {
    expect(validateValues(['0', '1', '100']).isValid).toBe(true)
  })

  it('flags empty values', () => {
    const r = validateValues([''])
    expect(r.isValid).toBe(false)
    expect(r.errors[0]).toMatch(/empty/i)
  })

  it('flags non-numeric values', () => {
    const r = validateValues(['not-a-number'])
    expect(r.isValid).toBe(false)
    expect(r.errors[0]).toMatch(/not a valid number/i)
  })

  it('flags negative values', () => {
    const r = validateValues(['-1'])
    expect(r.isValid).toBe(false)
    expect(r.errors[0]).toMatch(/negative/i)
  })

  it('returns empty contractNames array', () => {
    expect(validateValues(['1']).contractNames).toEqual([])
  })
})

// ---------------------------------------------------------------------------
// validateCalldatas
// ---------------------------------------------------------------------------

describe('validateCalldatas', () => {
  it('accepts a valid calldata that decodes against COMBINED_ABI', () => {
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'transfer',
      args: [UNKNOWN_ADDR, 1n],
    })
    expect(validateCalldatas([data]).isValid).toBe(true)
  })

  it('flags empty calldata', () => {
    const r = validateCalldatas([''])
    expect(r.isValid).toBe(false)
    expect(r.errors[0]).toMatch(/empty/i)
  })

  it("flags missing '0x' prefix", () => {
    const r = validateCalldatas(['deadbeef'])
    expect(r.isValid).toBe(false)
    expect(r.errors[0]).toMatch(/must start with '0x'/i)
  })

  it('flags non-hex characters', () => {
    const r = validateCalldatas(['0xZZZZ'])
    expect(r.isValid).toBe(false)
    expect(r.errors[0]).toMatch(/invalid hex characters/i)
  })

  it('flags calldata that cannot be decoded with COMBINED_ABI', () => {
    const r = validateCalldatas(['0xdeadbeef'])
    expect(r.isValid).toBe(false)
    expect(r.errors[0]).toMatch(/could not be decoded/i)
  })

  it('accepts just 0x (empty calldata body) as valid hex but fails decode', () => {
    // '0x' passes hex check but decodeFunctionData will throw
    const r = validateCalldatas(['0x'])
    expect(r.isValid).toBe(false)
    expect(r.errors[0]).toMatch(/could not be decoded/i)
  })
})

// ---------------------------------------------------------------------------
// isCrossChainExecution
// ---------------------------------------------------------------------------

describe('isCrossChainExecution', () => {
  const buildXchainData = () =>
    encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'sendProposalToTargetChain',
      args: [
        30110,
        [UNKNOWN_ADDR],
        [0n],
        ['0x'],
        `0x${'a'.repeat(64)}` as `0x${string}`,
        '0x0003010011010000000000000000000000000007a120' as `0x${string}`,
      ],
    })

  it('returns true for sendProposalToTargetChain selector + govV2 governor target (base)', () => {
    // BASE_GOVERNOR_V2 is recognized by checking deployedContracts.govV2.summerGovernor
    expect(isCrossChainExecution(BASE_GOVERNOR_V2, buildXchainData())).toBe(true)
  })

  it('returns true for sendProposalToTargetChain selector + govV1 governor target (base)', () => {
    // BASE_GOVERNOR_V1 is recognized by checking deployedContracts.gov.summerGovernor
    expect(isCrossChainExecution(BASE_GOVERNOR_V1, buildXchainData())).toBe(true)
  })

  it('returns false when the target is not a known governor (zero address)', () => {
    expect(isCrossChainExecution(ZERO_ADDR, buildXchainData())).toBe(false)
  })

  it('returns false when the target is not a known governor (random address)', () => {
    expect(isCrossChainExecution(UNKNOWN_ADDR, buildXchainData())).toBe(false)
  })

  it('returns false when the selector is not sendProposalToTargetChain', () => {
    const data = encodeFunctionData({
      abi: COMBINED_ABI,
      functionName: 'transfer',
      args: [UNKNOWN_ADDR, 1n],
    })
    expect(isCrossChainExecution(BASE_GOVERNOR_V2, data)).toBe(false)
  })

  it('returns false on malformed/empty calldata', () => {
    expect(isCrossChainExecution(BASE_GOVERNOR_V2, '0x')).toBe(false)
  })
})
