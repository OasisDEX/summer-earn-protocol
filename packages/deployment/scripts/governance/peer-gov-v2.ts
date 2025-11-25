import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address, Hex } from 'viem'
import { BaseConfig, SupportedNetworks } from '../../types/config-types'
import { ADDRESS_ZERO } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { configureNewChainLayerZero } from './bridge/configure-new-chain-lz'
import { validateAddress } from '../helpers/validation'

interface PeerConfig {
  eid: number
  address: string
}

interface NetworkPeers {
  tokenPeers: PeerConfig[]
  governorPeers: PeerConfig[]
}
export async function peerGovV2(useBummerConfig = false) {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  // Ask if user wants to run LZ configuration first
  const { runLzConfig } = await prompts({
    type: 'confirm',
    name: 'runLzConfig',
    message: 'Do you want to run LayerZero configuration for a new chain first?',
    initial: false,
  })

  if (runLzConfig) {
    console.log(kleur.cyan().bold('\nRunning LayerZero configuration for new chain...\n'))
    try {
      // Call the imported function directly instead of using exec
      await configureNewChainLayerZero(useBummerConfig)
      console.log(kleur.green().bold('\nLayerZero configuration completed!'))
    } catch (error) {
      console.error(kleur.red().bold('\nLayerZero configuration failed:'), error)

      const { continueAnyway } = await prompts({
        type: 'confirm',
        name: 'continueAnyway',
        message: 'Do you want to continue with peering anyway?',
        initial: false,
      })

      if (!continueAnyway) {
        console.log(kleur.yellow('Peering process aborted.'))
        return
      }
    }
  }

  const config = getConfigByNetwork(
    hre.network.name,
    { common: false, gov: true, core: false },
    useBummerConfig,
  ) as BaseConfig

  if (config.common.layerZero.lzEndpoint === ADDRESS_ZERO) {
    throw new Error('LayerZero is not set up correctly')
  }

  // Get contract instances
  const summerToken = await hre.viem.getContractAt(
    'SummerToken' as string,
    config.deployedContracts.gov.summerToken.address as Address,
  )

  // Get contract instances
  const summerGovernor = await hre.viem.getContractAt(
    'SummerGovernorV2' as string,
    validateAddress(config.deployedContracts.govV2.summerGovernor.address, 'govV2.summerGovernor'),
  )
  const publicClient = await hre.viem.getPublicClient()

  // Get peers using existing configuration logic
  const peers = getPeersFromConfig(hre.network.name, useBummerConfig)

  // Set token peers
  console.log(kleur.cyan().bold('Setting token peers...'))
  for (const peer of peers.tokenPeers) {
    console.log(`Checking token peer for endpoint ${peer.eid}: ${peer.address}`)
    const peerAddressAsBytes32 = `0x000000000000000000000000${peer.address.slice(2)}` as Hex

    try {
      // Check if peer already exists with the same address
      const existingPeerAsBytes32 = await summerToken.read.peers([peer.eid])
      if ((existingPeerAsBytes32 as string).toLowerCase() === peerAddressAsBytes32.toLowerCase()) {
        console.log(kleur.yellow(`⚠ Token peer already set correctly for endpoint ${peer.eid}`))
        continue
      }

      const hash = await summerToken.write.setPeer([peer.eid, peerAddressAsBytes32])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green(`✓ Token peer set successfully for endpoint ${peer.eid}`))
    } catch (error) {
      console.error(kleur.red(`✗ Failed to set token peer for endpoint ${peer.eid}:`), error)
    }
  }

  // Set governor peers
  console.log(kleur.cyan().bold('\nSetting governor peers...'))
  for (const peer of peers.governorPeers) {
    console.log(`Checking governor peer for endpoint ${peer.eid}: ${peer.address}`)
    const peerAddressAsBytes32 = `0x000000000000000000000000${peer.address.slice(2)}` as Hex

    try {
      const existingPeerAsBytes32 = await summerGovernor.read.peers([peer.eid])
      if ((existingPeerAsBytes32 as string).toLowerCase() === peerAddressAsBytes32.toLowerCase()) {
        console.log(kleur.yellow(`⚠ Governor peer already set correctly for endpoint ${peer.eid}`))
        continue
      }

      const hash = await summerGovernor.write.setPeer([peer.eid, peerAddressAsBytes32])
      await publicClient.waitForTransactionReceipt({ hash })
      console.log(kleur.green(`✓ Governor peer set successfully for endpoint ${peer.eid}`))
    } catch (error) {
      console.error(kleur.red(`✗ Failed to set governor peer for endpoint ${peer.eid}:`), error)
    }
  }

  console.log(kleur.green().bold('\nPeering process completed!'))
}

// Reuse the existing peer configuration functions
function getPeersFromConfig(sourceNetwork: string, useBummerConfig = false): NetworkPeers {
  return {
    tokenPeers: getTokenPeers(sourceNetwork, useBummerConfig),
    governorPeers: getGovernorPeers(sourceNetwork, useBummerConfig),
  }
}
function getTokenPeers(sourceNetwork: string, useBummerConfig = false): PeerConfig[] {
  return getPeersForContract(
    sourceNetwork,
    (config) => ({
      address: validateAddress(
        config.deployedContracts.gov.summerToken.address,
        'govV2.summerToken',
      ),
      skipSatelliteToSatellite: false,
      label: 'TOKEN',
    }),
    useBummerConfig,
  )
}

function getGovernorPeers(sourceNetwork: string, useBummerConfig = false): PeerConfig[] {
  return getPeersForContract(
    sourceNetwork,
    (config) => ({
      address: validateAddress(
        config.deployedContracts.govV2.summerGovernor.address,
        'govV2.summerGovernor',
      ),
      skipSatelliteToSatellite: true,
      label: 'GOVERNOR',
    }),
    useBummerConfig,
  )
}

function getPeersForContract(
  sourceNetwork: string,
  getContractInfo: (config: any) => {
    address: string | undefined
    skipSatelliteToSatellite: boolean
    label: string
  },
  useBummerConfig = false,
): PeerConfig[] {
  const peers: PeerConfig[] = []
  const networks = Object.values(SupportedNetworks)
  const HUB_NETWORK = SupportedNetworks.BASE
  const isSourceHub = sourceNetwork === HUB_NETWORK

  for (const targetNetwork of networks) {
    if (targetNetwork === sourceNetwork) {
      console.log(
        kleur.blue().bold('Peering - skipping source network:'),
        kleur.cyan(targetNetwork),
      )
      continue
    }

    try {
      const networkConfig = getConfigByNetwork(
        targetNetwork,
        {
          common: false,
          gov: true,
          core: false,
        },
        useBummerConfig,
      ) as BaseConfig
      const { address, skipSatelliteToSatellite, label } = getContractInfo(networkConfig)
      const layerZeroEID = networkConfig.common?.layerZero?.eID

      const isTargetHub = targetNetwork === HUB_NETWORK

      if (!layerZeroEID) {
        console.log(
          kleur.yellow().bold('Peering - skipping network, missing LayerZero config:'),
          kleur.cyan(targetNetwork),
        )
        continue
      }

      if (skipSatelliteToSatellite && !isSourceHub && !isTargetHub) {
        console.log(
          kleur.blue().bold(`Peering - ${label} - skipping satellite-to-satellite peering:`),
          kleur.cyan(`${sourceNetwork} -> ${targetNetwork}`),
        )
        continue
      }

      if (address && address !== ADDRESS_ZERO) {
        peers.push({
          eid: parseInt(layerZeroEID),
          address,
        })
      } else {
        console.log(
          kleur.yellow().bold('Peering - skipping network, no valid contract address:'),
          kleur.cyan(targetNetwork),
        )
      }
    } catch (error) {
      console.log(kleur.red().bold('Error processing network config:'), kleur.cyan(targetNetwork))
      console.error(error)
      continue
    }
  }

  return peers
}

// Execute the script
if (require.main === module) {
  // Parse command line arguments
  const args = process.argv.slice(2)
  const useBummerConfig = args.includes('--bummer')

  peerGovV2(useBummerConfig).catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
