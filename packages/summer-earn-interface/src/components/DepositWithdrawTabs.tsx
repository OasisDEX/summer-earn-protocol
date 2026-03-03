'use client'

import { useState } from 'react'

import type { UserFleetInfo } from '../types'
import { AmountInput } from './AmountInput'

interface DepositWithdrawTabsProps {
  userInfo: UserFleetInfo
  assetSymbol: string
  assetDecimals: number
  fleetSymbol: string
  fleetDecimals: number
  onDeposit: (amount: string, parsedAmount: bigint) => void
  onWithdraw: (amount: string, parsedAmount: bigint) => void
  onApprove: () => void
  isApproveLoading: boolean
  isDepositLoading: boolean
  isWithdrawLoading: boolean
  needsApproval: (amount: string) => boolean
}

export function DepositWithdrawTabs({
  userInfo,
  assetSymbol,
  assetDecimals,
  fleetSymbol,
  fleetDecimals,
  onDeposit,
  onWithdraw,
  onApprove,
  isApproveLoading,
  isDepositLoading,
  isWithdrawLoading,
  needsApproval,
}: DepositWithdrawTabsProps) {
  const [activeTab, setActiveTab] = useState<'deposit' | 'withdraw'>('deposit')
  const [depositAmount, setDepositAmount] = useState('')
  const [parsedDepositAmount, setParsedDepositAmount] = useState<bigint>(BigInt(0))
  const [withdrawAmount, setWithdrawAmount] = useState('')
  const [parsedWithdrawAmount, setParsedWithdrawAmount] = useState<bigint>(BigInt(0))

  const handleDeposit = () => {
    if (parsedDepositAmount > BigInt(0)) {
      onDeposit(depositAmount, parsedDepositAmount)
    }
  }

  const handleWithdraw = () => {
    if (parsedWithdrawAmount > BigInt(0)) {
      onWithdraw(withdrawAmount, parsedWithdrawAmount)
    }
  }

  const depositNeedsApproval = needsApproval(depositAmount)

  return (
    <div className="glass rounded-2xl p-6">
      <h3 className="font-bold text-lg text-white mb-6">Deposit & Withdraw</h3>

      {/* Tab Navigation */}
      <div className="flex gap-1 mb-6 bg-white/5 p-1 rounded-xl border border-white/5">
        <button
          onClick={() => setActiveTab('deposit')}
          className={`flex-1 py-2.5 px-4 rounded-lg font-semibold text-sm transition-all ${
            activeTab === 'deposit'
              ? 'bg-primary text-white shadow-lg shadow-primary/20'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          Deposit {assetSymbol}
        </button>
        <button
          onClick={() => setActiveTab('withdraw')}
          className={`flex-1 py-2.5 px-4 rounded-lg font-semibold text-sm transition-all ${
            activeTab === 'withdraw'
              ? 'bg-primary text-white shadow-lg shadow-primary/20'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          Withdraw {assetSymbol}
        </button>
      </div>

      {/* Tab Content */}
      {activeTab === 'deposit' && (
        <div className="space-y-4">
          <div className="p-4 bg-primary/10 border border-primary/20 rounded-xl">
            <p className="text-xs text-slate-400 uppercase font-bold mb-2">Deposit Process</p>
            <p className="text-sm text-slate-300">
              1. Deposit {assetSymbol} → Get {fleetSymbol} shares
              <br />
              2. {fleetSymbol} shares earn yield from fleet strategies
              <br />
              3. Optionally stake {fleetSymbol} shares for bonus rewards
            </p>
          </div>

          <AmountInput
            value={depositAmount}
            onChange={(value, parsed) => {
              setDepositAmount(value)
              setParsedDepositAmount(parsed)
            }}
            symbol={assetSymbol}
            decimals={assetDecimals}
            balance={userInfo.underlyingBalance}
            showMaxButton={true}
            label={`Amount to Deposit`}
            placeholder={`Enter ${assetSymbol} amount`}
          />

          <div className="space-y-2">
            {depositNeedsApproval && (
              <button
                onClick={onApprove}
                disabled={isApproveLoading || parsedDepositAmount === BigInt(0)}
                className={`w-full py-3 rounded-xl font-bold transition-all ${
                  isApproveLoading || parsedDepositAmount === BigInt(0)
                    ? 'bg-charcoal-700 text-slate-500 cursor-not-allowed'
                    : 'bg-amber-500/20 border border-amber-500/30 text-amber-400 hover:bg-amber-500/30'
                }`}
              >
                {isApproveLoading ? 'Approving...' : `Approve ${assetSymbol}`}
              </button>
            )}

            <button
              onClick={handleDeposit}
              disabled={
                isDepositLoading || parsedDepositAmount === BigInt(0) || depositNeedsApproval
              }
              className={`w-full py-3 rounded-xl font-bold transition-all ${
                isDepositLoading || parsedDepositAmount === BigInt(0) || depositNeedsApproval
                  ? 'bg-charcoal-700 text-slate-500 cursor-not-allowed'
                  : 'bg-primary hover:shadow-neon-glow border border-primary/50 text-white'
              }`}
            >
              {isDepositLoading ? 'Depositing...' : `Deposit ${assetSymbol}`}
            </button>
          </div>
        </div>
      )}

      {activeTab === 'withdraw' && (
        <div className="space-y-4">
          <div className="p-4 bg-emerald-500/10 border border-emerald-500/20 rounded-xl">
            <p className="text-xs text-slate-400 uppercase font-bold mb-2">Withdraw Process</p>
            <p className="text-sm text-slate-300">
              1. Burn {fleetSymbol} shares → Get {assetSymbol}
              <br />
              2. You&apos;ll receive your share of fleet performance
              <br />
              3. Note: Unstake first if you have staked shares
            </p>
          </div>

          <AmountInput
            value={withdrawAmount}
            onChange={(value, parsed) => {
              setWithdrawAmount(value)
              setParsedWithdrawAmount(parsed)
            }}
            symbol={fleetSymbol}
            decimals={fleetDecimals}
            balance={userInfo.balance}
            showMaxButton={true}
            showMaxUintButton={true}
            label={`${fleetSymbol} Shares to Withdraw`}
            placeholder={`Enter ${fleetSymbol} amount`}
          />

          <button
            onClick={handleWithdraw}
            disabled={isWithdrawLoading || parsedWithdrawAmount === BigInt(0)}
            className={`w-full py-3 rounded-xl font-bold transition-all ${
              isWithdrawLoading || parsedWithdrawAmount === BigInt(0)
                ? 'bg-charcoal-700 text-slate-500 cursor-not-allowed'
                : 'bg-primary hover:shadow-neon-glow border border-primary/50 text-white'
            }`}
          >
            {isWithdrawLoading ? 'Withdrawing...' : `Withdraw to ${assetSymbol}`}
          </button>
        </div>
      )}
    </div>
  )
}
