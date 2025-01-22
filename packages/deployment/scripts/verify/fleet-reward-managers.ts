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

  // Get config for current network
  const config = getConfigByNetwork(hre.network.name, {
    common: true,
    gov: true,
    core: false,
  })

  const accessManagerAddress = config.deployedContracts.gov.protocolAccessManager.address

  const journal = fs
    .readFileSync(journalPath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line) => JSON.parse(line))

  // Find RewardsManagerCreated event
  const rewardsManagerEvent = journal.find((entry) =>
    entry.receipt?.logs?.some((log) => log.topics[0] === REWARDS_MANAGER_CREATED_EVENT),
  )

  if (rewardsManagerEvent) {
    const rewardsManagerLog = rewardsManagerEvent.receipt.logs.find(
      (log) => log.topics[0] === REWARDS_MANAGER_CREATED_EVENT,
    )

    const rewardsManagerAddress = `0x${rewardsManagerLog.topics[1].slice(26)}`
    const fleetCommanderAddress = `0x${rewardsManagerLog.topics[2].slice(26)}`

    try {
      await hre.run('verify:verify', {
        address: rewardsManagerAddress,
        contract: 'src/contracts/FleetCommanderRewardsManager.sol:FleetCommanderRewardsManager',
        constructorArguments: [accessManagerAddress, fleetCommanderAddress],
      })
    } catch (error) {
      console.error('Error verifying contract:', error)
    }
  }
}

if (require.main === module) {
  verifyFactoryContracts(hre).catch(console.error)
}
