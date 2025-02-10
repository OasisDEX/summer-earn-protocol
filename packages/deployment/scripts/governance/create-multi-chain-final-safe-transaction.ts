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

// Governance role hash for gov role changes – update with your actual hash if needed.
const GOVERNANCE_ROLE = '0xGovRolePlaceholder'

// Get the Safe address from environment variables.
const safeAddress = getAddress(process.env.BVI_MULTISIG_ADDRESS as Address)

/**
 * Handles role-related transactions.
 *
 * Global roles:
 * - Grants the curator role on a fleet-by-fleet basis, using the fleet commander address.
 *
 * For chain "base":
 * - Grants the gov role to the endgame (timelock) address and revokes it from the current addresses.
 * - Grants the foundation role to the endgame (foundation multisig) address and revokes it from current holders.
 *
 * @param chainKey - The current chain key (lowercase, e.g. "base")
 * @param globalRoles - Global roles configuration (from rolesConfig.all)
 * @param specificRoles - Chain-specific roles configuration (for Base, gov and foundation)
 * @param accessManager - The ProtocolAccessManager contract instance.
 * @param transactions - The list of transactions being built.
 */
async function handleRoles(
  chainKey: string,
  globalRoles: any,
  specificRoles: any,
  accessManager: any,
  transactions: TransactionBase[],
): Promise<void> {
  // ---------- CURATOR ROLE (Fleet-Specific) ----------
  // Get the curator account from global configuration.
  const curatorAddress = globalRoles.curator
  const CURATOR_ROLE_ENUM = 0 // equivalent to ContractSpecificRoles.CURATOR_ROLE

  // Ensure we have fleet commander addresses from roles config.
  let fleetCommanders: string[] = []
  if (specificRoles.fleetCommanders && Array.isArray(specificRoles.fleetCommanders)) {
    fleetCommanders = specificRoles.fleetCommanders
  } else {
    console.log(`No fleet commanders found in roles config for chain: ${chainKey}`)
  }

  // Use viem public client to call readContract.
  const publicClient = await hre.viem.getPublicClient()

  for (const fleetCommanderAddress of fleetCommanders) {
    // Compute the fleet-specific curator role ID.
    const curatorRoleId = await publicClient.readContract({
      address: accessManager.address,
      abi: accessManager.abi,
      functionName: 'generateRole',
      args: [CURATOR_ROLE_ENUM, fleetCommanderAddress],
    })

    // Check if the curator already holds this role.
    const hasCuratorRole = await accessManager.read.hasRole([curatorRoleId, curatorAddress])
    if (!hasCuratorRole) {
      console.log(
        `CURATOR: ${curatorAddress} does not have the fleet-specific curator role for fleet commander ${fleetCommanderAddress}. Adding...`,
      )
      // Encode the call to grantCuratorRole.
      const grantCuratorRoleCalldata = encodeFunctionData({
        abi: accessManager.abi,
        functionName: 'grantCuratorRole',
        args: [fleetCommanderAddress, curatorAddress],
      })
      transactions.push({
        to: accessManager.address,
        data: grantCuratorRoleCalldata,
        value: '0',
      })
    } else {
      console.log(
        `CURATOR: ${curatorAddress} already has the fleet-specific curator role for fleet commander ${fleetCommanderAddress}. Skipping...`,
      )
    }
  }

  // ---------- GOVERNANCE & FOUNDATION (Only on Base) ----------
  if (chainKey === 'base') {
    // Process GOV Role changes.
    if (specificRoles.gov) {
      const govEndgame = specificRoles.gov.endgame
      // First, grant gov role to the timelock (endgame).
      const hasGovRole = await accessManager.read.hasRole([GOVERNANCE_ROLE, govEndgame])
      if (!hasGovRole) {
        console.log(`GOV: ${govEndgame} does not have the gov role. Granting...`)
        const grantGovRoleCalldata = encodeFunctionData({
          abi: accessManager.abi,
          functionName: 'grantGovernorRole',
          args: [govEndgame],
        })
        transactions.push({
          to: accessManager.address,
          data: grantGovRoleCalldata,
          value: '0',
        })
      } else {
        console.log(`GOV: ${govEndgame} already has the gov role. Skipping...`)
      }
      // Then revoke gov role from each current address (except the endgame).
      for (const currentGov of specificRoles.gov.current) {
        if (currentGov.toLowerCase() !== govEndgame.toLowerCase()) {
          const hasGov = await accessManager.read.hasRole([GOVERNANCE_ROLE, currentGov])
          if (hasGov) {
            console.log(`GOV: Revoking gov role from ${currentGov}...`)
            const revokeGovRoleCalldata = encodeFunctionData({
              abi: accessManager.abi,
              functionName: 'revokeGovernorRole',
              args: [currentGov],
            })
            transactions.push({
              to: accessManager.address,
              data: revokeGovRoleCalldata,
              value: '0',
            })
          } else {
            console.log(`GOV: ${currentGov} does not have gov role. Skipping...`)
          }
        }
      }
    }

    // Process FOUNDATION Role changes.
    if (specificRoles.foundation) {
      const foundationEndgame = specificRoles.foundation.endgame
      // First, grant the foundation role to the foundation multisig (endgame).
      const hasFoundationRole = await accessManager.read.hasRole([
        FOUNDATION_ROLE,
        foundationEndgame,
      ])
      if (!hasFoundationRole) {
        console.log(
          `FOUNDATION: ${foundationEndgame} does not have the foundation role. Granting...`,
        )
        const grantFoundationRoleCalldata = encodeFunctionData({
          abi: accessManager.abi,
          functionName: 'grantFoundationRole',
          args: [foundationEndgame],
        })
        transactions.push({
          to: accessManager.address,
          data: grantFoundationRoleCalldata,
          value: '0',
        })
      } else {
        console.log(`FOUNDATION: ${foundationEndgame} already has foundation role. Skipping...`)
      }
      // Then revoke the foundation role from each current address (except the endgame).
      for (const currentFnd of specificRoles.foundation.current) {
        if (currentFnd.toLowerCase() !== foundationEndgame.toLowerCase()) {
          const hasFnd = await accessManager.read.hasRole([FOUNDATION_ROLE, currentFnd])
          if (hasFnd) {
            console.log(`FOUNDATION: Revoking foundation role from ${currentFnd}...`)
            const revokeFoundationRoleCalldata = encodeFunctionData({
              abi: accessManager.abi,
              functionName: 'revokeFoundationRole',
              args: [currentFnd],
            })
            transactions.push({
              to: accessManager.address,
              data: revokeFoundationRoleCalldata,
              value: '0',
            })
          } else {
            console.log(`FOUNDATION: ${currentFnd} does not have foundation role. Skipping...`)
          }
        }
      }
    }
  }

  // Handle Super Keeper role
  await handleSuperKeeperRole(globalRoles, accessManager, transactions)
}

/**
 * Handles granting the Super Keeper role.
 *
 * Reads the super keeper address from the global roles config. If the address does not
 * already have the super keeper role (as defined by ProtocolAccessManager), this function
 * encodes a transaction to grant it.
 *
 * @param globalRoles - Global roles configuration (from rolesConfig.all)
 * @param accessManager - The ProtocolAccessManager contract instance.
 * @param transactions - The list of transactions being built.
 */
async function handleSuperKeeperRole(
  globalRoles: any,
  accessManager: any,
  transactions: TransactionBase[],
): Promise<void> {
  const superKeeperAddress = globalRoles.superKeeper
  if (!superKeeperAddress) {
    console.log('No super keeper address found in global roles configuration.')
    return
  }

  // Retrieve the SUPER_KEEPER_ROLE constant from the contract.
  const superKeeperRole = await accessManager.read.SUPER_KEEPER_ROLE()

  // Check if the super keeper already has the role.
  const hasSuperKeeperRole = await accessManager.read.hasRole([superKeeperRole, superKeeperAddress])

  if (!hasSuperKeeperRole) {
    console.log(`SUPER KEEPER: ${superKeeperAddress} does not have the role. Granting...`)
    const grantSuperKeeperCalldata = encodeFunctionData({
      abi: accessManager.abi,
      functionName: 'grantSuperKeeperRole',
      args: [superKeeperAddress],
    })
    transactions.push({
      to: accessManager.address,
      data: grantSuperKeeperCalldata,
      value: '0',
    })
  } else {
    console.log(`SUPER KEEPER: ${superKeeperAddress} already has the role. Skipping...`)
  }
}

/**
 * Handles tip stream transactions.
 * Processes the tip streams configuration and adds transactions to call addTipStream.
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
        `TIP STREAM: Adding tip stream for ${tip.recipient} with allocation ${tip.allocation} and min term ${tip.minTerm} seconds.`,
      )
      // For simplicity, we assume SummerToken has addTipStream.
      const tipStreamCalldata = encodeFunctionData({
        abi: summerToken.abi,
        functionName: 'addTipStream',
        args: [tip.recipient, tip.allocation],
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
 *  2. Calls notifyRewardAmount on the manager contract to start reward distribution.
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

  // Prompt for the target chain.
  const {
    config: chainDeployConfig,
    chain,
    rpcUrl,
    name: chainName,
  } = await promptForChain('Select the target chain:')
  const chainKey = chainName.toLowerCase()
  const currentChainId: number = chain.id
  console.log(`Selected Chain: ${chainName} (chainId ${currentChainId})`)

  // Load roles configuration.
  const rolesConfigPath = path.join(__dirname, '../../launch-config/roles.json')
  const rolesConfig = JSON.parse(fs.readFileSync(rolesConfigPath, 'utf-8'))
  const globalRoles = rolesConfig.all
  const specificRoles = rolesConfig[chainKey] || {} // Gov/foundation roles only exist for Base.

  // Load tip streams configuration.
  const tipStreamsConfigPath = path.join(__dirname, '../../launch-config/tip-streams.json')
  const tipStreamsData = JSON.parse(fs.readFileSync(tipStreamsConfigPath, 'utf-8'))
  if (!tipStreamsData || !tipStreamsData.tipStreams) {
    console.log('⚠️ No tip streams configuration found. Continuing without tip streams...')
  }

  // Load fleet rewards configuration.
  const fleetRewardsConfigPath = path.join(__dirname, '../../launch-config/fleet-rewards.json')
  const fleetRewardsConfig = JSON.parse(fs.readFileSync(fleetRewardsConfigPath, 'utf-8'))
  const chainFleetRewardsData = fleetRewardsConfig[chainKey]

  // Build chain configuration.
  const chainConfig = {
    chain: chain,
    chainId: currentChainId,
    config: chainDeployConfig,
    rpcUrl: rpcUrl,
  }

  const transactions: TransactionBase[] = []

  /***** ROLES *****/
  // Get the ProtocolAccessManager contract instance.
  const accessManagerAddress = chainConfig.config.deployedContracts.gov.protocolAccessManager
    .address as Address
  const accessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    accessManagerAddress,
  )
  await handleRoles(chainKey, globalRoles, specificRoles, accessManager, transactions)

  /***** TIP STREAMS *****/
  // Get the SummerToken contract instance.
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

  // Get the deployer address.
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
