import { TransactionBase } from '@safe-global/types-kit'
import dotenv from 'dotenv'
import fs from 'fs'
import hre from 'hardhat'
import path from 'path'
import { Address, encodeFunctionData, getAddress } from 'viem'
import { FOUNDATION_ROLE } from '../common/constants'
import { promptForChain } from '../helpers/chain-prompt'

// Load environment variables
dotenv.config()

if (!process.env.BVI_MULTISIG_ADDRESS) {
  throw new Error('❌ BVI_MULTISIG_ADDRESS not set in environment')
}

if (!process.env.DEPLOYER_PRIV_KEY) {
  throw new Error('❌ DEPLOYER_PRIV_KEY not set in environment')
}

const GOVERNANCE_ROLE = '0x7935bd0ae54bc31f548c14dba4d37c5c64b3f8ca900cb468fb8abd54d5894f55'

// Get the Safe address from environment variables.
const safeAddress = getAddress(process.env.BVI_MULTISIG_ADDRESS as Address)

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
  console.log('==== Handling Roles ====')

  // ---------- CURATOR ROLE (Fleet-Specific) ----------
  const curatorAddress = globalRoles.curator
  const CURATOR_ROLE_ENUM = 0 // CURATOR_ROLE corresponds to enum value 0.

  // Get fleet commanders from roles configuration.
  let fleetCommanders: string[] = []
  if (specificRoles.fleetCommanders && Array.isArray(specificRoles.fleetCommanders)) {
    fleetCommanders = specificRoles.fleetCommanders
    console.log(
      `Found ${fleetCommanders.length} fleet commander(s) for chain ${chainKey}: ${fleetCommanders.join(', ')}`,
    )
  } else {
    console.log(`No fleet commanders specified for chain ${chainKey}`)
  }

  // Use viem public client to generate the fleet-specific role.
  const publicClient = await hre.viem.getPublicClient()

  for (const fleetCommanderAddress of fleetCommanders) {
    console.log(`Processing fleet commander: ${fleetCommanderAddress}`)
    const curatorRoleId = await publicClient.readContract({
      address: accessManager.address,
      abi: accessManager.abi,
      functionName: 'generateRole',
      args: [CURATOR_ROLE_ENUM, fleetCommanderAddress],
    })
    console.log(
      `Generated curator role ID for fleet commander ${fleetCommanderAddress}: ${curatorRoleId}`,
    )

    const hasCuratorRole = await accessManager.read.hasRole([curatorRoleId, curatorAddress])
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

  // ---------- GOVERNANCE & FOUNDATION (Only on Base) ----------
  if (chainKey === 'base') {
    console.log("Processing GOV and FOUNDATION roles for chain 'base'")

    // Process GOV role: grant to timelock endgame and revoke from current.
    if (specificRoles.gov) {
      const govEndgame = specificRoles.gov.endgame
      console.log(`Gov endgame target: ${govEndgame}`)

      const hasGovRole = await accessManager.read.hasRole([GOVERNANCE_ROLE, govEndgame])
      if (!hasGovRole) {
        console.log(`Granting GOV role to ${govEndgame}`)
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
        console.log(`Gov role already granted to ${govEndgame}.`)
      }

      const currentGovs = specificRoles.gov.current
      if (Array.isArray(currentGovs)) {
        for (const govAddress of currentGovs) {
          console.log(`Revoking GOV role from current gov: ${govAddress}`)
          const revokeGovRoleCalldata = encodeFunctionData({
            abi: accessManager.abi,
            functionName: 'revokeGovernorRole',
            args: [govAddress],
          })
          transactions.push({
            to: accessManager.address,
            data: revokeGovRoleCalldata,
            value: '0',
          })
        }
      } else {
        console.log('No current GOV addresses found.')
      }
    } else {
      console.log("No GOV role configuration present for chain 'base'")
    }

    // Process FOUNDATION role: grant endgame and revoke from current.
    if (specificRoles.foundation) {
      const foundationEndgame = specificRoles.foundation.endgame
      console.log(`Foundation endgame target: ${foundationEndgame}`)

      const hasFoundationRole = await accessManager.read.hasRole([
        FOUNDATION_ROLE,
        foundationEndgame,
      ])
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
  globalRoles: any,
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
  summerToken: any,
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
  console.log('==== Completed handling Fleet Rewards ====')
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

  const transactions: TransactionBase[] = []

  /***** ROLES *****/
  // Handle roles with logging.
  await handleRoles(chainKey, globalRoles, specificRoles, accessManager, transactions)
  // Handle Super Keeper Role.
  await handleSuperKeeperRole(globalRoles, accessManager, transactions)

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
  console.log(`Using SummerToken at address: ${summerTokenAddress}`)
  const summerToken = await hre.viem.getContractAt('SummerToken' as string, summerTokenAddress)
  await handleTipStreams(summerToken, tipStreamsData, transactions)

  /***** FLEET REWARDS: Approval & Notify *****/
  await handleFleetRewards(chainKey, chainFleetRewardsData, summerToken, transactions)

  console.log(`\nFinal Safe transaction will include ${transactions.length} operation(s).`)
  // Log complete JSON dump
  console.log('Complete Transactions JSON:')
  console.log(JSON.stringify(transactions, null, 2))

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
