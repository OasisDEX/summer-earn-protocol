import { dataSource } from '@graphprotocol/graph-ts'
import { DelegateChanged, DelegateVotesChanged } from '../../generated/SummerGovernanceToken/Votes'
import { getOrCreateDelegate } from '../initializers'
import { isHub } from '../utils/chain'

export function handleDelegateChanged(event: DelegateChanged): void {
  if (!isHub(dataSource.network())) {
    return
  }

  const fromDelegateAddr = event.params.fromDelegate.toHexString()
  const toDelegateAddr = event.params.toDelegate.toHexString()

  // Use a constant for the zero address for better readability
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

  if (fromDelegateAddr != ZERO_ADDRESS) {
    const fromDelegate = getOrCreateDelegate(fromDelegateAddr)
    if (fromDelegate.delegationsCount > 0) {
      fromDelegate.delegationsCount = fromDelegate.delegationsCount - 1
    }
    fromDelegate.save()
  }

  if (toDelegateAddr != ZERO_ADDRESS) {
    const toDelegate = getOrCreateDelegate(toDelegateAddr)
    toDelegate.delegationsCount = toDelegate.delegationsCount + 1
    toDelegate.save()
  }
}

export function handleDelegateVotesChanged(event: DelegateVotesChanged): void {
  if (!isHub(dataSource.network())) {
    return
  }

  const delegateAddr = event.params.delegate.toHexString()
  const delegate = getOrCreateDelegate(delegateAddr)

  delegate.votingPower = event.params.newVotes
  delegate.save()
}
