'use client'

import { useMemo, useState } from 'react'
import { useAccount } from 'wagmi'

import { RoundStateBadge } from '@/components/rounds/RoundStateBadge'
import { AmountInput } from '@/components/ui/AmountInput'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { Field } from '@/components/ui/Field'
import { Pill } from '@/components/ui/Pill'
import type { Institution, InstitutionFleet } from '@/config/institutions'
import { useAccess } from '@/hooks/useAccess'
import { useErc20Approval } from '@/hooks/useErc20Approval'
import { useRoundsActions } from '@/hooks/useRoundsActions'
import { useRoundsVaultState } from '@/hooks/useRoundsVaultState'
import { useTokenAllowance } from '@/hooks/useTokenAllowance'
import { formatDecimalOutput, MAX_UINT256, parseDecimalInput } from '@/lib/format'

interface Props {
  institution: Institution
  fleet: InstitutionFleet
  /** Address of the rounds-vault to deposit into (Input or Output). */
  roundsVaultAddress: `0x${string}`
  /** Underlying ERC20 the user spends. Input: USDC. Output: FleetCommander shares. */
  depositToken: `0x${string}`
  /** Display copy customised per Input/Output. */
  title: string
  description: string
}

export function DepositForm({
  institution,
  fleet,
  roundsVaultAddress,
  depositToken,
  title,
  description,
}: Props) {
  const { address } = useAccount()
  const access = useAccess({ institution, fleet, account: address })
  const { currentRound, roundState, minPositionSize } = useRoundsVaultState({
    roundsVaultAddress,
    chainId: institution.chainId,
  })
  const { decimals, symbol, balance, allowance, refetch } = useTokenAllowance({
    token: depositToken,
    owner: address,
    spender: roundsVaultAddress,
    chainId: institution.chainId,
  })
  const approval = useErc20Approval({
    token: depositToken,
    spender: roundsVaultAddress,
    chainId: institution.chainId,
    symbol,
  })
  const actions = useRoundsActions({
    roundsVaultAddress,
    chainId: institution.chainId,
    owner: address,
  })

  const [amount, setAmount] = useState('')
  const parsedAmount = useMemo(() => parseDecimalInput(amount, decimals ?? 18), [amount, decimals])

  const isOpen = roundState === 'OPENED'
  const isAllowed = access.isDepositorWhitelisted
  const insufficientBalance = balance !== undefined && parsedAmount > balance
  const belowMin =
    minPositionSize !== undefined && minPositionSize > 0n && parsedAmount < minPositionSize
  const needsApproval = allowance !== undefined && parsedAmount > 0n && allowance < parsedAmount

  async function onApprove() {
    await approval.approve(MAX_UINT256)
    await refetch()
  }

  async function onDeposit() {
    if (!address) return
    await actions.deposit(parsedAmount, address)
    setAmount('')
    await refetch()
  }

  return (
    <Card>
      <div className="flex items-center justify-between">
        <div>
          <h2 className="h2">{title}</h2>
          <p className="mt-1 text-sm text-[var(--text-3)]">{description}</p>
        </div>
        <RoundStateBadge state={roundState} />
      </div>

      <div className="mt-6 text-xs text-[var(--text-3)]">
        Current round{' '}
        <span className="font-mono text-[var(--text)]">{currentRound?.toString() ?? '—'}</span>
      </div>

      {!address ? (
        <div className="mt-6 rounded-md border border-dashed border-[var(--border)] p-4 text-sm text-[var(--text-2)]">
          Connect your wallet to continue.
        </div>
      ) : !isAllowed ? (
        <div className="mt-6 rounded-md border border-dashed border-[var(--warning)] p-4 text-sm text-[var(--warning)]">
          This wallet is not on the institution whitelist for this fleet. Contact your institution
          administrator to be added (or wait for the whitelist manager to call{' '}
          <span className="font-mono">setWhitelisted</span>).
        </div>
      ) : (
        <div className="mt-6 space-y-4">
          <Field
            label={`Amount (${symbol ?? ''})`}
            hint={
              balance !== undefined && decimals !== undefined
                ? `Wallet balance: ${formatDecimalOutput(balance, decimals)} ${symbol ?? ''}`
                : undefined
            }
          >
            <AmountInput
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0"
              suffix={<span className="font-mono">{symbol ?? ''}</span>}
              chips={
                balance !== undefined && decimals !== undefined ? (
                  <>
                    <button
                      type="button"
                      className="rounded-sm border border-[var(--border)] px-2 py-1 text-[11px] text-[var(--text-2)]"
                      onClick={() =>
                        setAmount(formatDecimalOutput(balance / 2n, decimals, decimals))
                      }
                    >
                      50%
                    </button>
                    <button
                      type="button"
                      className="rounded-sm border border-[var(--border)] px-2 py-1 text-[11px] text-[var(--text-2)]"
                      onClick={() => setAmount(formatDecimalOutput(balance, decimals, decimals))}
                    >
                      Max
                    </button>
                  </>
                ) : null
              }
            />
          </Field>

          {minPositionSize !== undefined && minPositionSize > 0n && decimals !== undefined && (
            <div className="text-xs text-[var(--text-3)]">
              Minimum position{' '}
              <span className="font-mono text-[var(--text-2)]">
                {formatDecimalOutput(minPositionSize, decimals)} {symbol ?? ''}
              </span>
            </div>
          )}

          {!isOpen && (
            <div className="rounded-md border border-[var(--warning)] p-3 text-xs text-[var(--warning)]">
              Round is currently in <Pill variant="paused">{roundState ?? '—'}</Pill>. Deposits will
              fail until the keeper opens the next round.
            </div>
          )}

          <div className="flex items-center gap-2">
            {needsApproval ? (
              <Button loading={approval.isPending} onClick={onApprove}>
                Approve {symbol ?? ''}
              </Button>
            ) : (
              <Button
                disabled={
                  !isOpen ||
                  parsedAmount === 0n ||
                  insufficientBalance ||
                  belowMin ||
                  actions.pending.deposit
                }
                loading={actions.pending.deposit}
                onClick={onDeposit}
              >
                Deposit
              </Button>
            )}
            {insufficientBalance && (
              <span className="text-xs text-[var(--danger)]">Insufficient balance</span>
            )}
            {belowMin && !insufficientBalance && (
              <span className="text-xs text-[var(--danger)]">Below minimum position</span>
            )}
          </div>
        </div>
      )}
    </Card>
  )
}
