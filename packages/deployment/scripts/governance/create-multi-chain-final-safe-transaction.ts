import { TransactionBase } from '@safe-global/types-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import hre from 'hardhat'
import path from 'path'
import { Address, encodeFunctionData, getAddress } from 'viem'
import { FOUNDATION_ROLE } from '../common/constants'
import { promptForChain } from '../helpers/chain-prompt'
import { proposeAllSafeTransactions } from '../helpers/safe-transaction'

// Load environment variables
dotenv.config()

if (!process.env.BVI_MULTISIG_ADDRESS) {
  throw new Error('❌ BVI_MULTISIG_ADDRESS not set in environment')
}

if (!process.env.DEPLOYER_PRIV_KEY) {
  throw new Error('❌ DEPLOYER_PRIV_KEY not set in environment')
}

// In many protocols, roles are defined as the keccak256 hash of the role name.
// This is a placeholder for the curator role.
const CURATOR_ROLE = '0x5fe3d73f69d7a4cb61e46a1a6515e00333708f454f7d7fbb5b411e60e3309f4a'

// Get the Safe address from the environment variables
const safeAddress = getAddress(process.env.BVI_MULTISIG_ADDRESS as Address)

/**
 * Handles role-related transactions:
 * - Grants the curator role on all chains.
 * - Grants the foundation role only on the 'base' chain.
 */
async function handleRoles(
  chainKey: string,
  roles: any,
  accessManager: any,
  transactions: TransactionBase[],
): Promise<void> {
  // Grant the curator role (applies on all chains)
  const curatorAddress = roles.curator
  const hasCuratorRole = await accessManager.read.hasRole([CURATOR_ROLE, curatorAddress])
  if (!hasCuratorRole) {
    console.log(`CURATOR: ❌ ${curatorAddress} does not have the curator role. Adding...`)
    const grantCuratorRoleCalldata = encodeFunctionData({
      abi: accessManager.abi,
      functionName: 'grantCuratorRole',
      args: [curatorAddress],
    })
    transactions.push({
      to: accessManager.address,
      data: grantCuratorRoleCalldata,
      value: '0',
    })
  } else {
    console.log(`CURATOR: ✅ ${curatorAddress} already has the curator role. Skipping...`)
  }

  // Grant the foundation role only on 'base' and if defined
  if (chainKey === 'base' && roles.foundation) {
    const foundationAddress = roles.foundation
    const hasFoundationRole = await accessManager.read.hasRole([FOUNDATION_ROLE, foundationAddress])
    if (!hasFoundationRole) {
      console.log(
        `FOUNDATION: ❌ ${foundationAddress} does not have the foundation role. Adding...`,
      )
      const grantFoundationRoleCalldata = encodeFunctionData({
        abi: accessManager.abi,
        functionName: 'grantFoundationRole',
        args: [foundationAddress],
      })
      transactions.push({
        to: accessManager.address,
        data: grantFoundationRoleCalldata,
        value: '0',
      })
    } else {
      console.log(
        `FOUNDATION: ✅ ${foundationAddress} already has the foundation role. Skipping...`,
      )
    }
  }
}

/**
 * Handles tip stream transactions.
 * This uses the simplified tip streams config which is identical across chains.
 */
async function handleTipStreams(
  summerToken: any,
  tipStreamsData: any,
  transactions: TransactionBase[],
): Promise<void> {
  if (tipStreamsData && Array.isArray(tipStreamsData.tipStreams)) {
    console.log(
      `\nTIP STREAMS: Preparing tip stream transactions for ${tipStreamsData.tipStreams.length} stream(s)...`,
    )
    for (const tip of tipStreamsData.tipStreams) {
      console.log(
        `TIP STREAM: Adding tip stream for ${tip.address} - ${tip.description || ''} with amount ${tip.amount}`,
      )
      const tipStreamCalldata = encodeFunctionData({
        abi: summerToken.abi,
        functionName: 'addTipStream',
        args: [tip.address, tip.amount],
      })
      transactions.push({
        to: summerToken.address,
        data: tipStreamCalldata,
        value: '0',
      })
    }
  } else {
    console.log('TIP STREAMS: No tip stream configurations found, skipping tip stream addition.\n')
  }
}

/**
 * Handles fleet rewards transactions.
 * For each fleet reward manager specified in the config:
 *  1. Approves the manager to pull the configured reward amount from the multisig.
 *  2. Calls notifyRewardAmount on the manager contract to fund reward distribution.
 */
async function handleFleetRewards(
  chainKey: string,
  fleetRewardsData: any,
  summerToken: any,
  transactions: TransactionBase[],
): Promise<void> {
  if (fleetRewardsData && fleetRewardsData.fleetRewards) {
    console.log(
      `\nFLEET REWARDS: Preparing approval and notify transactions for ${fleetRewardsData.fleetRewards.length} manager(s)...`,
    )
    for (const rewardManager of fleetRewardsData.fleetRewards) {
      // Skip managers that should only be handled on Base
      if (rewardManager.onlyOnBase && chainKey !== 'base') {
        console.log(
          `ℹ️ Skipping ${rewardManager.description} (${rewardManager.address}) since it is only for Base`,
        )
        continue
      }
      // Approve the fleet reward manager to pull the specified amount from the Safe's token balance
      console.log(
        `APPROVE: Approving ${rewardManager.description} (${rewardManager.address}) to pull ${rewardManager.amount} tokens`,
      )
      const approveCalldata = encodeFunctionData({
        abi: summerToken.abi,
        functionName: 'approve',
        args: [rewardManager.address, rewardManager.amount],
      })
      transactions.push({
        to: summerToken.address,
        data: approveCalldata,
        value: '0',
      })

      // Encode notifyRewardAmount for the fleet reward manager.
      // We use a minimal ABI fragment for the notifyRewardAmount function found in StakingRewardsManagerBase.
      const rewardManagerABI = [
        'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration) external',
      ]
      console.log(
        `NOTIFY: Notifying reward amount for ${rewardManager.description} (${rewardManager.address})`,
      )
      const notifyCalldata = encodeFunctionData({
        abi: rewardManagerABI,
        functionName: 'notifyRewardAmount',
        args: [summerToken.address, rewardManager.amount, rewardManager.rewardsDuration],
      })
      transactions.push({
        to: rewardManager.address,
        data: notifyCalldata,
        value: '0',
      })
    }
  } else {
    console.log(
      'FLEET REWARDS: No fleet rewards configuration found, skipping fleet rewards handling.\n',
    )
  }
}

async function main() {
  console.log('🚀 Starting multi-chain final Safe transaction process...\n')

  // Use promptForChain to select the target chain.
  const {
    config: chainDeployConfig,
    chain,
    rpcUrl,
    name: chainName,
  } = await promptForChain('Select the target chain:')
  const chainKey = chainName.toLowerCase()
  // Use the chain config returned by the prompt (assumes chainDeployConfig contains chainId and deployedContracts).
  const currentChainId: number = chain.id
  console.log(`Selected Chain: ${chainName} (chainId ${currentChainId})`)

  // Load chain-specific roles configuration
  const rolesConfigPath = path.join(__dirname, '../../launch-config/roles.json')
  const rolesConfig = JSON.parse(fs.readFileSync(rolesConfigPath, 'utf-8'))
  const chainRolesData = rolesConfig[chainKey]
  if (!chainRolesData) {
    throw new Error(`❌ No roles configuration found for chain ${chainKey}`)
  }

  // Load the simplified tip streams configuration (same across all chains)
  const tipStreamsConfigPath = path.join(__dirname, '../../launch-config/tip-streams.json')
  const tipStreamsData = JSON.parse(fs.readFileSync(tipStreamsConfigPath, 'utf-8'))
  if (!tipStreamsData || !tipStreamsData.tipStreams) {
    console.log('⚠️ No tip streams configuration found. Continuing without tip streams...')
  }

  // Load fleet rewards configuration (keyed by chain name)
  const fleetRewardsConfigPath = path.join(__dirname, '../../launch-config/fleet-rewards.json')
  const fleetRewardsConfig = JSON.parse(fs.readFileSync(fleetRewardsConfigPath, 'utf-8'))
  const chainFleetRewardsData = fleetRewardsConfig[chainKey]

  // Build chain configuration using the network name and deployed contracts config.
  const chainConfig = {
    chain: chain,
    chainId: currentChainId,
    config: chainDeployConfig,
    rpcUrl: rpcUrl,
  }

  const transactions: TransactionBase[] = []

  /***** ROLES *****/
  // Get the ProtocolAccessManager contract instance
  const accessManagerAddress = chainConfig.config.deployedContracts.gov.protocolAccessManager
    .address as Address
  const accessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    accessManagerAddress,
  )
  await handleRoles(chainKey, chainRolesData, accessManager, transactions)

  /***** TIP STREAMS *****/
  // Get the SummerToken contract instance
  if (
    !chainConfig.config.deployedContracts.gov.summerToken.address ||
    chainConfig.config.deployedContracts.gov.summerToken.address ===
      '0x0000000000000000000000000000000000000000'
  ) {
    throw new Error('❌ SummerToken is not deployed on this network')
  }
  const summerTokenAddress = chainConfig.config.deployedContracts.gov.summerToken.address as Address
  const summerToken = await hre.viem.getContractAt('SummerToken' as string, summerTokenAddress)
  await handleTipStreams(summerToken, tipStreamsData, transactions)

  /***** FLEET REWARDS: Approval & Notify *****/
  await handleFleetRewards(chainKey, chainFleetRewardsData, summerToken, transactions)

  console.log(`\nFinal Safe transaction will include ${transactions.length} operation(s).`)

  // Get the deployer address
  const deployer = getAddress((await hre.viem.getWalletClients())[0].account.address)
  await proposeAllSafeTransactions(
    transactions,
    deployer,
    safeAddress,
    currentChainId,
    chainConfig.rpcUrl,
    process.env.DEPLOYER_PRIV_KEY as Address,
  )
}

main().catch((error) => {
  console.error('❌ Error:', error)
  process.exit(1)
})
