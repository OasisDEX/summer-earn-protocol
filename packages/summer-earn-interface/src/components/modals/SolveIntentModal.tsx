'use client'

import { useEffect, useState } from 'react'
import { useAccount } from 'wagmi'

import type { Environment } from '../../config/environments'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import type { ChainId } from '../../types'
import { Button, helpTextBase, inputBase, labelBase, selectBase } from '../ui'
import { Modal } from '../ui/Modal'

interface IntentData {
  intentId: string
  user: string
  requiredNotional: bigint
  requiredBond: bigint
  term: bigint
  targetYield: bigint
  token: string
  oracle: string
  expiry: bigint
}

const DAY_IN_SECONDS = BigInt(86400)
const USD_MULTIPLIER = BigInt(10 ** 18)

interface SolveIntentModalProps {
  isOpen: boolean
  onClose: () => void
  environment: Environment
  chainId: ChainId
  intentData?: IntentData // Optional prefilled data from intent
}

export function SolveIntentModal({
  isOpen,
  onClose,
  environment,
  chainId,
  intentData,
}: SolveIntentModalProps) {
  const { address: userAddress } = useAccount()
  const {
    solveIntent,
    loading,
    error,
    tokens,
    mockIntentOracle,
    getSummerTokenAllowance,
    approveToken,
    intentHandler,
  } = useIntentSystem(environment, chainId)

  const [formData, setFormData] = useState({
    user: '', // Ark address
    requiredNotional: '',
    requiredBond: '', // USD amount with 18 decimals
    term: '',
    targetYield: '',
    token: tokens?.USDC || '',
    oracle: mockIntentOracle || '',
    expiry: '',
    escrowedYield: '',
  })

  const [approvalStatus, setApprovalStatus] = useState<
    'idle' | 'checking' | 'needs-approval' | 'approving' | 'approved'
  >('idle')
  const [needsApproval, setNeedsApproval] = useState(false)

  const isApproving = () => approvalStatus === 'approving'

  // Prefill form data when intentData is provided
  useEffect(() => {
    console.log('SolveIntentModal useEffect:', {
      intentData,
      isOpen,
      userAddress,
      tokens,
      mockIntentOracle,
    })
    console.log('Environment:', environment, 'ChainId:', chainId)

    if (intentData && isOpen) {
      const expiryDate = new Date(Number(intentData.expiry) * 1000)
      const newFormData = {
        user: intentData.user,
        requiredNotional: intentData.requiredNotional.toString(),
        requiredBond: (intentData.requiredBond / BigInt(10 ** 18)).toString(), // Convert from 18 decimals to USD
        term: (intentData.term / BigInt(86400)).toString(), // Convert from seconds to days
        targetYield: intentData.targetYield.toString(),
        token: intentData.token,
        oracle:
          intentData.oracle || mockIntentOracle || '0x8a6AeCaa8C5241b72bA8c8D5D67102341Ee0c553',
        expiry: expiryDate.toISOString().slice(0, 16), // Format for datetime-local input
        escrowedYield: '',
      }
      console.log('Setting form data with intentData:', newFormData)
      setFormData(newFormData)
    } else if (!intentData && isOpen) {
      // Reset to default values when no intent data
      const newFormData = {
        user: userAddress || '',
        requiredNotional: '',
        requiredBond: '',
        term: '',
        targetYield: '',
        token: tokens?.USDC || '',
        oracle: mockIntentOracle || '0x8a6AeCaa8C5241b72bA8c8D5D67102341Ee0c553', // Fallback for Base staging
        expiry: '',
        escrowedYield: '',
      }
      console.log('Setting form data with defaults:', newFormData)
      setFormData(newFormData)
    }
  }, [intentData, isOpen, tokens, mockIntentOracle, userAddress, environment, chainId])

  // Check if approval is needed for the escrowed yield token
  const checkTokenApproval = async () => {
    if (!userAddress || !intentHandler || !formData.escrowedYield || !formData.token) return

    try {
      setApprovalStatus('checking')

      // For now, we'll use the SUMMER token allowance check as a fallback
      // TODO: Implement generic token allowance checking
      const allowance = await getSummerTokenAllowance(userAddress)
      const requiredAmount = BigInt(formData.escrowedYield)

      console.log('Current allowance:', allowance.toString())
      console.log('Required amount:', requiredAmount.toString())
      console.log('Token to approve:', formData.token)

      if (allowance < requiredAmount) {
        setNeedsApproval(true)
        setApprovalStatus('needs-approval')
      } else {
        setNeedsApproval(false)
        setApprovalStatus('approved')
      }
    } catch (error) {
      console.error('Error checking allowance:', error)
      setApprovalStatus('idle')
    }
  }

  // Approve tokens for spending
  const handleApprove = async () => {
    if (!intentHandler || !formData.token) return

    try {
      setApprovalStatus('approving')
      // For now, we'll approve the token from the intent (which is typically the token being used)
      // In the future, we might need to approve both the intent token and SUMMER token
      const hash = await approveToken(formData.token, intentHandler, BigInt(formData.escrowedYield))
      console.log('Approval transaction:', hash)
      console.log('Approved token:', formData.token)
      console.log('Approved spender:', intentHandler)
      console.log('Approved amount:', formData.escrowedYield)
      setApprovalStatus('approved')
      setNeedsApproval(false)
    } catch (error) {
      console.error('Error approving tokens:', error)
      setApprovalStatus('needs-approval')
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    try {
      // Validate required fields
      if (!formData.user || formData.user === '') {
        alert('Please enter a valid user address')
        return
      }
      if (!formData.token || formData.token === '') {
        alert('Token address is required')
        return
      }
      if (!formData.oracle || formData.oracle === '') {
        alert('Oracle address is required')
        return
      }
      if (!formData.requiredNotional || formData.requiredNotional === '') {
        alert('Required notional is required')
        return
      }
      if (!formData.requiredBond || formData.requiredBond === '') {
        alert('Required bond is required')
        return
      }
      if (!formData.term || formData.term === '') {
        alert('Term is required')
        return
      }
      if (!formData.targetYield || formData.targetYield === '') {
        alert('Target yield is required')
        return
      }
      if (!formData.expiry || formData.expiry === '') {
        alert('Expiry date is required')
        return
      }
      if (!formData.escrowedYield || formData.escrowedYield === '') {
        alert('Escrowed yield is required')
        return
      }

      const expiryTimestamp = Math.floor(new Date(formData.expiry).getTime() / 1000)

      console.log('Form data before submission:', formData)

      // Create Intent struct matching the contract
      const intent = {
        user: formData.user as `0x${string}`,
        requiredNotional: BigInt(formData.requiredNotional),
        requiredBond: BigInt(formData.requiredBond) * USD_MULTIPLIER, // Convert USD input to 18 decimals
        term: BigInt(formData.term) * DAY_IN_SECONDS, // Convert days back to seconds
        targetYield: BigInt(formData.targetYield),
        token: formData.token as `0x${string}`,
        oracle: formData.oracle as `0x${string}`,
        expiry: intentData ? intentData.expiry : BigInt(expiryTimestamp), // Use original expiry from intent
      }

      console.log('Intent object:', intent)

      const escrowedYield = BigInt(formData.escrowedYield)
      console.log('Escrowed yield:', escrowedYield)

      // Check approval before solving
      if (needsApproval) {
        alert('Please approve token spending first')
        return
      }

      const hash = await solveIntent(intent, escrowedYield)

      console.log('Intent solved:', hash)
      onClose()
      // Reset form
      setFormData({
        user: '',
        requiredNotional: '',
        requiredBond: '',
        term: '',
        targetYield: '',
        token: tokens?.USDC || '',
        oracle: mockIntentOracle || '',
        expiry: '',
        escrowedYield: '',
      })
    } catch (err) {
      console.error('Error solving intent:', err)
    }
  }

  const handleInputChange = (field: string, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }))
  }

  if (!isOpen) return null

  return (
    <Modal onClose={onClose} title="Solve Intent" size="md">
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Ark Address */}
        <div>
          <label className={labelBase}>Ark Address</label>
          <input
            type="text"
            value={formData.user}
            onChange={(e) => handleInputChange('user', e.target.value)}
            placeholder="0x..."
            className={inputBase}
            required
          />
        </div>

        {/* Required Notional */}
        <div>
          <label className={labelBase}>Required Notional (USDC)</label>
          <input
            type="number"
            value={formData.requiredNotional}
            onChange={(e) => handleInputChange('requiredNotional', e.target.value)}
            placeholder="1000000"
            className={inputBase}
            required
          />
          <div className={helpTextBase}>
            USDC amount in wei (6 decimals) - enter the raw token amount
          </div>
        </div>

        {/* Required Bond */}
        <div>
          <label className={labelBase}>Required Bond (USD)</label>
          <input
            type="number"
            value={formData.requiredBond}
            onChange={(e) => handleInputChange('requiredBond', e.target.value)}
            placeholder="1000"
            className={inputBase}
            required
          />
          <div className={helpTextBase}>
            USD amount (e.g., enter &quot;1000&quot; for $1000 USD - will be converted to 18
            decimals automatically)
          </div>
        </div>

        {/* Term */}
        <div>
          <label className={labelBase}>Term (days)</label>
          <input
            type="number"
            value={formData.term}
            onChange={(e) => handleInputChange('term', e.target.value)}
            placeholder="30"
            min="1"
            max="365"
            className={inputBase}
            required
          />
        </div>

        {/* Target Yield */}
        <div>
          <label className={labelBase}>Target Yield (USDC)</label>
          <input
            type="number"
            value={formData.targetYield}
            onChange={(e) => handleInputChange('targetYield', e.target.value)}
            placeholder="50000"
            className={inputBase}
            required
          />
        </div>

        {/* Token */}
        <div>
          <label className={labelBase}>Token</label>
          <select
            value={formData.token}
            onChange={(e) => handleInputChange('token', e.target.value)}
            className={`${selectBase} w-full`}
            required
          >
            <option value="">Select token</option>
            {tokens &&
              Object.entries(tokens).map(([symbol, address]) => (
                <option key={symbol} value={address}>
                  {symbol}
                </option>
              ))}
          </select>
        </div>

        {/* Oracle */}
        <div>
          <label className={labelBase}>Oracle Address</label>
          <input
            type="text"
            value={formData.oracle}
            onChange={(e) => handleInputChange('oracle', e.target.value)}
            placeholder="0x..."
            className={inputBase}
            required
          />
        </div>

        {/* Expiry */}
        <div>
          <label className={labelBase}>Expiry Date</label>
          <input
            type="datetime-local"
            value={formData.expiry}
            onChange={(e) => handleInputChange('expiry', e.target.value)}
            className={inputBase}
            required
          />
        </div>

        {/* Escrowed Yield */}
        <div>
          <label className={labelBase}>Escrowed Yield (USDC)</label>
          <input
            type="number"
            value={formData.escrowedYield}
            onChange={(e) => handleInputChange('escrowedYield', e.target.value)}
            placeholder="50000"
            className={inputBase}
            required
          />
          <p className={helpTextBase}>Amount of yield to escrow upfront</p>
        </div>

        {/* Token Approval Section */}
        {formData.escrowedYield && BigInt(formData.escrowedYield) > BigInt(0) && (
          <div className="bg-white/[0.02] p-4 rounded-lg border border-white/5">
            <div className="flex items-center justify-between mb-3">
              <h4 className="text-sm font-medium text-on-surface">Token Approval</h4>
              <Button
                type="button"
                onClick={checkTokenApproval}
                disabled={approvalStatus === 'checking'}
                variant="secondary"
                size="sm"
              >
                {approvalStatus === 'checking' ? 'Checking...' : 'Check Approval'}
              </Button>
            </div>

            {approvalStatus === 'needs-approval' && (
              <div className="space-y-2">
                <p className="text-xs text-warning">You need to approve tokens for spending</p>
                <button
                  type="button"
                  onClick={handleApprove}
                  disabled={isApproving()}
                  className="w-full py-2 px-4 bg-warning/15 border border-warning/30 text-warning hover:bg-warning/25 disabled:opacity-40 disabled:cursor-not-allowed rounded-lg font-medium transition-colors"
                >
                  {isApproving() ? 'Approving...' : 'Approve Tokens'}
                </button>
              </div>
            )}

            {approvalStatus === 'approved' && (
              <p className="text-xs text-success">✅ Tokens approved for spending</p>
            )}
          </div>
        )}

        {/* Error Display */}
        {error && (
          <div className="text-error text-sm bg-error/15 border border-error/30 p-3 rounded-lg">
            {error}
          </div>
        )}

        {/* Submit Button */}
        <Button type="submit" disabled={loading || needsApproval} variant="primary" fullWidth>
          {loading ? 'Solving...' : needsApproval ? 'Approve Tokens First' : 'Solve Intent'}
        </Button>
      </form>
    </Modal>
  )
}
