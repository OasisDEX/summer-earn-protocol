import { createSafeClient } from '@safe-global/sdk-starter-kit'
import { TransactionBase } from '@safe-global/types-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import hre from 'hardhat'
import path from 'path'
import { Address, encodeFunctionData } from 'viem'
import { base } from 'viem/chains'
import { BaseConfig } from '../../types/config-types'
import { ADDRESS_ZERO, FOUNDATION_ROLE, GOVERNOR_ROLE } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'

dotenv.config()

type Transfer = {
  address: string
  amount: string
}

type VestingConfig = {
  [key: string]: {
    timeBased: string
    goals?: string[]
  }
}

type MerkleConfig = {
  merkleRoot: string
  totalAmount: string
}

const VESTING_TYPE = {
  TeamVesting: 0,
  InvestorExTeamVesting: 1,
}

const oazoAppsLimitedTransfer = {
  address: '0xDE1Bf64033Fa4BabB5d047C18E858c0f272B2f32',
  amount: '154261300000000000000000000',
}
const foundationTransfer = {
  address: '0xE470684D279386Ce126d0576086C123a930312B3',
  amount: '70000000000000000000000000',
}
const oazoMultisigTransfer = { address: 'TBD', amount: '64900000000000000000000000' }

const tokenTransfers: Transfer[] = [
  oazoAppsLimitedTransfer,
  foundationTransfer,
  oazoMultisigTransfer,
]

// Load vesting distribution configuration
const distributionsDir = path.join(__dirname, '../../token-distributions/')

const chainConfig = {
  chain: base,
  chainId: 8453,
  config: getConfigByNetwork(hre.network.name, { common: true, gov: true, core: true }),
  rpcUrl: process.env.BASE_RPC_URL as string,
}

async function handleRoles(
  chainConfig: BaseConfig,
  safeAddress: Address,
  transactions: TransactionBase[],
): Promise<void> {
  const accessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    chainConfig.deployedContracts.gov.protocolAccessManager.address as Address,
  )
  const hasGovernanceRole = await accessManager.read.hasRole([GOVERNOR_ROLE, safeAddress])
  if (!hasGovernanceRole) {
    console.log('❌ Safe is not a governor - adding...')
    await accessManager.write.grantGovernorRole([safeAddress])
    console.log('✅ Safe is a governor - all good!')
  } else {
    console.log('✅ Safe is a governor - all good!')
  }

  const hasFoundationRole = await accessManager.read.hasRole([FOUNDATION_ROLE, safeAddress])
  if (!hasFoundationRole) {
    console.log('❌ Safe is not a foundation - adding...')
    const grantFoundationRoleCalldata = encodeFunctionData({
      abi: accessManager.abi,
      functionName: 'grantFoundationRole',
      args: [safeAddress],
    })
    transactions.push({
      to: accessManager.address,
      data: grantFoundationRoleCalldata,
      value: '0',
    })
  } else {
    console.log('✅ Safe is a foundation - all good!')
  }
}

async function handleWhitelist(
  summerToken: any,
  safeAddress: Address,
  factoryAddress: Address,
  transactions: TransactionBase[],
): Promise<void> {
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
    console.log('✅ Safe is already whitelisted, skipping...')
  }

  const isFactoryWhitelisted = await summerToken.read.whitelistedAddresses([factoryAddress])
  if (!isFactoryWhitelisted) {
    console.log('❌ Factory is not whitelisted, adding to whitelist...')
    const whitelistCalldata = encodeFunctionData({
      abi: summerToken.abi,
      functionName: 'addToWhitelist',
      args: [factoryAddress],
    })
    transactions.push({
      to: summerToken.address,
      data: whitelistCalldata,
      value: '0',
    })
    console.log('✅ Added factory to whitelist!')
  } else {
    console.log('✅ Factory is already whitelisted, skipping...')
  }
}

async function handleApproval(
  summerToken: any,
  safeAddress: Address,
  factoryAddress: Address,
  totalAmount: bigint,
  transactions: TransactionBase[],
): Promise<void> {
  const allowance = (await summerToken.read.allowance([safeAddress, factoryAddress])) as bigint
  if (allowance < totalAmount) {
    console.log('❌ Allowance is less than total amount, adding approval tx...')
    const approvalCalldata = encodeFunctionData({
      abi: summerToken.abi,
      functionName: 'approve',
      args: [factoryAddress, totalAmount.toString()],
    })
    transactions.push({
      to: summerToken.address,
      data: approvalCalldata,
      value: '0',
    })
  } else {
    console.log('✅ Allowance is greater than total amount, skipping approval...')
  }
}

function createVestingWalletTransactions(
  vestingWalletFactory: any,
  factoryAddress: Address,
  beneficiaries: string[],
  vestingConfig: VestingConfig,
): TransactionBase[] {
  return beneficiaries.map((beneficiary) => {
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

    console.log(`🔑 Creating vesting wallet for ${beneficiary}...`)
    return {
      to: factoryAddress,
      data: createVestingCalldata,
      value: '0',
    }
  })
}

async function createMerkleRootTransaction(
  config: BaseConfig,
  merkleRoot: string,
): Promise<TransactionBase> {
  const summerRewardsRedeemerContract = await hre.viem.getContractAt(
    'SummerRewardsRedeemer' as string,
    config.deployedContracts.gov.rewardsRedeemer.address as Address,
  )
  const addRootCalldata = encodeFunctionData({
    abi: summerRewardsRedeemerContract.abi,
    functionName: 'addRoot',
    args: [1, merkleRoot],
  })
  console.log(`🔑 Adding root to rewards redeemer... hash: ${merkleRoot} index: 1`)
  return {
    to: summerRewardsRedeemerContract.address,
    data: addRootCalldata,
    value: '0',
  }
}

async function getSafeClient(rpcUrl: string): Promise<any> {
  if (!process.env.SAFE_ADDRESS) {
    throw new Error('❌ SAFE_ADDRESS not set in environment')
  }

  if (!process.env.DEPLOYER_PRIV_KEY) {
    throw new Error('❌ DEPLOYER_PRIV_KEY not set in environment')
  }

  const safeAddress = process.env.SAFE_ADDRESS as Address
  const safeClient = await createSafeClient({
    provider: rpcUrl,
    signer: process.env.DEPLOYER_PRIV_KEY as Address,
    safeAddress: safeAddress,
  })

  return { safeClient, safeAddress }
}

async function getTokenAndFactory(
  chainConfig: BaseConfig,
): Promise<{ summerToken: any; vestingWalletFactory: any; factoryAddress: Address }> {
  if (
    !chainConfig.deployedContracts.gov.summerToken.address ||
    chainConfig.deployedContracts.gov.summerToken.address === ADDRESS_ZERO
  ) {
    throw new Error('❌ SummerToken is not deployed')
  }

  console.log(`🔑 SummerToken address: ${chainConfig.deployedContracts.gov.summerToken.address}`)

  const summerToken = await hre.viem.getContractAt(
    'SummerToken' as string,
    chainConfig.deployedContracts.gov.summerToken.address as Address,
  )

  console.log(' Instantiating SummerVestingWalletFactory...')
  const factoryAddress = (await summerToken.read.vestingWalletFactory()) as Address
  console.log(`🔑 SummerVestingWalletFactory address: ${factoryAddress}`)

  const vestingWalletFactory = await hre.viem.getContractAt(
    'SummerVestingWalletFactory' as string,
    factoryAddress,
  )

  return { summerToken, vestingWalletFactory, factoryAddress }
}

function getTotalAmount(
  vestingConfig: Record<string, any>,
  transfers: Transfer[],
  merkleAmount: bigint,
): bigint {
  const beneficiaries = Object.keys(vestingConfig)

  const totalVestingAmount = beneficiaries.reduce((sum, beneficiary) => {
    const vestingData = vestingConfig[beneficiary]
    const timeBasedAmount = BigInt(vestingData.timeBased)
    const goalAmounts: bigint[] = vestingData.goals ? vestingData.goals.map(BigInt) : []
    return sum + timeBasedAmount + goalAmounts.reduce((sum, amount) => sum + amount, 0n)
  }, 0n)

  const totalTransfersAmount = transfers.reduce(
    (sum, transfer) => sum + BigInt(transfer.amount),
    0n,
  )

  return totalVestingAmount + totalTransfersAmount + merkleAmount
}

async function main() {
  console.log('🚀 Starting Safe vesting wallet creation process...\n')
  const { safeClient, safeAddress } = await getSafeClient(chainConfig.rpcUrl)

  const transactions: TransactionBase[] = []

  const vestingPath = path.resolve(
    distributionsDir,
    'input',
    chainConfig.chainId.toString(),
    'vesting.json',
  )
  const merkleRedeemerPath = path.resolve(
    distributionsDir,
    'output',
    chainConfig.chainId.toString(),
    'merkle-redeemer',
    'distribution-1.json',
  )

  const vestingConfig: VestingConfig = JSON.parse(fs.readFileSync(vestingPath, 'utf-8'))
  const merkleRedeemerConfig: MerkleConfig = JSON.parse(
    fs.readFileSync(merkleRedeemerPath, 'utf-8'),
  )
  const merkleRoot = merkleRedeemerConfig.merkleRoot
  const merkleAmount = BigInt(merkleRedeemerConfig.totalAmount)

  const { summerToken, vestingWalletFactory, factoryAddress } = await getTokenAndFactory(
    chainConfig.config,
  )

  await handleRoles(chainConfig.config, safeAddress, transactions)
  await handleWhitelist(summerToken, safeAddress, factoryAddress, transactions)

  // Calculate total amount needed for approval
  const totalAmount = getTotalAmount(vestingConfig, tokenTransfers, merkleAmount)

  const safeBalance = (await summerToken.read.balanceOf([safeAddress])) as bigint
  if (safeBalance < totalAmount) {
    throw new Error('❌ Safe balance is less than total amount')
  }

  console.log(`🔑 Safe balance: ${safeBalance}`)
  console.log(`🔑 Total amount: ${totalAmount}`)

  await handleApproval(summerToken, safeAddress, factoryAddress, totalAmount, transactions)

  transactions.push(
    ...createVestingWalletTransactions(
      vestingWalletFactory,
      factoryAddress,
      Object.keys(vestingConfig),
      vestingConfig,
    ),
  )
  transactions.push(...createTransferTransactions(summerToken, tokenTransfers))
  transactions.push(await createMerkleRootTransaction(chainConfig.config, merkleRoot))

  console.log(`Preparing Safe transaction with ${transactions.length} operations...`)

  // Send transactions to Safe
  const txResult = await safeClient.send({ transactions })
  console.log('Safe transaction created!')
  console.log('Safe Transaction Hash:', txResult.transactions?.safeTxHash)
}

function createTransferTransactions(summerToken: any, transfers: Transfer[]) {
  const transferTransactions = transfers.map(({ address, amount }) => ({
    to: summerToken.address,
    data: encodeFunctionData({
      abi: summerToken.abi,
      functionName: 'transfer',
      args: [address as Address, amount],
    }),
    value: '0',
  }))
  console.log(`🔑 Creating ${transferTransactions.length} transfer transactions...`)
  return transferTransactions
}

main().catch((error) => {
  console.error('❌ Error:', error)
  process.exit(1)
})
