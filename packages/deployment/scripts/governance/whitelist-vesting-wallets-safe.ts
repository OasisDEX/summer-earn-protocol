import { TransactionBase } from '@safe-global/types-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import hre from 'hardhat'
import path from 'path'
import { Address, encodeFunctionData, getAddress } from 'viem'
import { base } from 'viem/chains'
import { getConfigByNetwork } from '../helpers/config-handler'
import { proposeAllSafeTransactions } from '../helpers/safe-transaction'

dotenv.config()

if (!process.env.BVI_MULTISIG_ADDRESS) {
  throw new Error('❌ BVI_MULTISIG_ADDRESS not set in environment')
}

if (!process.env.DEPLOYER_PRIV_KEY) {
  throw new Error('❌ DEPLOYER_PRIV_KEY not set in environment')
}

const safeAddress = getAddress(process.env.BVI_MULTISIG_ADDRESS as Address)

// Load vesting distribution configuration
const distributionsDir = path.join(__dirname, '../../token-distributions/')

const chainConfig = {
  chain: base,
  chainId: 8453,
  config: getConfigByNetwork(hre.network.name, { common: true, gov: true, core: false }),
  rpcUrl: process.env.BASE_RPC_URL as string,
}

async function getVestingConfig(chainId: number): Promise<Record<string, any>> {
  const vestingPath = path.resolve(distributionsDir, 'input', chainId.toString(), 'vesting.json')
  return JSON.parse(fs.readFileSync(vestingPath, 'utf-8'))
}

async function main() {
  console.log('🚀 Starting Safe vesting wallet whitelist process...\n')

  const vestingConfig = await getVestingConfig(chainConfig.chainId)
  const beneficiaries = Object.keys(vestingConfig)

  console.log(`Found ${beneficiaries.length} vesting wallet beneficiaries to whitelist`)

  // Get the SummerToken contract
  const summerToken = await hre.viem.getContractAt(
    'SummerToken' as string,
    chainConfig.config.deployedContracts.gov.summerToken.address as Address,
  )

  // Get the factory contract
  const factoryAddress = (await summerToken.read.vestingWalletFactory()) as Address
  const vestingWalletFactory = await hre.viem.getContractAt(
    'SummerVestingWalletFactory' as string,
    factoryAddress,
  )

  const transactions: TransactionBase[] = []

  // Create whitelist transactions for each vesting wallet
  for (const beneficiary of beneficiaries) {
    const vestingWalletAddress = await vestingWalletFactory.read.vestingWallets([beneficiary])

    if (vestingWalletAddress === '0x0000000000000000000000000000000000000000') {
      console.log(`⚠️ No vesting wallet found for ${beneficiary}, skipping...`)
      continue
    }

    const isWhitelisted = await summerToken.read.whitelistedAddresses([vestingWalletAddress])
    if (isWhitelisted) {
      console.log(`✅ Vesting wallet for ${beneficiary} already whitelisted, skipping...`)
      continue
    }

    console.log(
      `📝 Creating whitelist transaction for ${beneficiary}'s vesting wallet at ${vestingWalletAddress}...`,
    )
    const whitelistCalldata = encodeFunctionData({
      abi: summerToken.abi,
      functionName: 'addToWhitelist',
      args: [vestingWalletAddress],
    })

    transactions.push({
      to: summerToken.address,
      data: whitelistCalldata,
      value: '0',
    })
  }

  if (transactions.length === 0) {
    console.log('✨ No transactions needed - all vesting wallets are already whitelisted')
    return
  }

  console.log(`\n📦 Created ${transactions.length} whitelist transactions`)

  const deployer = getAddress((await hre.viem.getWalletClients())[0].account.address)
  await proposeAllSafeTransactions(
    transactions,
    deployer,
    safeAddress,
    chainConfig.chainId,
    chainConfig.rpcUrl,
    process.env.DEPLOYER_PRIV_KEY as Address,
  )
}

main().catch((error) => {
  console.error('❌ Error:', error)
  process.exit(1)
})
