import dotenv from 'dotenv'
import hre from 'hardhat'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { resolve } from 'path'
import { getChainConfigByChainId } from '../core/chain'
import { getChainPublicClient } from '../core/clients'
import { getConfigByNetwork } from '../core/config'

dotenv.config()

const multiSources = [resolve(__dirname, '../../../gov-contracts/src')]

export async function verifyGovernanceRewardsManager(
  hre: HardhatRuntimeEnvironment,
  useBummerConfig: boolean = false,
) {
  for (const sourcePath of multiSources || []) {
    hre.config.paths.sources = sourcePath
    hre.config.paths.root = resolve(sourcePath, '..')
  }

  const config = getConfigByNetwork(
    hre.network.name,
    {
      common: true,
      gov: true,
      core: false,
    },
    useBummerConfig,
  )
  const chainConfig = getChainConfigByChainId(hre.network.config.chainId as number)
  const publicClient = await getChainPublicClient(chainConfig.chainName)

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
