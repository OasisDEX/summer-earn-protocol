import fs from 'fs'
import hre from 'hardhat'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import path, { resolve } from 'path'
import { getConfigByNetwork } from '../helpers/config-handler'

const REWARDS_MANAGER_CREATED_EVENT =
  '0x0b3397f9446e8b85cf96fe3194aeec84e2fd23ab014cf85f82805b36aef207aa'

const multiSources = [resolve(__dirname, '../../../core-contracts/src')]

async function verifyFactoryContracts(hre: HardhatRuntimeEnvironment) {
  for (const sourcePath of multiSources || []) {
    hre.config.paths.sources = sourcePath
    hre.config.paths.root = resolve(sourcePath, '..')
  }

  const chainId = hre.network.config.chainId?.toString()
  const journalPath = path.join(
    __dirname,
    `../../ignition/deployments/chain-${chainId}/journal.jsonl`,
  )
  console.log('journalPath', journalPath)

  // Get config for current network
  const config = getConfigByNetwork(
    hre.network.name,
    {
      common: true,
      gov: true,
      core: false,
    },
    true,
  )

  const accessManagerAddress = config.deployedContracts.gov.protocolAccessManager.address

  const journal = fs
    .readFileSync(journalPath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line) => JSON.parse(line))

  // Find all RewardsManagerCreated events
  const rewardsManagerEvents = journal.filter((entry) =>
    entry.receipt?.logs?.some((log) => log.topics[0] === REWARDS_MANAGER_CREATED_EVENT),
  )

  console.log(`Found ${rewardsManagerEvents.length} rewards manager events`)

  for (const rewardsManagerEvent of rewardsManagerEvents) {
    // Find all logs in this event that match our topic
    const rewardsManagerLogs = rewardsManagerEvent.receipt.logs.filter(
      (log) => log.topics[0] === REWARDS_MANAGER_CREATED_EVENT,
    )

    for (const rewardsManagerLog of rewardsManagerLogs) {
      const rewardsManagerAddress = `0x${rewardsManagerLog.topics[1].slice(26)}`
      const fleetCommanderAddress = `0x${rewardsManagerLog.topics[2].slice(26)}`

      console.log(
        `Verifying rewards manager at ${rewardsManagerAddress} for fleet commander ${fleetCommanderAddress}`,
      )

      try {
        await hre.run('verify:verify', {
          address: rewardsManagerAddress,
          contract: 'src/contracts/FleetCommanderRewardsManager.sol:FleetCommanderRewardsManager',
          constructorArguments: [accessManagerAddress, fleetCommanderAddress],
        })
        console.log(`Successfully verified rewards manager at ${rewardsManagerAddress}`)
      } catch (error) {
        console.error(`Error verifying contract at ${rewardsManagerAddress}:`, error)
      }
    }
  }
}

if (require.main === module) {
  verifyFactoryContracts(hre).catch(console.error)
}
