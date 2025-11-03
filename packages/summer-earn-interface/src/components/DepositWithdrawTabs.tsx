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
    <div className="bg-gray-900 p-6 rounded-lg">
      <h3 className="text-xl font-semibold text-white mb-6">Deposit & Withdraw</h3>

      {/* Tab Navigation */}
      <div className="flex space-x-1 mb-6 bg-gray-800 p-1 rounded-lg">
        <button
          onClick={() => setActiveTab('deposit')}
          className={`flex-1 py-2 px-4 rounded-md font-medium text-sm transition-colors ${
            activeTab === 'deposit'
              ? 'bg-blue-600 text-white'
              : 'text-gray-300 hover:text-white hover:bg-gray-700'
          }`}
        >
          💰 Deposit {assetSymbol}
        </button>
        <button
          onClick={() => setActiveTab('withdraw')}
          className={`flex-1 py-2 px-4 rounded-md font-medium text-sm transition-colors ${
            activeTab === 'withdraw'
              ? 'bg-orange-600 text-white'
              : 'text-gray-300 hover:text-white hover:bg-gray-700'
          }`}
        >
          🏦 Withdraw {assetSymbol}
        </button>
      </div>

      {/* Tab Content */}
      {activeTab === 'deposit' && (
        <div className="space-y-4">
          <div className="p-4 bg-blue-900 border border-blue-700 rounded-lg">
            <p className="text-sm text-blue-200 mb-2">
              <strong>Deposit Process:</strong>
            </p>
            <p className="text-xs text-blue-300">
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
                className={`w-full p-3 rounded-lg font-semibold transition-colors ${
                  isApproveLoading || parsedDepositAmount === BigInt(0)
                    ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                    : 'bg-yellow-600 hover:bg-yellow-700 text-white'
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
              className={`w-full p-3 rounded-lg font-semibold transition-colors ${
                isDepositLoading || parsedDepositAmount === BigInt(0) || depositNeedsApproval
                  ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                  : 'bg-blue-600 hover:bg-blue-700 text-white'
              }`}
            >
              {isDepositLoading ? 'Depositing...' : `Deposit ${assetSymbol}`}
            </button>
          </div>
        </div>
      )}

      {activeTab === 'withdraw' && (
        <div className="space-y-4">
          <div className="p-4 bg-orange-900 border border-orange-700 rounded-lg">
            <p className="text-sm text-orange-200 mb-2">
              <strong>Withdraw Process:</strong>
            </p>
            <p className="text-xs text-orange-300">
              1. Burn {fleetSymbol} shares → Get {assetSymbol}
              <br />
              2. You'll receive your share of fleet performance
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
            className={`w-full p-3 rounded-lg font-semibold transition-colors ${
              isWithdrawLoading || parsedWithdrawAmount === BigInt(0)
                ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                : 'bg-orange-600 hover:bg-orange-700 text-white'
            }`}
          >
            {isWithdrawLoading ? 'Withdrawing...' : `Withdraw to ${assetSymbol}`}
          </button>
        </div>
      )}
    </div>
  )
}
