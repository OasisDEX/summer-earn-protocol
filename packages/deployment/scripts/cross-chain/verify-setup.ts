import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address, getAddress } from 'viem'
import { BaseConfig } from '../../types/config-types'
import {
  CrossChainConfig,
  getCrossChainConfigStatus,
  loadCrossChainConfig,
} from '../lib/config/cross-chain'
import { getConfigByNetwork } from '../lib/config/handler'
import { promptForConfigType } from '../lib/infrastructure/prompts'

const REGISTRY_ABI = [
  {
    inputs: [
      { internalType: 'address', name: 'sourceContract', type: 'address' },
      { internalType: 'address', name: 'targetContract', type: 'address' },
      { internalType: 'uint16', name: 'sourceChainId', type: 'uint16' },
      { internalType: 'uint16', name: 'targetChainId', type: 'uint16' },
      { internalType: 'bytes32', name: 'relationshipType', type: 'bytes32' },
    ],
    name: 'isValidCrossChainPair',
    outputs: [{ internalType: 'bool', name: 'isValid', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'sourceContract', type: 'address' },
      { internalType: 'bytes32', name: 'relationshipType', type: 'bytes32' },
    ],
    name: 'getTargetsForSource',
    outputs: [
      { internalType: 'address[]', name: 'targetContracts', type: 'address[]' },
      { internalType: 'uint16[]', name: 'targetChainIds', type: 'uint16[]' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'PEER_RELATIONSHIP',
    outputs: [{ internalType: 'bytes32', name: '', type: 'bytes32' }],
    stateMutability: 'pure',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: 'executor', type: 'address' }],
    name: 'isAuthorizedExecutor',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

function listCrossChainConfigs(): string[] {
  const fs = require('fs')
  const dir = path.join(process.cwd(), 'config', 'cross-chain')
  if (!fs.existsSync(dir)) return []
  return fs
    .readdirSync(dir)
    .filter((f: string) => f.endsWith('.json'))
    .sort()
}

async function chooseFleetConfig(): Promise<string | null> {
  const files = listCrossChainConfigs()
  if (files.length === 0) {
    console.log(kleur.yellow('No cross-chain config files found under config/cross-chain'))
    return null
  }

  const { selected } = await prompts({
    type: 'select',
    name: 'selected',
    message: 'Select a fleet cross-chain config to verify:',
    choices: files.map((f) => ({ title: f, value: f })),
  })
  return selected || null
}

async function verifyRelationship(
  registry: Address,
  sourceArk: Address,
  targetFleetProxy: Address,
  sourceChainId: number,
  targetChainId: number,
): Promise<boolean> {
  const publicClient = await hre.viem.getPublicClient()

  try {
    const peerRelationshipType = (await publicClient.readContract({
      address: getAddress(registry as `0x${string}`),
      abi: REGISTRY_ABI,
      functionName: 'PEER_RELATIONSHIP',
      args: [],
    })) as `0x${string}`

    const isValid = (await publicClient.readContract({
      address: getAddress(registry as `0x${string}`),
      abi: REGISTRY_ABI,
      functionName: 'isValidCrossChainPair',
      args: [
        getAddress(sourceArk as `0x${string}`),
        getAddress(targetFleetProxy as `0x${string}`),
        Number(sourceChainId),
        Number(targetChainId),
        peerRelationshipType,
      ],
    })) as boolean

    return isValid
  } catch (error) {
    console.log(kleur.red(`Error verifying relationship: ${error}`))
    return false
  }
}

async function verifyExecutor(registry: Address, executor: Address): Promise<boolean> {
  const publicClient = await hre.viem.getPublicClient()

  try {
    const isAuthorized = (await publicClient.readContract({
      address: getAddress(registry as `0x${string}`),
      abi: REGISTRY_ABI,
      functionName: 'isAuthorizedExecutor',
      args: [getAddress(executor as `0x${string}`)],
    })) as boolean

    return isAuthorized
  } catch (error) {
    console.log(kleur.red(`Error verifying executor: ${error}`))
    return false
  }
}

export async function verifyCrossChainSetup() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const useBummerConfig = await promptForConfigType()
  const localConfig = getConfigByNetwork(
    network,
    { common: true, gov: true, bridge: true },
    useBummerConfig,
  ) as BaseConfig

  const registryAddress = localConfig.deployedContracts.bridge?.crossChainRegistry
    ?.address as Address
  if (!registryAddress) throw new Error('CrossChainRegistry not deployed on this network')

  const localChainId = Number(localConfig.common.chainId)

  const chosen = await chooseFleetConfig()
  if (!chosen) return

  const fleetName = chosen.replace(/\.json$/, '')
  const cc: CrossChainConfig | null = loadCrossChainConfig(fleetName)
  if (!cc) throw new Error(`Failed to load cross-chain config for ${fleetName}`)

  console.log(
    kleur
      .green()
      .bold(
        `Verifying cross-chain setup on local registry (chainId=${localChainId}) for ${fleetName}...`,
      ),
  )

  // Check config status
  const configStatus = getCrossChainConfigStatus(fleetName)
  console.log(kleur.blue('\n📋 Configuration Status:'))
  console.log(kleur.blue(`Phase: ${configStatus.phase}`))
  console.log(kleur.blue(`Valid: ${configStatus.isValid ? '✅' : '❌'}`))

  if (configStatus.missingFields.length > 0) {
    console.log(kleur.yellow(`Missing fields: ${configStatus.missingFields.join(', ')}`))
  }

  if (configStatus.errors.length > 0) {
    console.log(kleur.red('Errors:'))
    configStatus.errors.forEach((error) => {
      console.log(kleur.red(`  • ${error}`))
    })
  }

  if (!configStatus.isValid) {
    console.log(
      kleur.red('\n❌ Configuration is incomplete. Please complete the deployment first.'),
    )
    return
  }

  console.log(kleur.green('\n🔍 On-Chain Verification:'))

  let totalRelationships = 0
  let validRelationships = 0
  let totalExecutors = 0
  let validExecutors = 0

  // Verify Ark-Fleet relationships
  console.log(kleur.blue('\n📡 Ark-Fleet Relationships:'))
  for (const dest of cc.destinations) {
    for (const protocol of dest.protocols) {
      const ark = protocol.crossChainArkAddress
      const fleetProxy = protocol.fleetProxyAddress

      if (!ark || !fleetProxy) continue

      // Verify only if this chain matches one side of the pair
      if (localChainId !== cc.sourceChainId && localChainId !== dest.chainId) continue

      totalRelationships += 1

      const sourceChainId = cc.sourceChainId
      const targetChainId = dest.chainId

      console.log(
        `- ${protocol.protocol}: ${kleur.blue(String(sourceChainId))} ARK -> ${kleur.blue(
          String(targetChainId),
        )} FLEET (ark=${ark}, fleet=${fleetProxy})`,
      )

      const isValid = await verifyRelationship(
        registryAddress,
        ark as Address,
        fleetProxy as Address,
        sourceChainId,
        targetChainId,
      )

      if (isValid) {
        validRelationships += 1
        console.log(kleur.green('  ✅ Relationship registered'))
      } else {
        console.log(kleur.red('  ❌ Relationship NOT registered'))
      }
    }
  }

  // Verify executors
  console.log(kleur.blue('\n👤 Executors:'))
  const candidates: Address[] = []

  try {
    const currentChainId = Number((localConfig as BaseConfig).common.chainId)
    const fs = require('fs')
    const cfgDir = path.resolve(__dirname, '..', '..', 'config', 'cross-chain')
    if (fs.existsSync(cfgDir)) {
      const files = fs
        .readdirSync(cfgDir)
        .filter((f: string) => f.endsWith('.json'))
        .map((f: string) => path.join(cfgDir, f))

      for (const file of files) {
        try {
          const raw = fs.readFileSync(file, 'utf8')
          const data = JSON.parse(raw) as {
            sourceChainId?: number
            destinations?: Array<{
              chainId: number
              protocols: Array<{
                protocol: string
                fleetProxyAddress?: string
                crossChainArkAddress?: string
              }>
            }>
          }

          // On source (hub) chain: CrossChainArk calls BridgeRouter → register CrossChainArk
          if (data?.sourceChainId && Number(data.sourceChainId) === currentChainId) {
            for (const dest of data.destinations ?? []) {
              for (const p of dest.protocols ?? []) {
                const addr = p.crossChainArkAddress
                if (addr && addr.startsWith('0x') && addr.length === 42) {
                  const normalized = getAddress(addr as `0x${string}`)
                  if (!candidates.includes(normalized)) candidates.push(normalized)
                }
              }
            }
          }

          // On destination (satellite) chain: FleetProxy calls BridgeRouter → register FleetProxy
          for (const dest of data.destinations ?? []) {
            if (Number(dest.chainId) === currentChainId) {
              for (const p of dest.protocols ?? []) {
                const addr = p.fleetProxyAddress
                if (addr && addr.startsWith('0x') && addr.length === 42) {
                  const normalized = getAddress(addr as `0x${string}`)
                  if (!candidates.includes(normalized)) candidates.push(normalized)
                }
              }
            }
          }
        } catch (err) {
          console.log(kleur.yellow(`Skipped invalid cross-chain config: ${file}`))
        }
      }
    }
  } catch (err) {
    console.log(kleur.red('Failed to load cross-chain executors from config:'), err)
  }

  for (const addr of candidates) {
    totalExecutors += 1
    console.log(`- Executor: ${addr}`)

    const isAuthorized = await verifyExecutor(registryAddress, addr)
    if (isAuthorized) {
      validExecutors += 1
      console.log(kleur.green('  ✅ Executor authorized'))
    } else {
      console.log(kleur.red('  ❌ Executor NOT authorized'))
    }
  }

  // Summary
  console.log(kleur.blue('\n📊 Summary:'))
  console.log(kleur.blue(`Relationships: ${validRelationships}/${totalRelationships} valid`))
  console.log(kleur.blue(`Executors: ${validExecutors}/${totalExecutors} authorized`))

  if (validRelationships === totalRelationships && validExecutors === totalExecutors) {
    console.log(kleur.green().bold('\n✅ All verifications passed! Cross-chain setup is complete.'))
  } else {
    console.log(
      kleur.yellow().bold('\n⚠️  Some verifications failed. Please check the issues above.'),
    )
    console.log(
      kleur.cyan(
        'Run: npx hardhat run scripts/cross-chain/register-relationships.ts --network <chain>',
      ),
    )
  }

  console.log(
    kleur.yellow(
      '\n💡 Tip: Run this script on both the source chain and each destination chain to verify complete setup.',
    ),
  )
}

if (require.main === module) {
  verifyCrossChainSetup().catch((error) => {
    console.error(kleur.red('Error during cross-chain setup verification:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}
