import hre from 'hardhat'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { createPublicClient, http } from 'viem'
import { getConfigByNetwork } from '../helpers/config-handler'

export async function verifyGovernanceRewardsManager(hre: HardhatRuntimeEnvironment) {
  const config = getConfigByNetwork(hre.network.name, {
    common: true,
    gov: true,
    core: false,
  })

  const publicClient = createPublicClient({
    chain: hre.network.config as any,
    transport: http(),
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
