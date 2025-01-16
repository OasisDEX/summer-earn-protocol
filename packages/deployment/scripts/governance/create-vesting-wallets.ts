import dotenv from 'dotenv'
import fs from 'fs'
import hre from 'hardhat'
import path from 'path'
import { Address, keccak256, toBytes } from 'viem'
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
  console.log('🚀 Starting vesting wallet creation process...\n')
  if (
    !chainConfig.config.deployedContracts.gov.summerToken.address ||
    chainConfig.config.deployedContracts.gov.summerToken.address === ADDRESS_ZERO
  ) {
    throw new Error('SummerToken is not deployed')
  }

  const signer = (await hre.viem.getWalletClients())[0]
  const summerToken = await hre.viem.getContractAt(
    'SummerToken' as string,
    chainConfig.config.deployedContracts.gov.summerToken.address as Address,
  )
  console.log('Instantiating SummerVestingWalletFactory...')
  const FACTORY_ADDRESS = (await summerToken.read.vestingWalletFactory()) as Address
  const vestingWalletFactory = await hre.viem.getContractAt(
    'SummerVestingWalletFactory' as string,
    FACTORY_ADDRESS,
  )
  const accessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    chainConfig.config.deployedContracts.gov.protocolAccessManager.address as Address,
  )
  const hasGovernanceRole = await accessManager.read.hasRole([
    GOVERNOR_ROLE,
    signer.account.address,
  ])
  if (!hasGovernanceRole) {
    throw new Error('❌ You are not a governor')
  } else {
    console.log('✅ You are a governor - all good!')
  }

  console.log('✅ Address of the factory: ', FACTORY_ADDRESS)
  const beneficiaries = Object.keys(vestingConfig)
  // summ all tokens for approval
  const totalAmount = beneficiaries.reduce((sum, beneficiary) => {
    const vestingData = vestingConfig[beneficiary]
    const timeBasedAmount = BigInt(vestingData.timeBased)
    const goalAmounts: bigint[] = vestingData.goals ? vestingData.goals.map(BigInt) : []
    const totalAmount = timeBasedAmount + goalAmounts.reduce((sum, amount) => sum + amount, 0n)
    return sum + totalAmount
  }, 0n)

  const signerBalance = (await summerToken.read.balanceOf([signer.account.address])) as bigint
  if (signerBalance < totalAmount) {
    throw new Error('❌ Signer balance is less than total amount')
  }

  const allowance = (await summerToken.read.allowance([
    signer.account.address,
    FACTORY_ADDRESS,
  ])) as bigint
  if (allowance < totalAmount) {
    console.log('❌ Allowance is less than total amount, approving...')
    await summerToken.write.approve([FACTORY_ADDRESS, totalAmount.toString()])
    console.log('✅ Approved!')
  } else {
    console.log('✅ Allowance is greater than total amount, skipping approval...')
  }

  const isSignerWhitelisted = await summerToken.read.whitelistedAddresses([signer.account.address])
  if (!isSignerWhitelisted) {
    console.log('❌ Signer not whitelisted, adding to whitelist...')
    await summerToken.write.addToWhitelist([signer.account.address])
    console.log('✅ Added signer to whitelist!')
  } else {
    console.log('✅ Signer already whitelisted, skipping...')
  }

  const isFactoryWhitelisted = await summerToken.read.whitelistedAddresses([FACTORY_ADDRESS])
  if (!isFactoryWhitelisted) {
    console.log('❌ Factory is not whitelisted, adding to whitelist...')
    await summerToken.write.addToWhitelist([FACTORY_ADDRESS])
    console.log('✅ Added factory to whitelist!')
  } else {
    console.log('✅ Factory already whitelisted, skipping...')
  }

  for (const beneficiary of beneficiaries) {
    const vestingData = vestingConfig[beneficiary]
    const timeBasedAmount = BigInt(vestingData.timeBased)
    const goalAmounts = vestingData.goals ? vestingData.goals.map(BigInt) : []

    // Ask for vesting type
    const vestingType = vestingData.goals
      ? VESTING_TYPE.TeamVesting
      : VESTING_TYPE.InvestorExTeamVesting

    console.log('📋 Creating vesting wallet...')

    const tx = await vestingWalletFactory.write.createVestingWallet([
      beneficiary as Address,
      timeBasedAmount,
      goalAmounts,
      vestingType,
    ])

    console.log(`✅ Transaction sent: ${tx}`)

    console.log('✅ Vesting wallet created successfully!')
  }
}

main().catch((error) => {
  console.error('❌ Error:', error)
  process.exit(1)
})
