import { TransactionBase } from '@safe-global/types-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import hre from 'hardhat'
import path from 'path'
import {
  Address,
  PublicClient,
  encodeAbiParameters,
  encodeFunctionData,
  getAddress,
  keccak256,
  parseAbi,
} from 'viem'
import { FOUNDATION_ROLE, GOVERNOR_ROLE } from '../common/constants'
import { promptForChainFromHre } from '../helpers/chain-prompt'
import { createClients } from '../helpers/wallet-helper'

// Load environment variables
dotenv.config()

if (!process.env.BVI_MULTISIG_ADDRESS) {
  throw new Error('❌ BVI_MULTISIG_ADDRESS not set in environment')
}

if (!process.env.DEPLOYER_PRIV_KEY) {
  throw new Error('❌ DEPLOYER_PRIV_KEY not set in environment')
}

// Get the Safe address from environment variables.
const safeAddress = getAddress(process.env.BVI_MULTISIG_ADDRESS as Address)

// Define types for the roles configuration
interface GlobalRoles {
  curator: Address
  superKeeper: Address
  [key: string]: any
}

interface GovRoles {
  current: Address[]
  endgame: Address
}

interface FoundationRoles {
  current: Address[]
  endgame: Address
}

interface SpecificRoles {
  fleetCommanders?: Address[]
  gov?: GovRoles
  foundation?: FoundationRoles
}

/**
 * Handles the governor role on every chain:
 *   - Grants the gov role only to the timelock (gov endgame) address from the config.
 *   - Revokes the gov role from all other addresses.
 *
 * Note: We use the gov configuration from rolesConfig.base.gov as the canonical source.
 */
async function handleGovRole(
  globalRoles: any,
  govTimelock: string,
  accessManager: any,
  transactions: TransactionBase[],
  publicClient: PublicClient,
): Promise<void> {
  console.log('==== Handling Gov Roles (Removal and Timelock Assignment) ====')
  // Use the gov configuration from the base key as the canonical source.
  const globalGovRole = globalRoles.gov
  if (!globalGovRole) {
    console.log('No gov configuration found in roles config for base.')
    return
  }
  console.log('Gov globalGovRole:', globalGovRole)
  const govRemoved: string[] = globalGovRole.remove || []
  if (!govTimelock) {
    console.log('No gov timelock address configured in roles config.')
    return
  }

  // First, grant the gov role to the timelock if it hasn't been granted.
  const hasGovRole = await accessManager.read.hasRole([GOVERNOR_ROLE, govTimelock], {
    publicClient,
  })
  if (!hasGovRole) {
    console.log(`Granting GOV role to timelock governor: ${govTimelock}`)
    const grantGovRoleCalldata = encodeFunctionData({
      abi: accessManager.abi,
      functionName: 'grantGovernorRole',
      args: [govTimelock],
    })
    transactions.push({
      to: accessManager.address,
      data: grantGovRoleCalldata,
      value: '0',
    })
  } else {
    console.log(`Timelock governor ${govTimelock} already has GOV role.`)
  }

  // Then, revoke the gov role from every address that is NOT the timelock.
  for (const govAddr of govRemoved) {
    if (govAddr.toLowerCase() !== govTimelock.toLowerCase()) {
      // Check if this address currently holds the GOV role
      const hasGovRoleForAddr = await accessManager.read.hasRole([GOVERNOR_ROLE, govAddr], {
        publicClient,
      })
      if (hasGovRoleForAddr) {
        console.log(`Revoking GOV role from address: ${govAddr}`)
        const revokeGovRoleCalldata = encodeFunctionData({
          abi: accessManager.abi,
          functionName: 'revokeGovernorRole',
          args: [govAddr],
        })
        transactions.push({
          to: accessManager.address,
          data: revokeGovRoleCalldata,
          value: '0',
        })
      } else {
        console.log(`Skipping revocation for ${govAddr}: does not have the GOV role.`)
      }
    }
  }
  console.log('==== Completed Gov Role handling ====')
}

/**
 * Handles role-related transactions.
 *
 * Global roles:
 * - Grants the curator role on a fleet-by-fleet basis, using the fleet commander addresses.
 *
 * For chain "base":
 * - Grants the gov role to the endgame (timelock) address and revokes it from the current addresses.
 * - Grants the foundation role to the endgame (foundation multisig) address and revokes it from current holders.
 *
 * @param chainKey - The current chain key (lowercase, e.g. "base")
 * @param rolesConfig - Full roles configuration from roles.json
 * @param accessManager - The ProtocolAccessManager contract instance.
 * @param transactions - The list of transactions being built.
 */
async function handleRoles(
  chainKey: string,
  rolesConfig: any,
  govTimelock: string,
  accessManager: any,
  transactions: TransactionBase[],
  publicClient: PublicClient,
): Promise<void> {
  console.log('==== Handling Roles ====')

  // Extract the global roles (from rolesConfig.all)
  const globalRoles = rolesConfig.all
  const curatorAddress = globalRoles.curator
  const CURATOR_ROLE_ENUM = 0 // CURATOR_ROLE corresponds to enum value 0.

  // Grab chain-specific roles (if any) for the current chain.
  const specificRoles = rolesConfig[chainKey] || {}

  // ---------- CURATOR ROLE (Fleet-Specific) ----------
  let fleetCommanders: string[] = []
  if (specificRoles.fleetCommanders && Array.isArray(specificRoles.fleetCommanders)) {
    fleetCommanders = specificRoles.fleetCommanders
    console.log(
      `Found ${fleetCommanders.length} fleet commander(s) for chain ${chainKey}: ${fleetCommanders.join(', ')}`,
    )
  } else {
    console.log(`No fleet commanders specified for chain ${chainKey}`)
  }

  for (const fleetCommanderAddress of fleetCommanders) {
    console.log(`Processing fleet commander: ${fleetCommanderAddress}`)
    // Compute the role ID for curator on a fleet-by-fleet basis.
    const curatorRoleId = keccak256(
      encodeAbiParameters(
        [{ type: 'uint8' }, { type: 'address' }],
        [CURATOR_ROLE_ENUM, fleetCommanderAddress as Address],
      ),
    )
    console.log(
      `Generated curator role ID for fleet commander ${fleetCommanderAddress}: ${curatorRoleId}`,
    )

    const hasCuratorRole = await accessManager.read.hasRole([curatorRoleId, curatorAddress], {
      publicClient,
    })
    if (!hasCuratorRole) {
      console.log(
        `Granting fleet-specific curator role for ${curatorAddress} on fleet ${fleetCommanderAddress}`,
      )
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
        `Curator ${curatorAddress} already has role for fleet commander ${fleetCommanderAddress}. Skipping.`,
      )
    }
  }

  // ---------- GOVERNOR ROLE (Gov) - Process on EVERY chain ----------
  await handleGovRole(globalRoles, govTimelock, accessManager, transactions, publicClient)

  // ---------- FOUNDATION ROLE (Only on Base) ----------
  if (chainKey === 'base') {
    console.log("Processing FOUNDATION roles for chain 'base'")
    if (specificRoles.foundation) {
      const foundationEndgame = specificRoles.foundation.endgame
      console.log(`Foundation endgame target: ${foundationEndgame}`)

      const hasFoundationRole = await accessManager.read.hasRole(
        [FOUNDATION_ROLE, foundationEndgame],
        { publicClient },
      )
      if (!hasFoundationRole) {
        console.log(`Granting FOUNDATION role to ${foundationEndgame}`)
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
        console.log(`Foundation role already granted to ${foundationEndgame}.`)
      }

      const currentFoundations = specificRoles.foundation.current
      if (Array.isArray(currentFoundations)) {
        for (const foundationAddress of currentFoundations) {
          console.log(`Revoking FOUNDATION role from current foundation: ${foundationAddress}`)
          const revokeFoundationRoleCalldata = encodeFunctionData({
            abi: accessManager.abi,
            functionName: 'revokeFoundationRole',
            args: [foundationAddress],
          })
          transactions.push({
            to: accessManager.address,
            data: revokeFoundationRoleCalldata,
            value: '0',
          })
        }
      } else {
        console.log('No current FOUNDATION addresses found.')
      }
    } else {
      console.log("No FOUNDATION role configuration present for chain 'base'")
    }
  }

  console.log('==== Completed handling roles ====')
}

/**
 * Handles granting the Super Keeper role.
 *
 * This reads the superKeeper address from global roles, checks if the role is already held,
 * and if not, encodes a transaction to grant the role in ProtocolAccessManager.
 */
async function handleSuperKeeperRole(
  globalRoles: GlobalRoles,
  accessManager: any,
  transactions: TransactionBase[],
): Promise<void> {
  console.log('==== Handling Super Keeper Role ====')
  const superKeeperAddress = globalRoles.superKeeper
  if (!superKeeperAddress) {
    console.log('No super keeper address found in global roles configuration.')
    return
  }

  const superKeeperRole = await accessManager.read.SUPER_KEEPER_ROLE()
  console.log(`SUPER_KEEPER_ROLE constant: ${superKeeperRole}`)
  const hasSuperKeeperRole = await accessManager.read.hasRole([superKeeperRole, superKeeperAddress])

  if (!hasSuperKeeperRole) {
    console.log(`Granting Super Keeper role to ${superKeeperAddress}`)
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
    console.log(`Super Keeper ${superKeeperAddress} already has the role. Skipping.`)
  }
  console.log('==== Completed handling Super Keeper Role ====')
}

/**
 * Handles tip stream transactions.
 * Processes the tip streams configuration and adds transactions to call addTipStream.
 */
async function handleTipStreams(
  tipJar: any,
  tipStreamsData: any,
  transactions: TransactionBase[],
): Promise<void> {
  console.log('==== Handling Tip Streams ====')
  if (tipStreamsData && Array.isArray(tipStreamsData.tipStreams)) {
    console.log(
      `\nTIP STREAMS: Preparing tip stream transactions for ${tipStreamsData.tipStreams.length} stream(s)...`,
    )
    for (const tip of tipStreamsData.tipStreams) {
      console.log(
        `TIP STREAM: Adding tip stream for ${tip.recipient} with allocation ${tip.allocation} and min term ${tip.minTerm} seconds.`,
      )
      // Build the TipStream struct as expected by the TipJar contract.
      const tipStreamStruct = {
        recipient: tip.recipient,
        allocation: tip.allocation,
        lockedUntilEpoch: tip.minTerm, // Adjust if you need a different calculation.
      }
      const tipStreamCalldata = encodeFunctionData({
        abi: tipJar.abi,
        functionName: 'addTipStream',
        args: [tipStreamStruct],
      })
      transactions.push({
        to: tipJar.address,
        data: tipStreamCalldata,
        value: '0',
      })
    }
  } else {
    console.log('TIP STREAMS: No tip stream configurations found, skipping tip stream addition.\n')
  }
  console.log('==== Completed handling Tip Streams ====')
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
  console.log('==== Handling Fleet Rewards ====')
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

      // Convert the string-based ABI to a proper ABI object using parseAbi.
      const rewardManagerABI = parseAbi([
        'function notifyRewardAmount(address rewardToken, uint256 reward, uint256 newRewardsDuration) external',
      ])
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
  console.log('==== Completed handling Fleet Rewards ====')
}

async function main() {
  console.log('🚀 Starting multi-chain final Safe transaction process...\n')

  // Instead of asking the user which chain, infer it from hre and ask for confirmation.
  const {
    config: chainDeployConfig,
    chain,
    rpcUrl,
    name: chainName,
  } = await promptForChainFromHre(
    'Automatically detected chain. Confirm execution on this network:',
  )
  const chainKey = chainName.toLowerCase()
  const currentChainId: number = chain.id
  console.log(`Selected Chain: ${chainName} (chainId ${currentChainId})`)

  const detectedChainId = hre.network.config.chainId || 'unknown'

  if (detectedChainId !== currentChainId) {
    console.log('❌ Chain ID mismatch detected. Exiting.')
    process.exit(1)
  }

  // Load roles configuration.
  const rolesConfigPath = path.join(__dirname, '../../launch-config/roles.json')
  const rolesConfig = JSON.parse(fs.readFileSync(rolesConfigPath, 'utf-8'))
  console.log('Loaded roles configuration:')
  console.log(JSON.stringify(rolesConfig, null, 2))

  // Load tip streams configuration.
  const tipStreamsConfigPath = path.join(__dirname, '../../launch-config/tip-streams.json')
  const tipStreamsData = JSON.parse(fs.readFileSync(tipStreamsConfigPath, 'utf-8'))
  if (!tipStreamsData || !tipStreamsData.tipStreams) {
    console.log('⚠️ No tip streams configuration found. Continuing without tip streams...')
  } else {
    console.log('Tip streams configuration loaded.')
  }

  // Load fleet rewards configuration.
  const fleetRewardsConfigPath = path.join(__dirname, '../../launch-config/fleet-rewards.json')
  const fleetRewardsConfig = JSON.parse(fs.readFileSync(fleetRewardsConfigPath, 'utf-8'))
  const chainFleetRewardsData = fleetRewardsConfig[chainKey]
  console.log('Fleet rewards configuration loaded.')

  // Build chain configuration.
  const chainConfig = {
    chain: chain,
    chainId: currentChainId,
    config: chainDeployConfig,
    rpcUrl: rpcUrl,
  }
  console.log('Chain configuration built.')

  // Get the ProtocolAccessManager contract instance.
  const accessManagerAddress = chainConfig.config.deployedContracts.gov.protocolAccessManager
    .address as Address
  console.log(`Using ProtocolAccessManager at address: ${accessManagerAddress}`)
  const accessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    accessManagerAddress,
  )
  console.log('ProtocolAccessManager contract instance created.')

  // Create clients using createClients instead of hre.viem.getPublicClient.
  const { publicClient } = createClients(chain, rpcUrl)

  const transactions: TransactionBase[] = []

  /***** ROLES *****/
  const govTimelock = chainConfig.config.deployedContracts.gov.timelock.address as Address
  // Handle roles with logging.
  await handleRoles(chainKey, rolesConfig, govTimelock, accessManager, transactions, publicClient)
  // Handle Super Keeper Role.
  await handleSuperKeeperRole(rolesConfig.all, accessManager, transactions)

  /***** TIP STREAMS *****/
  // Instead of using SummerToken for tip streams, we use TipJar.
  // Pull TipJar address from the "core" section of your deployment config.
  if (
    !chainConfig.config.deployedContracts.core.tipJar.address ||
    chainConfig.config.deployedContracts.core.tipJar.address ===
      '0x0000000000000000000000000000000000000000'
  ) {
    throw new Error('❌ TipJar is not deployed on this network')
  }
  const tipJarAddress = chainConfig.config.deployedContracts.core.tipJar.address as Address
  console.log(`Using TipJar at address: ${tipJarAddress}`)
  const tipJar = await hre.viem.getContractAt('TipJar' as string, tipJarAddress)
  await handleTipStreams(tipJar, tipStreamsData, transactions)

  /***** FLEET REWARDS: Approval & Notify *****/
  // For fleet rewards, we still use the SummerToken instance.
  if (
    !chainConfig.config.deployedContracts.gov.summerToken.address ||
    chainConfig.config.deployedContracts.gov.summerToken.address ===
      '0x0000000000000000000000000000000000000000'
  ) {
    throw new Error('❌ SummerToken is not deployed on this network')
  }
  const summerTokenAddress = chainConfig.config.deployedContracts.gov.summerToken.address as Address
  console.log(`Using SummerToken at address: ${summerTokenAddress}`)
  const summerToken = await hre.viem.getContractAt('SummerToken' as string, summerTokenAddress)
  await handleFleetRewards(chainKey, chainFleetRewardsData, summerToken, transactions)

  console.log(`\nFinal Safe transaction will include ${transactions.length} operation(s).`)

  // Additional individual logging for clarity.
  console.log('\nDetailed Transaction Log:')
  transactions.forEach((tx, index) => {
    console.log(`Transaction ${index + 1}:`)
    console.log(`  To: ${tx.to}`)
    console.log(`  Data: ${tx.data}`)
    console.log(`  Value: ${tx.value}`)
  })

  // Get the deployer address.
  const deployer = getAddress((await hre.viem.getWalletClients())[0].account.address)
  console.log(`Deployer address: ${deployer}`)

  // Final propose step commented out for testing purposes.
  /*
  await proposeAllSafeTransactions(
    transactions,
    deployer,
    safeAddress,
    currentChainId,
    chainConfig.rpcUrl,
    process.env.DEPLOYER_PRIV_KEY as Address,
  )
  */
  console.log('Propose step commented out. End of testing script.')
}

main().catch((error) => {
  console.error('❌ Error:', error)
  process.exit(1)
})
