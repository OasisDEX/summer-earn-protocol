import type { Address } from 'viem'

import type { PendingEdit } from './types'

export type EditAuthRequirement = 'delegate-or-owner' | 'owner-only'

export function authRequirementFor(edit: PendingEdit): EditAuthRequirement {
  switch (edit.kind) {
    case 'setSendConfig':
    case 'setReceiveConfig':
    case 'setSendLibrary':
    case 'setReceiveLibrary':
      return 'delegate-or-owner'
    case 'setPeer':
    case 'setDelegate':
    case 'setEnforcedOptions':
      return 'owner-only'
  }
}

function sameAddrCI(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!a || !b) return false
  return a.toLowerCase() === b.toLowerCase()
}

export function canConnectedWalletSubmit(
  edit: PendingEdit,
  connected: Address | undefined,
  owner: Address | null | undefined,
  delegate: Address | null | undefined,
): boolean {
  if (!connected) return false
  const req = authRequirementFor(edit)
  if (req === 'owner-only') return sameAddrCI(connected, owner)
  // delegate-or-owner
  return sameAddrCI(connected, delegate) || sameAddrCI(connected, owner)
}
