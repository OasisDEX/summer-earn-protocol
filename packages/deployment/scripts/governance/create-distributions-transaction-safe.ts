import { addressToBytes32 } from '@layerzerolabs/lz-v2-utilities'
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
import { constructLzOptions } from '../helpers/layerzero-options'

dotenv.config()

if (!process.env.BVI_MULTISIG_ADDRESS) {
  throw new Error('❌ BVI_MULTISIG_ADDRESS not set in environment')
}

if (!process.env.DEPLOYER_PRIV_KEY) {
  throw new Error('❌ DEPLOYER_PRIV_KEY not set in environment')
}

const safeAddress = process.env.BVI_MULTISIG_ADDRESS as Address

type TotalAmounts = {
  vestingAmount: bigint
  transfersAmount: bigint
  merkleAmount: bigint
  governanceRewardsAmount: bigint
  bridgeAmount: bigint
  totalAmount: bigint
}

type Transfer = {
  address: string
  amount: string
}

type TransferConfig = {
  [key: string]: Transfer
}

type VestingConfig = {
  [key: string]: {
    timeBased: string
    goals?: string[]
  }
}

type MerkleConfig = {
  distributionId: string
  merkleRoot: string
  totalAmount: string
}

type BridgeDestination = {
  address: string
  amount: string
}

type BridgeConfig = {
  mainnet: BridgeDestination
  arbitrum: BridgeDestination
}

type GovernanceRewardsConfig = {
  amount: string
  duration: string
}

type NetworkDestination = {
  network: 'mainnet' | 'arbitrum'
  destination: BridgeDestination
}

const VESTING_TYPE = {
  TeamVesting: 0,
  InvestorExTeamVesting: 1,
}

// Load vesting distribution configuration
const distributionsDir = path.join(__dirname, '../../token-distributions/')

// Update NetworkConfigs to exclude 'base'
type NetworkConfigs = Record<'mainnet' | 'arbitrum', BaseConfig>

type ChainConfiguration = {
  chain: typeof base
  chainId: number
  config: BaseConfig // This is the base chain config
  rpcUrl: string
  satelliteConfigs: NetworkConfigs // Only contains mainnet and arbitrum configs
}

const chainConfig: ChainConfiguration = {
  chain: base,
  chainId: 8453,
  config: getConfigByNetwork(hre.network.name, { common: true, gov: true, core: true }),
  rpcUrl: process.env.BASE_RPC_URL as string,
  // Filter out 'base' from the loaded config
  satelliteConfigs: (() => {
    const allConfigs = JSON.parse(
      fs.readFileSync(path.join(__dirname, '../../config/index.json'), 'utf-8'),
    )
    const { base, ...satelliteConfigs } = allConfigs
    return satelliteConfigs
  })(),
}

async function handleRoles(
  chainConfig: ChainConfiguration,
  safeAddress: Address,
  transactions: TransactionBase[],
): Promise<void> {
  const accessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    chainConfig.config.deployedContracts.gov.protocolAccessManager.address as Address,
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
  source: Address,
  target: Address,
  amount: bigint,
  context: string,
): Promise<TransactionBase | undefined> {
  const allowance = (await summerToken.read.allowance([source, target])) as bigint
  console.log(`🔑 ${context} allowance: ${allowance}, amount is: ${amount}`)
  if (allowance < amount) {
    console.log(`❌ ${context} allowance is less than required amount, adding approval tx...`)
    const approvalCalldata = encodeFunctionData({
      abi: summerToken.abi,
      functionName: 'approve',
      args: [target, amount.toString()],
    })
    return {
      to: summerToken.address,
      data: approvalCalldata,
      value: '0',
    }
  } else {
    console.log(`✅ ${context} allowance is sufficient, skipping approval...`)
  }
}

async function createVestingWalletTransactions(
  summerToken: any,
  totalAmounts: TotalAmounts,
  vestingWalletFactory: any,
  vestingConfig: VestingConfig,
): Promise<TransactionBase[]> {
  const factoryAddress = vestingWalletFactory.address
  const approvalTx = await handleApproval(
    summerToken,
    safeAddress,
    factoryAddress,
    totalAmounts.vestingAmount,
    'Factory',
  )
  const beneficiaries = Object.keys(vestingConfig)
  const vestingTransactions: TransactionBase[] = beneficiaries.map((beneficiary) => {
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
  if (approvalTx) {
    vestingTransactions.unshift(approvalTx)
  }
  return vestingTransactions
}

async function createGovernanceRewardsTransaction(
  summerToken: any,
  totalAmounts: TotalAmounts,
  govRewardsConfig: GovernanceRewardsConfig,
): Promise<TransactionBase[]> {
  const governanceStakingAddress = await summerToken.read.rewardsManager()
  console.log(`🔑 Governance staking address: ${governanceStakingAddress}`)
  const approvalTx = await handleApproval(
    summerToken,
    safeAddress,
    governanceStakingAddress,
    totalAmounts.governanceRewardsAmount,
    'Governance rewards',
  )
  const governanceRewardsContract = await hre.viem.getContractAt(
    'GovernanceRewardsManager' as string,
    governanceStakingAddress,
  )
  const notifyRewardAmountCalldata = encodeFunctionData({
    abi: governanceRewardsContract.abi,
    functionName: 'notifyRewardAmount',
    args: [summerToken.address, govRewardsConfig.amount, govRewardsConfig.duration],
  })
  const notifyRewardAmountTx = {
    to: governanceStakingAddress,
    data: notifyRewardAmountCalldata,
    value: '0',
  }
  if (approvalTx) {
    return [approvalTx, notifyRewardAmountTx]
  }
  return [notifyRewardAmountTx]
}

async function createBridgeTransactions(
  summerToken: any,
  safeAddress: Address,
  chainConfig: ChainConfiguration,
  bridgeConfig: BridgeConfig,
): Promise<TransactionBase[]> {
  console.log('\n🌉 Preparing bridge transactions...')

  const satelliteConfigs = chainConfig.satelliteConfigs
  const bridgeTransactions: TransactionBase[] = []

  // Fee buffer multiplier (e.g., 1.5 = 50% buffer)
  const FEE_BUFFER_MULTIPLIER = 1.5
  console.log(`Using fee buffer multiplier: ${FEE_BUFFER_MULTIPLIER}x`)

  const destinations: NetworkDestination[] = [
    { network: 'mainnet', destination: bridgeConfig.mainnet },
    { network: 'arbitrum', destination: bridgeConfig.arbitrum },
  ]

  for (const { network, destination } of destinations) {
    if (destination.amount === '0') {
      console.log(`\n⏩ Skipping ${network} - amount is 0`)
      continue
    }

    console.log(`\n🔗 Processing bridge to ${network}:`)
    console.log(`   Amount: ${destination.amount}`)

    const satelliteConfig = satelliteConfigs[network]
    const destinationAddress = (
      destination.address && destination.address !== ADDRESS_ZERO
        ? destination.address
        : satelliteConfig.deployedContracts.gov.timelock.address
    ) as Address

    const destinationHex =
      `0x${Buffer.from(addressToBytes32(destinationAddress)).toString('hex')}` as `0x${string}`

    console.log(`   Destination address: ${destinationAddress}`)
    console.log(`   Destination hex: ${destinationHex}`)
    console.log(`   Destination EID: ${satelliteConfig.common.layerZero.eID}`)

    const options = constructLzOptions(300000n)
    console.log('   Generated options:', options)

    const sendParam = {
      dstEid: Number(satelliteConfig.common.layerZero.eID),
      to: destinationHex,
      amountLD: BigInt(destination.amount),
      minAmountLD: BigInt(destination.amount),
      extraOptions: options,
      composeMsg: '0x' as `0x${string}`,
      oftCmd: '0x' as `0x${string}`,
    }

    // Quote the fees before creating the transaction
    console.log('   📊 Quoting cross-chain fees...')
    const [nativeFee, lzTokenFee] = await summerToken.read.quoteSend([sendParam, false])

    // Add buffer to the fees
    const bufferedNativeFee = BigInt(Math.ceil(Number(nativeFee) * FEE_BUFFER_MULTIPLIER))
    const bufferedLzTokenFee = BigInt(Math.ceil(Number(lzTokenFee) * FEE_BUFFER_MULTIPLIER))

    console.log(`   💰 Native fee: ${nativeFee} wei`)
    console.log(`      Buffered to: ${bufferedNativeFee} wei`)
    console.log(`   🎟️  LZ token fee: ${lzTokenFee} wei`)
    console.log(`      Buffered to: ${bufferedLzTokenFee} wei`)

    const sendCalldata = encodeFunctionData({
      abi: summerToken.abi,
      functionName: 'send',
      args: [
        sendParam,
        { nativeFee: bufferedNativeFee, lzTokenFee: bufferedLzTokenFee },
        safeAddress, // Refund address
      ],
    })

    console.log('   ✅ Created bridge transaction')
    bridgeTransactions.push({
      to: summerToken.address,
      data: sendCalldata,
      value: bufferedNativeFee.toString(),
    })
  }

  console.log(`\n✨ Created ${bridgeTransactions.length} bridge transactions`)
  return bridgeTransactions
}

async function createMerkleRootTransaction(
  summerToken: any,
  totalAmounts: TotalAmounts,
  config: BaseConfig,
  merkleConfig: MerkleConfig,
): Promise<TransactionBase[]> {
  const redeemerAddress = config.deployedContracts.gov.rewardsRedeemer.address as Address
  const approvalTx = await handleApproval(
    summerToken,
    safeAddress,
    redeemerAddress,
    totalAmounts.merkleAmount,
    'Merkle redeemer',
  )
  const redeemerContract = await hre.viem.getContractAt(
    'SummerRewardsRedeemer' as string,
    redeemerAddress,
  )
  console.log(
    `🔑 Adding merkleRoot to rewards redeemer... hash: ${merkleConfig.merkleRoot} index: ${merkleConfig.distributionId}`,
  )
  const addRootCalldata = encodeFunctionData({
    abi: redeemerContract.abi,
    functionName: 'addRoot',
    args: [merkleConfig.distributionId, merkleConfig.merkleRoot],
  })
  const addRootTx = {
    to: redeemerAddress,
    data: addRootCalldata,
    value: '0',
  }
  if (approvalTx) {
    return [approvalTx, addRootTx]
  }
  return [addRootTx]
}

function createTransferTransactions(summerToken: any, transfers: TransferConfig) {
  const transferTransactions = Object.values(transfers).map(({ address, amount }) => ({
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

async function getSafeClient(rpcUrl: string): Promise<any> {
  const safeClient = await createSafeClient({
    provider: rpcUrl,
    signer: process.env.DEPLOYER_PRIV_KEY as Address,
    safeAddress: safeAddress,
  })

  return { safeClient, safeAddress }
}

async function getTokenAndFactory(
  chainConfig: ChainConfiguration,
): Promise<{ summerToken: any; vestingWalletFactory: any; factoryAddress: Address }> {
  if (
    !chainConfig.config.deployedContracts.gov.summerToken.address ||
    chainConfig.config.deployedContracts.gov.summerToken.address === ADDRESS_ZERO
  ) {
    throw new Error('❌ SummerToken is not deployed')
  }

  console.log(
    `🔑 SummerToken address: ${chainConfig.config.deployedContracts.gov.summerToken.address}`,
  )

  const summerToken = await hre.viem.getContractAt(
    'SummerToken' as string,
    chainConfig.config.deployedContracts.gov.summerToken.address as Address,
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

function getTotalAmounts(
  vestingConfig: VestingConfig,
  transfers: TransferConfig,
  merkleConfig: MerkleConfig,
  governanceRewardsConfig: GovernanceRewardsConfig,
  bridgeConfig: BridgeConfig,
): {
  vestingAmount: bigint
  transfersAmount: bigint
  merkleAmount: bigint
  governanceRewardsAmount: bigint
  bridgeAmount: bigint
  totalAmount: bigint
} {
  const beneficiaries = Object.keys(vestingConfig)

  const totalVestingAmount = beneficiaries.reduce((sum, beneficiary) => {
    const vestingData = vestingConfig[beneficiary]
    const timeBasedAmount = BigInt(vestingData.timeBased)
    const goalAmounts: bigint[] = vestingData.goals ? vestingData.goals.map(BigInt) : []
    return sum + timeBasedAmount + goalAmounts.reduce((sum, amount) => sum + amount, 0n)
  }, 0n)

  const totalTransfersAmount = Object.values(transfers).reduce(
    (sum, transfer) => sum + BigInt(transfer.amount),
    0n,
  )
  const totalGovernanceRewardsAmount = BigInt(governanceRewardsConfig.amount)
  const totalBridgeAmount =
    BigInt(bridgeConfig.mainnet.amount) + BigInt(bridgeConfig.arbitrum.amount)
  return {
    vestingAmount: totalVestingAmount,
    transfersAmount: totalTransfersAmount,
    merkleAmount: BigInt(merkleConfig.totalAmount),
    governanceRewardsAmount: totalGovernanceRewardsAmount,
    bridgeAmount: totalBridgeAmount,
    totalAmount:
      totalVestingAmount +
      totalTransfersAmount +
      BigInt(merkleConfig.totalAmount) +
      totalGovernanceRewardsAmount +
      totalBridgeAmount,
  }
}

async function getVestingConfig(chainId: number): Promise<VestingConfig> {
  const vestingPath = path.resolve(distributionsDir, 'input', chainId.toString(), 'vesting.json')
  return JSON.parse(fs.readFileSync(vestingPath, 'utf-8'))
}

async function getMerkleConfig(chainId: number): Promise<MerkleConfig> {
  const merkleRedeemerPath = path.resolve(
    distributionsDir,
    'output',
    chainId.toString(),
    'merkle-redeemer',
    'distribution-1.json',
  )
  const merkleRedeemerConfig: MerkleConfig = JSON.parse(
    fs.readFileSync(merkleRedeemerPath, 'utf-8'),
  )
  return {
    distributionId: merkleRedeemerConfig.distributionId,
    merkleRoot: merkleRedeemerConfig.merkleRoot,
    totalAmount: merkleRedeemerConfig.totalAmount,
  }
}

async function getTransfersConfig(chainId: number): Promise<TransferConfig> {
  const transfersPath = path.resolve(
    distributionsDir,
    'input',
    chainId.toString(),
    'transfers.json',
  )
  const transfersConfig: TransferConfig = JSON.parse(fs.readFileSync(transfersPath, 'utf-8'))

  return transfersConfig
}

async function getBridgeConfig(chainId: number): Promise<BridgeConfig> {
  const bridgePath = path.resolve(distributionsDir, 'input', chainId.toString(), 'bridge.json')
  const bridgeConfig: BridgeConfig = JSON.parse(fs.readFileSync(bridgePath, 'utf-8'))

  return bridgeConfig
}

async function getGovernanceRewardsConfig(chainId: number): Promise<GovernanceRewardsConfig> {
  const governanceRewardsPath = path.resolve(
    distributionsDir,
    'input',
    chainId.toString(),
    'governance-rewards.json',
  )
  const governanceRewardsConfig: GovernanceRewardsConfig = JSON.parse(
    fs.readFileSync(governanceRewardsPath, 'utf-8'),
  )

  return governanceRewardsConfig
}

async function main() {
  console.log('🚀 Starting Safe vesting wallet creation process...\n')
  const { safeClient, safeAddress } = await getSafeClient(chainConfig.rpcUrl)

  const transactions: TransactionBase[] = []

  const transfersConfig = await getTransfersConfig(chainConfig.chainId)
  const vestingConfig = await getVestingConfig(chainConfig.chainId)
  const merkleConfig = await getMerkleConfig(chainConfig.chainId)
  const bridgeConfig = await getBridgeConfig(chainConfig.chainId)
  const governanceRewardsConfig = await getGovernanceRewardsConfig(chainConfig.chainId)

  const { summerToken, vestingWalletFactory, factoryAddress } =
    await getTokenAndFactory(chainConfig)

  await handleRoles(chainConfig, safeAddress, transactions)
  await handleWhitelist(summerToken, safeAddress, factoryAddress, transactions)

  // Calculate total amount needed for approval
  const totalAmounts = getTotalAmounts(
    vestingConfig,
    transfersConfig,
    merkleConfig,
    governanceRewardsConfig,
    bridgeConfig,
  )

  const safeBalance = (await summerToken.read.balanceOf([safeAddress])) as bigint
  console.log(`🔑 Safe balance: ${safeBalance / 10n ** 18n}`)
  console.log(`🔑 Total amount: ${totalAmounts.totalAmount / 10n ** 18n}`)

  if (safeBalance < totalAmounts.totalAmount) {
    throw new Error('❌ Safe balance is less than total amount')
  }

  transactions.push(
    ...(await createVestingWalletTransactions(
      summerToken,
      totalAmounts,
      vestingWalletFactory,
      vestingConfig,
    )),
  )
  transactions.push(...createTransferTransactions(summerToken, transfersConfig))
  transactions.push(
    ...(await createMerkleRootTransaction(
      summerToken,
      totalAmounts,
      chainConfig.config,
      merkleConfig,
    )),
  )
  transactions.push(
    ...(await createGovernanceRewardsTransaction(
      summerToken,
      totalAmounts,
      governanceRewardsConfig,
    )),
  )
  transactions.push(
    ...(await createBridgeTransactions(summerToken, safeAddress, chainConfig, bridgeConfig)),
  )

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
