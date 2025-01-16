import { createSafeClient } from '@safe-global/sdk-starter-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import hre from 'hardhat'
import path from 'path'
import { Address, encodeFunctionData, keccak256, toBytes } from 'viem'
import { base } from 'viem/chains'
import { ADDRESS_ZERO } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'

const GOVERNOR_ROLE = keccak256(toBytes('GOVERNOR_ROLE'))
const VESTING_TYPE = {
  TeamVesting: 0,
  InvestorExTeamVesting: 1,
}

dotenv.config()

// Load configuration from index.json
const config = getConfigByNetwork(hre.network.name)

// Load vesting distribution configuration
const vestingPath = path.resolve(__dirname, '../../config/distributions/vesting.json')
const vestingConfig = JSON.parse(fs.readFileSync(vestingPath, 'utf-8'))

const chainConfig = {
  chain: base,
  config: config,
  rpcUrl: process.env.BASE_RPC_URL as string,
}

async function main() {
  console.log('🚀 Starting Safe vesting wallet creation process...\n')

  if (!process.env.SAFE_ADDRESS) {
    throw new Error('SAFE_ADDRESS not set in environment')
  }

  if (!process.env.DEPLOYER_PRIV_KEY) {
    throw new Error('DEPLOYER_PRIV_KEY not set in environment')
  }
  const safeAddress = process.env.SAFE_ADDRESS as Address
  // Initialize Safe client
  const safeClient = await createSafeClient({
    provider: chainConfig.rpcUrl,
    signer: process.env.DEPLOYER_PRIV_KEY as Address,
    safeAddress: safeAddress,
  })

  if (
    !chainConfig.config.deployedContracts.gov.summerToken.address ||
    chainConfig.config.deployedContracts.gov.summerToken.address === ADDRESS_ZERO
  ) {
    throw new Error('SummerToken is not deployed')
  }

  const summerToken = await hre.viem.getContractAt(
    'SummerToken' as string,
    chainConfig.config.deployedContracts.gov.summerToken.address as Address,
  )
  const accessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    chainConfig.config.deployedContracts.gov.protocolAccessManager.address as Address,
  )
  const hasGovernanceRole = await accessManager.read.hasRole([GOVERNOR_ROLE, safeAddress])
  if (!hasGovernanceRole) {
    throw new Error('❌ You are not a governor')
  } else {
    console.log('✅ You are a governor - all good!')
  }

  console.log(' Instantiating SummerVestingWalletFactory...')
  const FACTORY_ADDRESS = (await summerToken.read.vestingWalletFactory()) as Address
  const vestingWalletFactory = await hre.viem.getContractAt(
    'SummerVestingWalletFactory' as string,
    FACTORY_ADDRESS,
  )

  // Calculate total amount needed for approval
  const beneficiaries = Object.keys(vestingConfig)
  const totalAmount = beneficiaries.reduce((sum, beneficiary) => {
    const vestingData = vestingConfig[beneficiary]
    const timeBasedAmount = BigInt(vestingData.timeBased)
    const goalAmounts: bigint[] = vestingData.goals ? vestingData.goals.map(BigInt) : []
    return sum + timeBasedAmount + goalAmounts.reduce((sum, amount) => sum + amount, 0n)
  }, 0n)

  const safeBalance = (await summerToken.read.balanceOf([safeAddress])) as bigint
  if (safeBalance < totalAmount) {
    throw new Error('❌ Safe balance is less than total amount')
  }

  // Prepare transactions array for Safe
  const transactions = []
  const allowance = (await summerToken.read.allowance([safeAddress, FACTORY_ADDRESS])) as bigint
  if (allowance < totalAmount) {
    console.log('❌ Allowance is less than total amount, adding approval tx...')
    const approvalCalldata = encodeFunctionData({
      abi: summerToken.abi,
      functionName: 'approve',
      args: [FACTORY_ADDRESS, totalAmount.toString()],
    })
    transactions.push({
      to: summerToken.address,
      data: approvalCalldata,
      value: '0',
    })
  } else {
    console.log('✅ Allowance is greater than total amount, skipping approval...')
  }

  const isWhitelisted = await summerToken.read.whitelistedAddresses([safeAddress])
  if (!isWhitelisted) {
    console.log('❌ Not whitelisted, adding to whitelist...')
    const whitelistCalldata = encodeFunctionData({
      abi: summerToken.abi,
      functionName: 'addToWhitelist',
      args: [safeAddress],
    })

    transactions.push({
      to: summerToken.address,
      data: whitelistCalldata,
      value: '0',
    })
  } else {
    console.log('✅ Already whitelisted, skipping...')
  }
  const isFactoryWhitelisted = await summerToken.read.whitelistedAddresses([FACTORY_ADDRESS])
  if (!isFactoryWhitelisted) {
    console.log('❌ Factory is not whitelisted, adding to whitelist...')
    const whitelistCalldata = encodeFunctionData({
      abi: summerToken.abi,
      functionName: 'addToWhitelist',
      args: [FACTORY_ADDRESS],
    })
    transactions.push({
      to: summerToken.address,
      data: whitelistCalldata,
      value: '0',
    })
    console.log('✅ Added factory to whitelist!')
  } else {
    console.log('✅ Factory already whitelisted, skipping...')
  }
  // Add vesting wallet creation transactions
  for (const beneficiary of beneficiaries) {
    const vestingData = vestingConfig[beneficiary]
    const timeBasedAmount = BigInt(vestingData.timeBased)
    const goalAmounts = vestingData.goals ? vestingData.goals.map(BigInt) : []
    const vestingType = vestingData.goals
      ? VESTING_TYPE.TeamVesting
      : VESTING_TYPE.InvestorExTeamVesting

    const createVestingCalldata = encodeFunctionData({
      abi: vestingWalletFactory.abi,
      functionName: 'createVestingWallet',
      args: [beneficiary as Address, timeBasedAmount, goalAmounts, vestingType],
    })

    transactions.push({
      to: FACTORY_ADDRESS,
      data: createVestingCalldata,
      value: '0',
    })
  }

  console.log(`Preparing Safe transaction with ${transactions.length} operations...`)

  // Send transactions to Safe
  const txResult = await safeClient.send({ transactions })
  console.log('Safe transaction created!')
  console.log('Safe Transaction Hash:', txResult.transactions?.safeTxHash)
}

main().catch((error) => {
  console.error('❌ Error:', error)
  process.exit(1)
})
