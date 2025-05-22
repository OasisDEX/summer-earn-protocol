'use client'

import Link from 'next/link'
import { useState } from 'react'
import { formatUnits } from 'viem'
import { useFleetActions } from '../hooks/useFleetActions'
import { FleetCommanderInfo, UserFleetInfo } from '../types'

interface FleetCardProps {
  fleetInfo: FleetCommanderInfo
  userInfo: UserFleetInfo | null
  assetDecimals: number
  assetSymbol: string
  chainId: string
}

export function FleetCard({
  fleetInfo,
  userInfo,
  assetDecimals,
  assetSymbol,
  chainId,
}: FleetCardProps) {
  const [amount, setAmount] = useState<string>('')

  const { approve, deposit, withdraw, isApproveLoading, isDepositLoading, isWithdrawLoading } =
    useFleetActions({
      fleetAddress: fleetInfo.address as `0x${string}`,
      assetAddress: fleetInfo.asset as `0x${string}`,
      assetDecimals,
    })

  const needsApproval =
    userInfo && userInfo.allowance < BigInt(amount || '0') && BigInt(amount || '0') > BigInt(0)

  const handleDeposit = () => {
    if (needsApproval) {
      approve(amount)
    } else {
      deposit(amount)
    }
  }

  const handleWithdraw = () => {
    withdraw(amount)
  }

  return (
    <div className="bg-gray-400 shadow rounded-lg p-6 mb-4">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-xl font-bold">{fleetInfo.name}</h2>
        <span className="text-sm bg-blue-100 text-blue-800 py-1 px-2 rounded">
          {fleetInfo.symbol}
        </span>
      </div>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <p className="text-sm text-gray-800">Total Assets</p>
          <p className="font-medium">
            {formatUnits(fleetInfo.totalAssets, assetDecimals).slice(0, 10)} {assetSymbol}
          </p>
        </div>
        <div>
          <p className="text-sm text-gray-800">Withdrawable Assets</p>
          <p className="font-medium">
            {formatUnits(fleetInfo.withdrawableTotalAssets, assetDecimals).slice(0, 10)}{' '}
            {assetSymbol}
          </p>
        </div>
      </div>

      {userInfo && (
        <div className="border-t pt-4 mb-4">
          <div className="grid grid-cols-2 gap-4 mb-4">
            <div>
              <p className="text-sm text-gray-800">Your Balance</p>
              <p className="font-medium">
                {formatUnits(userInfo.balance, assetDecimals)} {fleetInfo.symbol}
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-800">Your {assetSymbol} Balance</p>
              <p className="font-medium">
                {formatUnits(userInfo.underlyingBalance, assetDecimals)} {assetSymbol}
              </p>
            </div>
          </div>

          <div className="mb-4">
            <label htmlFor="amount" className="block text-sm font-medium text-gray-800 mb-1">
              Amount
            </label>
            <input
              type="text"
              id="amount"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder={`Amount in ${assetSymbol}`}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <div className="flex space-x-2">
            <button
              onClick={handleDeposit}
              disabled={isApproveLoading || isDepositLoading || !amount}
              className="flex-1 bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 disabled:bg-gray-400"
            >
              {isApproveLoading
                ? 'Approving...'
                : isDepositLoading
                  ? 'Depositing...'
                  : needsApproval
                    ? 'Approve'
                    : 'Deposit'}
            </button>
            <button
              onClick={handleWithdraw}
              disabled={isWithdrawLoading || !amount}
              className="flex-1 bg-gray-600 text-white py-2 px-4 rounded-md hover:bg-gray-700 disabled:bg-gray-400"
            >
              {isWithdrawLoading ? 'Withdrawing...' : 'Withdraw'}
            </button>
          </div>
        </div>
      )}

      <div className="text-right mt-2">
        <Link
          href={`/fleet/${chainId}/${fleetInfo.address}`}
          className="text-blue-600 hover:underline text-sm"
        >
          View Details
        </Link>
      </div>
    </div>
  )
}
