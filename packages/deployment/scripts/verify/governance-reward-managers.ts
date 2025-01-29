import dotenv from 'dotenv'
import hre from 'hardhat'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { resolve } from 'path'
import { createPublicClient, http } from 'viem'
import { ChainName, chainConfigs } from '../helpers/chain-configs'
import { getConfigByNetwork } from '../helpers/config-handler'

dotenv.config()

const multiSources = [resolve(__dirname, '../../../gov-contracts/src')]

export async function verifyGovernanceRewardsManager(hre: HardhatRuntimeEnvironment) {
  for (const sourcePath of multiSources || []) {
    hre.config.paths.sources = sourcePath
    hre.config.paths.root = resolve(sourcePath, '..')
  }

  const config = getConfigByNetwork(hre.network.name, {
    common: true,
    gov: true,
    core: false,
  })
  const chainConfig = chainConfigs[hre.network.name as ChainName]

  const publicClient = createPublicClient({
    chain: chainConfig.chain,
    transport: http(chainConfig.rpcUrl),
  })

  // Get the rewards manager address by calling the contract
  const rewardsManagerAddress = await publicClient.readContract({
    address: config.deployedContracts.gov.summerToken.address as `0x${string}`,
    abi: [
      {
        inputs: [],
        name: 'rewardsManager',
        outputs: [{ type: 'address' }],
        stateMutability: 'view',
        type: 'function',
      },
    ],
    functionName: 'rewardsManager',
  })

  try {
    await hre.run('verify:verify', {
      address: rewardsManagerAddress,
      contract: 'src/contracts/GovernanceRewardsManager.sol:GovernanceRewardsManager',
      constructorArguments: [
        config.deployedContracts.gov.summerToken.address,
        config.deployedContracts.gov.protocolAccessManager.address,
      ],
    })
  } catch (error) {
    console.error('Error verifying contract:', error)
  }
}

if (require.main === module) {
  verifyGovernanceRewardsManager(hre).catch(console.error)
}
