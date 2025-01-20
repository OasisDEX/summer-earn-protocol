import hre from 'hardhat'
import kleur from 'kleur'
import { Address, Hex } from 'viem'
import { SupportedNetworks } from '../../types/config-types'
import { ADDRESS_ZERO } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'

interface PeerConfig {
  eid: number
  address: string
}

interface NetworkPeers {
  tokenPeers: PeerConfig[]
  governorPeers: PeerConfig[]
}

export async function peerGov() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
  const config = getConfigByNetwork(hre.network.name, { common: true, gov: true, core: false })

  if (config.common.layerZero.lzEndpoint === ADDRESS_ZERO) {
    throw new Error('LayerZero is not set up correctly')
  }

  // Get contract instances
  const summerToken = await hre.viem.getContractAt(
    'SummerToken' as string,
    config.deployedContracts.gov.summerToken.address as Address,
  )
  const summerGovernor = await hre.viem.getContractAt(
    'SummerGovernor' as string,
    config.deployedContracts.gov.summerGovernor.address as Address,
  )
  const publicClient = await hre.viem.getPublicClient()

  // Get peers using existing configuration logic
  const peers = getPeersFromConfig(hre.network.name)

  // Set token peers
  console.log(kleur.cyan().bold('Setting token peers...'))
  for (const peer of peers.tokenPeers) {
    console.log(`Setting token peer for endpoint ${peer.eid}: ${peer.address}`)
    const peerAddressAsBytes32 = `0x000000000000000000000000${peer.address.slice(2)}` as Hex
    try {
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
    console.log(`Setting governor peer for endpoint ${peer.eid}: ${peer.address}`)
    const peerAddressAsBytes32 = `0x000000000000000000000000${peer.address.slice(2)}` as Hex
    try {
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
function getPeersFromConfig(sourceNetwork: string): NetworkPeers {
  return {
    tokenPeers: getTokenPeers(sourceNetwork),
    governorPeers: getGovernorPeers(sourceNetwork),
  }
}

function getTokenPeers(sourceNetwork: string): PeerConfig[] {
  return getPeersForContract(sourceNetwork, (config) => ({
    address: config.deployedContracts?.gov?.summerToken?.address,
    skipSatelliteToSatellite: false,
    label: 'TOKEN',
  }))
}

function getGovernorPeers(sourceNetwork: string): PeerConfig[] {
  return getPeersForContract(sourceNetwork, (config) => ({
    address: config.deployedContracts?.gov?.summerGovernor?.address,
    skipSatelliteToSatellite: true,
    label: 'GOVERNOR',
  }))
}

function getPeersForContract(
  sourceNetwork: string,
  getContractInfo: (config: any) => {
    address: string | undefined
    skipSatelliteToSatellite: boolean
    label: string
  },
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
      const networkConfig = getConfigByNetwork(targetNetwork, {
        common: true,
        gov: true,
        core: false,
      })
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
  peerGov().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
