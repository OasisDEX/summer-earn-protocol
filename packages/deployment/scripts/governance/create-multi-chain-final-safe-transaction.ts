import { TransactionBase } from '@safe-global/types-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import hre from 'hardhat'
import path from 'path'
import { Address, PublicClient, encodeFunctionData, formatUnits, getAddress, parseAbi } from 'viem'
import { FOUNDATION_ROLE, GOVERNOR_ROLE } from '../common/constants'
import { promptForChainFromHre } from '../helpers/chain-prompt'
import { proposeAllSafeTransactions } from '../helpers/safe-transaction'
import { createClients } from '../helpers/wallet-helper'

// Load environment variables
dotenv.config({ path: '../../.env' })

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

/**
 * Formats a token amount (assumed to be in wei with 18 decimals) into a human-readable string.
 * E.g. "300000000000000000" becomes "0.3".
 */
function formatTokenAmount(amount: string): string {
  // viem's formatUnits expects a bigint or a bigint-formatted string.
  return formatUnits(BigInt(amount), 18)
}

/**
 * Converts a duration given in seconds into a human-readable format.
 * For example, 7776000 seconds returns "90 days".
 */
function formatDuration(seconds: number): string {
  // Days are 86400 seconds.
  if (seconds % 86400 === 0) {
    const days = seconds / 86400
    return `${days} day${days > 1 ? 's' : ''}`
  }
  // Fallback to hours if evenly divisible.
  if (seconds % 3600 === 0) {
    const hours = seconds / 3600
    return `${hours} hour${hours > 1 ? 's' : ''}`
  }
  return `${seconds} second${seconds > 1 ? 's' : ''}`
}

/**
 * Converts a fractional allocation (in wei, where e.g. "300000000000000000" represents 0.3)
 * into a percentage share. For example, 0.3 becomes "30% share".
 */
function formatPercentage(amount: string): string {
  // Convert the amount to a decimal string first (e.g. "0.3")
  const shareDecimal = Number(formatUnits(BigInt(amount), 18))
  // Multiply by 100 to get the percentage value
  const percentage = shareDecimal * 100
  return `${percentage % 1 === 0 ? percentage.toFixed(0) : percentage.toFixed(2)}% share`
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

    // Read the curator role ID using the on-chain generateRole method
    const curatorRoleId = await accessManager.read.generateRole([
      CURATOR_ROLE_ENUM,
      fleetCommanderAddress,
    ])

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

  // ---------- GOVERNOR ROLE (Gov) - Process on EVERY chain ----------
  await handleGovRole(globalRoles, govTimelock, accessManager, transactions, publicClient)

  // ---------- SUPER KEEPER ROLE (Global) ----------
  console.log('==== Handling Super Keeper Role ====')
  const superKeeperAddress = globalRoles.superKeeper
  if (!superKeeperAddress) {
    console.log('No super keeper address found in global roles configuration.')
  } else {
    const superKeeperRole = await accessManager.read.SUPER_KEEPER_ROLE()
    const hasSuperKeeperRole = await accessManager.read.hasRole([
      superKeeperRole,
      superKeeperAddress,
    ])
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
  }
  console.log('==== Completed handling Super Keeper Role ====')

  // ---------- FINAL REVOCATION OF BVI_MULTISIG ----------
  console.log('==== Appending final transaction: Revoke governor role from BVI_MULTISIG ====')
  const finalRevokeCalldata = encodeFunctionData({
    abi: accessManager.abi,
    functionName: 'revokeGovernorRole',
    args: [safeAddress],
  })
  transactions.push({
    to: accessManager.address,
    data: finalRevokeCalldata,
    value: '0',
  })
  console.log('==== Completed final revocation of BVI_MULTISIG ====')
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
        `TIP STREAM: Adding tip stream for ${tip.recipient} with allocation ${formatPercentage(tip.allocation)} (${tip.allocation}) and min term ${formatDuration(Number(tip.minTerm))} (${tip.minTerm} seconds).`,
      )
      const tipStreamStruct = {
        recipient: tip.recipient,
        allocation: tip.allocation,
        lockedUntilEpoch: tip.minTerm,
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
        `APPROVE: Approving ${rewardManager.description} (${rewardManager.address}) to pull ${formatTokenAmount(rewardManager.amount)} tokens (${rewardManager.amount}).`,
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
        `NOTIFY: Notifying reward amount for ${rewardManager.description} (${rewardManager.address}) with ${formatTokenAmount(rewardManager.amount)} tokens and duration ${formatDuration(Number(rewardManager.rewardsDuration))} (${rewardManager.rewardsDuration} seconds).`,
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

  // Load configurations.
  const rolesConfigPath = path.join(__dirname, '../launch-config/roles.json')
  const rolesConfig = JSON.parse(fs.readFileSync(rolesConfigPath, 'utf-8'))
  console.log('Loaded roles configuration:')
  console.log(JSON.stringify(rolesConfig, null, 2))

  const tipStreamsConfigPath = path.join(__dirname, '../launch-config/tip-streams.json')
  const tipStreamsData = JSON.parse(fs.readFileSync(tipStreamsConfigPath, 'utf-8'))
  if (!tipStreamsData || !tipStreamsData.tipStreams) {
    console.log('⚠️ No tip streams configuration found. Continuing without tip streams...')
  } else {
    console.log('Tip streams configuration loaded.')
  }

  const fleetRewardsConfigPath = path.join(__dirname, '../launch-config/fleet-rewards.json')
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

  // Create clients.
  const { publicClient } = createClients(chain, rpcUrl, process.env.DEPLOYER_PRIV_KEY as Address)

  const transactions: TransactionBase[] = []

  /***** TIP STREAMS *****/
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
  if (
    !chainConfig.config.deployedContracts.gov.summerToken.address ||
    chainConfig.config.deployedContracts.gov.summerToken.address ===
      '0x0000000000000000000000000000000000000000'
  ) {
    throw new Error('❌ SummerToken is not deployed on this network')
  }
  const summerTokenAddress = chainConfig.config.deployedContracts.gov.summerToken.address as Address
  const summerToken = await hre.viem.getContractAt('SummerToken' as string, summerTokenAddress)
  await handleFleetRewards(chainKey, chainFleetRewardsData, summerToken, transactions)

  /***** ROLES (includes Super Keeper handling and final revocation) *****/
  const govTimelock = chainConfig.config.deployedContracts.gov.timelock.address as Address
  await handleRoles(chainKey, rolesConfig, govTimelock, accessManager, transactions, publicClient)

  // --- Continue with logging and final proposal ---
  console.log(`\nFinal Safe transaction will include ${transactions.length} operation(s).`)
  console.log('\nDetailed Transaction Log:')
  transactions.forEach((tx, index) => {
    console.log(`Transaction ${index + 1}:`)
    console.log(`  To: ${tx.to}`)
    console.log(`  Data: ${tx.data}`)
    console.log(`  Value: ${tx.value}`)
  })

  const deployer = getAddress((await hre.viem.getWalletClients())[0].account.address)
  console.log(`Deployer address: ${deployer}`)
  console.log(`Safe address: ${safeAddress}`)
  console.log('Private key: ', process.env.DEPLOYER_PRIV_KEY?.slice(0, 6) + '...')

  console.log('Proposing transactions...')
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
