import { type DvnMetadata, lookupDvn } from '../hooks/useDvnMetadata'
import type {
  ChainName,
  DesiredRouteConfig,
  OAppAdminState,
  OnChainRouteConfig,
  Recommendation,
  UlnConfig,
} from './types'

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

function isZeroAddr(a: string | null | undefined): boolean {
  return !a || a.toLowerCase() === ZERO_ADDRESS
}

function dvnsEqualCI(a: readonly string[] | undefined, b: readonly string[] | undefined) {
  if (!a || !b) return false
  if (a.length !== b.length) return false
  const x = [...a].map((s) => s.toLowerCase()).sort()
  const y = [...b].map((s) => s.toLowerCase()).sort()
  return x.every((v, i) => v === y[i])
}

function ulnEqual(a: UlnConfig | null, b: UlnConfig | null): boolean {
  if (!a || !b) return false
  return (
    a.confirmations === b.confirmations &&
    a.requiredDVNCount === b.requiredDVNCount &&
    a.optionalDVNCount === b.optionalDVNCount &&
    a.optionalDVNThreshold === b.optionalDVNThreshold &&
    dvnsEqualCI(a.requiredDVNs as readonly string[], b.requiredDVNs as readonly string[]) &&
    dvnsEqualCI(a.optionalDVNs as readonly string[], b.optionalDVNs as readonly string[])
  )
}

export interface EvaluateInput {
  sourceChain: ChainName
  desired: DesiredRouteConfig | null
  onChain: OnChainRouteConfig | null
  admin: OAppAdminState | null
  dvnMetadata: DvnMetadata | undefined
}

export function evaluateRoute({
  sourceChain,
  desired,
  onChain,
  admin,
  dvnMetadata,
}: EvaluateInput): Recommendation[] {
  const recs: Recommendation[] = []

  // 1. Peer set
  if (onChain && (!onChain.peerBytes32 || /^0x0+$/.test(onChain.peerBytes32))) {
    recs.push({ id: 'peer-unset', severity: 'error', message: 'Peer is not set on this route.' })
  }

  // 2. Owner not zero
  if (admin && isZeroAddr(admin.owner)) {
    recs.push({ id: 'owner-zero', severity: 'error', message: 'OApp owner is the zero address.' })
  }

  // 3. Delegate
  if (admin) {
    if (isZeroAddr(admin.delegate)) {
      recs.push({
        id: 'delegate-zero',
        severity: 'warn',
        message: 'Delegate is unset — only the owner can update LZ configuration.',
      })
    } else if (
      admin.owner &&
      admin.delegate &&
      admin.owner.toLowerCase() === admin.delegate.toLowerCase()
    ) {
      recs.push({
        id: 'delegate-equals-owner',
        severity: 'info',
        message:
          'Delegate equals owner. Consider setting a dedicated operations Safe so DVN updates do not require a governance proposal.',
      })
    }
  }

  // 4. Libraries explicitly set
  if (onChain && desired) {
    if (!onChain.sendLib) {
      recs.push({
        id: 'send-lib-default',
        severity: 'warn',
        message: 'Send library uses the endpoint default. Pin explicitly via setSendLibrary.',
      })
    }
    if (!onChain.receiveLib) {
      recs.push({
        id: 'receive-lib-default',
        severity: 'warn',
        message:
          'Receive library uses the endpoint default. Pin explicitly via setReceiveLibrary.',
      })
    }
  }

  // 5/6. DVN count + deprecated DVNs (against on-chain config)
  for (const which of ['sendUln', 'receiveUln'] as const) {
    const u = onChain?.[which]
    if (!u) continue
    const totalCovered = u.requiredDVNCount + Math.min(u.optionalDVNCount, u.optionalDVNThreshold)
    if (u.requiredDVNCount < 2 && u.optionalDVNThreshold < 1) {
      recs.push({
        id: `${which}-low-dvn`,
        severity: 'error',
        message: `${which === 'sendUln' ? 'Send' : 'Receive'} ULN has fewer than 2 attesting DVNs (required=${u.requiredDVNCount}, optionalThreshold=${u.optionalDVNThreshold}).`,
      })
    } else if (totalCovered < 2) {
      recs.push({
        id: `${which}-thin`,
        severity: 'warn',
        message: `${which === 'sendUln' ? 'Send' : 'Receive'} ULN attesting set is thin — only ${totalCovered} DVN(s) need to attest.`,
      })
    }

    if (dvnMetadata) {
      const all = [...u.requiredDVNs, ...u.optionalDVNs]
      const deprecatedNames: string[] = []
      for (const addr of all) {
        const info = lookupDvn(dvnMetadata, sourceChain, addr as string)
        if (info?.deprecated) {
          deprecatedNames.push(`${info.canonicalName} (${addr})`)
        }
      }
      if (deprecatedNames.length > 0) {
        recs.push({
          id: `${which}-deprecated`,
          severity: 'error',
          message: `${which === 'sendUln' ? 'Send' : 'Receive'} ULN contains deprecated DVN(s): ${deprecatedNames.join(', ')}`,
        })
      }
    }
  }

  // 7. Send vs Receive must match
  if (onChain?.sendUln && onChain.receiveUln && !ulnEqual(onChain.sendUln, onChain.receiveUln)) {
    recs.push({
      id: 'send-receive-mismatch',
      severity: 'warn',
      message:
        'Send ULN config differs from Receive ULN config. LayerZero recommends matching settings across the pathway.',
    })
  }

  // 8. Enforced options
  if (onChain?.enforced) {
    const sendEmpty = !onChain.enforced.send || onChain.enforced.send === '0x'
    const sendAndCallEmpty = !onChain.enforced.sendAndCall || onChain.enforced.sendAndCall === '0x'
    if (sendEmpty && sendAndCallEmpty) {
      recs.push({
        id: 'enforced-options-missing',
        severity: 'warn',
        message:
          'No enforced options set for SEND or SEND_AND_CALL. Users may submit underfunded messages.',
      })
    } else if (sendEmpty) {
      recs.push({
        id: 'enforced-send-empty',
        severity: 'warn',
        message: 'No enforced options set for SEND (msgType 1).',
      })
    } else if (sendAndCallEmpty) {
      recs.push({
        id: 'enforced-send-and-call-empty',
        severity: 'warn',
        message: 'No enforced options set for SEND_AND_CALL (msgType 2).',
      })
    }
  }

  // 9. Confirmation floor (EVM)
  if (onChain?.sendUln && Number(onChain.sendUln.confirmations) < 15) {
    recs.push({
      id: 'confirmations-low',
      severity: 'info',
      message: `Send ULN confirmations = ${onChain.sendUln.confirmations}. LayerZero recommends >= 15 for EVM source chains.`,
    })
  }

  // sort: error → warn → info
  const order = { error: 0, warn: 1, info: 2 }
  return recs.sort((a, b) => order[a.severity] - order[b.severity])
}
