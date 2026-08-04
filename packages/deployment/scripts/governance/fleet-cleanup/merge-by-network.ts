import fs from 'node:fs'
import path from 'node:path'

import kleur from 'kleur'
import { Address, encodeFunctionData, getAddress, Hex, parseAbi } from 'viem'

import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../../common/constants'
import { ChainName, getChainConfigByChainName } from '../../helpers/chain-configs'
import { hashDescription } from '../../helpers/hash-description'
import { constructLzOptions } from '../../helpers/layerzero-options'
import { proposalsDir } from './common'

interface ProposalDetails {
  title: string
  description: string
  governorId: string
  targets: Address[]
  values: string[]
  calldatas: Hex[]
  discourseURL?: string
  timestamp: number
  crossChainExecution?: Array<{
    name: string
    chainId: number
    targets: string[]
    values: string[]
    datas: string[]
    predecessor?: string
    delay?: string
  }>
}

async function main() {
  const dir = proposalsDir()
  const today = new Date().toISOString().slice(0, 10)

  // Find all cleanup proposal files generated today that match per-fleet pattern
  const allFiles = fs
    .readdirSync(dir)
    .filter(
      (f) =>
        f.startsWith('prod_fleet_cleanup_proposal_') &&
        f.includes(today) &&
        !f.includes('_round2_'),
    )

  const networks = ['mainnet', 'base', 'arbitrum', 'sonic'] as const

  for (const network of networks) {
    const rawNetFiles = allFiles.filter((f) => f.includes(`_${network}_`))
    if (rawNetFiles.length === 0) continue

    // Deduplicate keeping the latest timestamp for each fleet
    const latestByFleet = new Map<string, string>()
    for (const f of rawNetFiles.sort()) {
      // file pattern: prod_fleet_cleanup_proposal_<FleetName>_<network>_<timestamp>.json
      const fleetName = f.replace('prod_fleet_cleanup_proposal_', '').split(`_${network}_`)[0]
      latestByFleet.set(fleetName, f)
    }
    const netFiles = Array.from(latestByFleet.values())

    console.log(
      kleur.blue(
        `\n================ Merging proposals for ${network} (${netFiles.length} fleets) ================`,
      ),
    )

    const isHub = network === HUB_CHAIN_NAME
    const hubSetup = getChainConfigByChainName(HUB_CHAIN_NAME as ChainName, false)
    const hubGovernor = getAddress(hubSetup.config.deployedContracts.govV2.summerGovernor.address)

    const fleetChainSetup = getChainConfigByChainName(network as ChainName, false)
    const fleetChainTimelock = getAddress(
      fleetChainSetup.config.deployedContracts.govV2.timelock.address,
    )

    const mergedTargetChainTargets: Address[] = []
    const mergedTargetChainValues: string[] = []
    const mergedTargetChainCalldatas: Hex[] = []
    const fleetDescriptions: string[] = []

    for (const file of netFiles) {
      const filePath = path.join(dir, file)
      const data = JSON.parse(fs.readFileSync(filePath, 'utf8')) as ProposalDetails
      console.log(kleur.cyan(`- Including: ${data.title}`))

      if (isHub) {
        mergedTargetChainTargets.push(...(data.targets as Address[]))
        mergedTargetChainValues.push(...data.values)
        mergedTargetChainCalldatas.push(...(data.calldatas as Hex[]))
      } else if (data.crossChainExecution && data.crossChainExecution[0]) {
        const cc = data.crossChainExecution[0]
        mergedTargetChainTargets.push(...(cc.targets as Address[]))
        mergedTargetChainValues.push(...cc.values)
        mergedTargetChainCalldatas.push(...(cc.datas as Hex[]))
      }

      const descBody = data.description.split('\n\n## Actions\n')[1] || data.description
      fleetDescriptions.push(`### ${data.title}\n\n${descBody}`)
    }

    const title = `Fleet cleanup — ${network.toUpperCase()} Round 2 (${netFiles.length} fleets)`
    const routingHeader = isHub
      ? `Executed on the ${HUB_CHAIN_NAME} hub by timelock ${fleetChainTimelock}.`
      : `Created on the ${HUB_CHAIN_NAME} hub and relayed via LayerZero to the ${network} timelock ${fleetChainTimelock} for execution.`

    const description = `# ${title}\n\n${routingHeader}\n\n` + fleetDescriptions.join('\n\n---\n\n')

    let proposal: ProposalDetails

    if (isHub) {
      proposal = {
        title,
        description,
        governorId: `eip155:${HUB_CHAIN_ID}:${hubGovernor}`,
        targets: mergedTargetChainTargets,
        values: mergedTargetChainValues,
        calldatas: mergedTargetChainCalldatas,
        timestamp: Date.now(),
      }
    } else {
      const targetEndpointId = fleetChainSetup.config.common.layerZero.eID
      const lzOptions = constructLzOptions(500000n)
      const valuesBigInt = mergedTargetChainValues.map((v) => BigInt(v))

      const crossChainCalldata = encodeFunctionData({
        abi: parseAbi([
          'function sendProposalToTargetChain(uint32 _dstEid, address[] _dstTargets, uint256[] _dstValues, bytes[] _dstCalldatas, bytes32 _dstDescriptionHash, bytes _options) external',
        ]),
        args: [
          Number(targetEndpointId),
          mergedTargetChainTargets,
          valuesBigInt,
          mergedTargetChainCalldatas,
          hashDescription(description),
          lzOptions,
        ],
      }) as Hex

      proposal = {
        title,
        description,
        governorId: `eip155:${HUB_CHAIN_ID}:${hubGovernor}`,
        targets: [hubGovernor],
        values: ['0'],
        calldatas: [crossChainCalldata],
        timestamp: Date.now(),
        crossChainExecution: [
          {
            name: network,
            chainId: fleetChainSetup.chain.id,
            targets: mergedTargetChainTargets,
            values: mergedTargetChainValues,
            datas: mergedTargetChainCalldatas,
            predecessor: '0x0000000000000000000000000000000000000000000000000000000000000000',
            delay: '0',
          },
        ],
      }
    }

    const outPath = path.join(dir, `prod_fleet_cleanup_proposal_${network}_round2_${today}.json`)
    fs.writeFileSync(outPath, JSON.stringify(proposal, null, 2) + '\n')
    console.log(kleur.green(`\n✓ Wrote merged ${network} proposal: ${outPath}`))
    console.log(
      kleur.yellow(
        `  Total target actions: ${isHub ? proposal.targets.length : proposal.crossChainExecution![0].targets.length}`,
      ),
    )
  }
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
