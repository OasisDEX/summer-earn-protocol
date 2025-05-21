import dotenv from 'dotenv'
import hre from 'hardhat'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { resolve } from 'path'

dotenv.config()

// Configure the source paths
const multiSources = [resolve(__dirname, '../../../chain-bridge/src')]

async function verifyBridgeRouter(hre: HardhatRuntimeEnvironment) {
  // Set the source paths correctly
  for (const sourcePath of multiSources) {
    hre.config.paths.sources = sourcePath
    hre.config.paths.root = resolve(sourcePath, '..')
  }

  // Contract details
  const bridgeRouterAddress = '0x1021D49B0BdacA6b2b250e7eA42be91650D1bc19'
  const accessManager = '0x2e208e55075b1cF15A767C15Ee9bA14205CB8371'
  const bridgeQueue = '0x0000000000000000000000000000000000000000'
  const chainIds = [8453]
  const routerAddresses = ['0x83914EB3BD89683a1687457085bDf7caF28aCd40']
  //   const chainIds = []
  //   const routerAddresses = []

  console.log('Verifying BridgeRouter contract on Arbitrum...')

  try {
    await hre.run('verify:verify', {
      address: bridgeRouterAddress,
      contract: 'src/router/BridgeRouter.sol:BridgeRouter',
      constructorArguments: [accessManager, bridgeQueue, chainIds, routerAddresses],
    })

    console.log('BridgeRouter verification successful!')
  } catch (error) {
    console.error('Verification failed:', error)
  }
}

if (require.main === module) {
  verifyBridgeRouter(hre).catch(console.error)
}
