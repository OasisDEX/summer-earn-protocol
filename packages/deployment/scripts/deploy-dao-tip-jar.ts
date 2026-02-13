import hre from 'hardhat'
import kleur from 'kleur'
import path from 'node:path'
import prompts from 'prompts'
import { Address, encodeFunctionData, getAddress, Hex } from 'viem'
import TipJarAbi from '../artifacts/src/contracts/TipJar.sol/TipJar.json'
import { createDaoTipJarModule, DaoTipJarContracts } from '../ignition/modules/dao-tip-jar'
import { BaseConfig } from '../types/config-types'
import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { getChainIdByNetwork } from './helpers/get-chainid'
import { hashDescription } from './helpers/hash-description'
import { constructLzOptions } from './helpers/layerzero-options'
import { fromIntegerPercentage } from './helpers/percentage'
import { promptForConfigType } from './helpers/prompt-helpers'
import { createGovernanceProposal } from './helpers/proposal-helpers'
import { updateIndexJson } from './helpers/update-json'
import { keccak256, toBytes } from 'viem'

const SIP_MAJOR = 1
const SIP_MINOR = 6
const SIP_PATCH = 1

// Summer -> 30%, BA -> 5%, Guardian -> 15%
// BA: 0xeaef8fb615a7d5ab6a356dec0549fd749460e970
// Guardian: 0x91E4482CF58aC14d8DC25290d828b2A4D9492BA4
// Summer: 0x6e7aE26175F9972e266B0e39288108597C152604
const DEFAULT_DAO_TIP_STREAMS = [
  {
    recipient: getAddress('0x6e7aE26175F9972e266B0e39288108597C152604'),
    allocation: fromIntegerPercentage(30),
  },
  {
    recipient: getAddress('0xeaef8fb615a7d5ab6a356dec0549fd749460e970'),
    allocation: fromIntegerPercentage(5),
  },
  {
    recipient: getAddress('0x91E4482CF58aC14d8DC25290d828b2A4D9492BA4'),
    allocation: fromIntegerPercentage(15),
  },
]

/** lockedUntilEpoch: 1 year from proposal creation (seconds) */
function getDefaultLockedUntilEpoch(): string {
  return String(Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60)
}

async function main() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const useBummerConfig = await promptForConfigType()
  const config = getConfigByNetwork(
    network,
    { common: true, gov: false, core: true },
    useBummerConfig,
  ) as BaseConfig

  const accessManager = config.deployedContracts.govV2.protocolAccessManager.address
  const configurationManager = config.deployedContracts.core.configurationManager.address
  const envLabel = useBummerConfig ? 'staging_' : ''

  const CREATE2_SALT = keccak256(toBytes(`${envLabel}_daoTipJar`))
  console.log(kleur.cyan().bold(`Deploying ${envLabel}DaoTipJar...`))

  const moduleName = `${envLabel}DaoTipJar`
  const DaoTipJarModule = createDaoTipJarModule(moduleName)
  const deployed = (await hre.ignition.deploy(DaoTipJarModule, {
    parameters: {
      [moduleName]: { accessManager, configurationManager },
    },
    strategy: 'create2',
    strategyConfig: {
      salt: CREATE2_SALT,
    },
  })) as DaoTipJarContracts

  const daoTipJarAddress = deployed.daoTipJar.address as Address
  console.log(kleur.green().bold('DaoTipJar deployed at:'), daoTipJarAddress)

  await updateIndexJson(
    'core',
    network,
    {
      ...(config.deployedContracts.core as Record<string, unknown>),
      daoTipJar: { address: daoTipJarAddress },
    } as Parameters<typeof updateIndexJson>[2],
    useBummerConfig,
  )

  // Create governance proposal (hub or cross-chain based on deployment network)
  const lockedUntilEpoch = getDefaultLockedUntilEpoch()
  const tipStreams = DEFAULT_DAO_TIP_STREAMS.map((s) => ({
    recipient: s.recipient,
    allocation: s.allocation,
    minTerm: lockedUntilEpoch,
  }))

  const confirmProposal = await prompts({
    type: 'confirm',
    name: 'continue',
    message: 'Create governance proposal for DaoTipJar tip streams?',
    initial: true,
  })

  if (!confirmProposal.continue) {
    console.log(kleur.yellow('Skipping proposal creation.'))
    return
  }

  const hubConfig = getConfigByNetwork(
    HUB_CHAIN_NAME,
    { common: true, core: true, gov: true },
    useBummerConfig,
  ) as BaseConfig
  const hubGovernorAddress = hubConfig.deployedContracts.govV2.summerGovernor.address as Address

  const addTipStreamAbi = TipJarAbi.abi.find(
    (item: { type?: string; name?: string }) =>
      item.type === 'function' && item.name === 'addTipStream',
  )
  if (!addTipStreamAbi) {
    throw new Error('addTipStream function not found in TipJar ABI')
  }

  const title = `SIP ${SIP_MAJOR}.${SIP_MINOR}.${SIP_PATCH}: DaoTipJar Setup on ${network}`
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const savePath = path.join(
    process.cwd(),
    'proposals',
    `${useBummerConfig ? 'test_' : ''}dao_tipjar_${network}_${timestamp}.json`,
  )

  if (network === HUB_CHAIN_NAME) {
    // Hub proposal: direct addTipStream actions on Base
    const targets: Address[] = []
    const values: bigint[] = []
    const calldatas: Hex[] = []

    for (const stream of tipStreams) {
      targets.push(daoTipJarAddress)
      values.push(0n)
      calldatas.push(
        encodeFunctionData({
          abi: [addTipStreamAbi],
          functionName: 'addTipStream',
          args: [
            {
              recipient: stream.recipient,
              allocation: BigInt(stream.allocation),
              lockedUntilEpoch: BigInt(stream.minTerm),
            },
          ],
        }),
      )
    }

    const description = buildProposalDescription(network, daoTipJarAddress, tipStreams)
    const actions = targets.map((target, i) => ({
      target,
      value: values[i],
      calldata: calldatas[i],
    }))

    await createGovernanceProposal(
      title,
      description,
      actions,
      hubGovernorAddress,
      HUB_CHAIN_ID,
      '',
      [`Add ${tipStreams.length} tip streams to DaoTipJar on ${network}`],
      savePath,
    )
    console.log(kleur.green('Hub proposal created. Submit on Base.'))
  } else {
    // Cross-chain proposal: send from hub to target chain
    const deployChainConfig = config
    const dstEid = deployChainConfig.common.layerZero.eID
    const chainId = getChainIdByNetwork(network)

    const dstTargets: Address[] = []
    const dstValues: bigint[] = []
    const dstCalldatas: Hex[] = []

    for (const stream of tipStreams) {
      dstTargets.push(daoTipJarAddress)
      dstValues.push(0n)
      dstCalldatas.push(
        encodeFunctionData({
          abi: [addTipStreamAbi],
          functionName: 'addTipStream',
          args: [
            {
              recipient: stream.recipient,
              allocation: BigInt(stream.allocation),
              lockedUntilEpoch: BigInt(stream.minTerm),
            },
          ],
        }),
      )
    }

    const dstDescription = `
# DaoTipJar Setup on ${network}

## Summary
Configure tip streams on the DaoTipJar deployed at ${daoTipJarAddress}.

## Actions
- Add ${tipStreams.length} tip streams with allocations: ${tipStreams
      .map((s) => `${Number(BigInt(s.allocation) / BigInt(1e18))}%`)
      .join(', ')}
    `.trim()

    const ESTIMATED_GAS = 400000n
    const lzOptions = constructLzOptions(ESTIMATED_GAS)

    const actions = [
      {
        target: hubGovernorAddress,
        value: 0n,
        calldata: encodeFunctionData({
          abi: [
            {
              name: 'sendProposalToTargetChain',
              type: 'function',
              inputs: [
                { name: '_dstEid', type: 'uint32' },
                { name: '_dstTargets', type: 'address[]' },
                { name: '_dstValues', type: 'uint256[]' },
                { name: '_dstCalldatas', type: 'bytes[]' },
                { name: '_dstDescriptionHash', type: 'bytes32' },
                { name: '_options', type: 'bytes' },
              ],
              outputs: [],
              stateMutability: 'nonpayable',
            },
          ],
          functionName: 'sendProposalToTargetChain',
          args: [
            Number(dstEid),
            dstTargets,
            dstValues,
            dstCalldatas,
            hashDescription(dstDescription),
            lzOptions,
          ],
        }),
      },
    ]

    const crossChainExecutions = [
      {
        name: network,
        chainId: Number(chainId),
        targets: dstTargets.map((t) => t as string),
        values: dstValues.map((v) => v.toString()),
        datas: dstCalldatas.map((c) => c as string),
      },
    ]

    const description = buildProposalDescription(network, daoTipJarAddress, tipStreams)

    await createGovernanceProposal(
      title,
      description,
      actions,
      hubGovernorAddress,
      HUB_CHAIN_ID,
      '',
      [`Send cross-chain proposal to ${network} to add DaoTipJar tip streams`],
      savePath,
      crossChainExecutions,
    )
    console.log(kleur.green(`Cross-chain proposal created. Submit on Base to target ${network}.`))
  }

  console.log(kleur.yellow('Proposal saved to:'), savePath)
}

function buildProposalDescription(
  network: string,
  daoTipJarAddress: string,
  tipStreams: Array<{ recipient: string; allocation: string; minTerm: string }>,
): string {
  return `
# SIP ${SIP_MAJOR}.${SIP_MINOR}.${SIP_PATCH}: DaoTipJar Setup on ${network}

## Summary
Configure tip streams on the DaoTipJar contract deployed for DAO fleets.

## DaoTipJar Address
${daoTipJarAddress}

## Tip Streams
${tipStreams
  .map(
    (s, i) =>
      `- Stream ${i + 1}: ${s.recipient}, ${Number(BigInt(s.allocation) / BigInt(1e18))}%, locked until epoch ${s.minTerm}`,
  )
  .join('\n')}

## Actions
${network === HUB_CHAIN_NAME ? `Add ${tipStreams.length} tip streams to DaoTipJar on Base.` : `Send cross-chain proposal to ${network} to add ${tipStreams.length} tip streams to DaoTipJar.`}
  `.trim()
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
