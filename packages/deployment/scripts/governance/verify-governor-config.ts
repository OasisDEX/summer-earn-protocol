import dotenv from 'dotenv'
import { createPublicClient, http } from 'viem'
import { arbitrum, base } from 'viem/chains'

dotenv.config()

// Simplified ABI for the functions we need
const governorAbi = [
  {
    inputs: [{ internalType: 'uint32', name: 'eid', type: 'uint32' }],
    name: 'peers',
    outputs: [{ internalType: 'bytes32', name: 'peer', type: 'bytes32' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'proposalChainId',
    outputs: [{ internalType: 'uint32', name: '', type: 'uint32' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'endpoint',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
]

function compareAddresses(actual: string, expected: string, label: string) {
  const isMatch = actual.toLowerCase() === expected.toLowerCase()
  console.log(`\n${label}:`)
  console.log('  Expected:', expected)
  console.log('  Actual:  ', actual)
  console.log('  Matches: ', isMatch ? '✅' : '❌')

  if (!isMatch) {
    console.log('  Differences:')
    // Compare each character and highlight differences
    for (let i = 0; i < actual.length; i++) {
      if (actual[i].toLowerCase() !== expected[i].toLowerCase()) {
        console.log(`    Position ${i}: Expected '${expected[i]}', Got '${actual[i]}'`)
      }
    }
  }
  return isMatch
}

async function verifyGovernorConfig(
  baseClient: any,
  arbClient: any,
  baseGovernor: `0x${string}`,
  arbGovernor: `0x${string}`,
) {
  console.log('\nVerifying governor configurations...')

  // Get Base governor config
  const baseEndpoint = await baseClient.readContract({
    address: baseGovernor,
    abi: governorAbi,
    functionName: 'endpoint',
  })

  const baseProposalChainId = await baseClient.readContract({
    address: baseGovernor,
    abi: governorAbi,
    functionName: 'proposalChainId',
  })

  // Get Arbitrum governor config
  const arbEndpoint = await arbClient.readContract({
    address: arbGovernor,
    abi: governorAbi,
    functionName: 'endpoint',
  })

  const arbProposalChainId = await arbClient.readContract({
    address: arbGovernor,
    abi: governorAbi,
    functionName: 'proposalChainId',
  })

  // Check peer configurations
  const basePeerOnArb = await baseClient.readContract({
    address: baseGovernor,
    abi: governorAbi,
    functionName: 'peers',
    args: [30110n], // Arbitrum EID
  })

  const arbPeerOnBase = await arbClient.readContract({
    address: arbGovernor,
    abi: governorAbi,
    functionName: 'peers',
    args: [30184n], // Base EID
  })

  console.log('\n=== Base Governor Configuration ===')
  console.log('Address:', baseGovernor)
  console.log('Endpoint:', baseEndpoint)
  console.log('Proposal Chain ID:', baseProposalChainId)
  console.log('Peer on Arbitrum:', basePeerOnArb)

  console.log('\n=== Arbitrum Governor Configuration ===')
  console.log('Address:', arbGovernor)
  console.log('Endpoint:', arbEndpoint)
  console.log('Proposal Chain ID:', arbProposalChainId)
  console.log('Peer on Base:', arbPeerOnBase)

  // Verify peer configurations with detailed comparison
  const baseAddressBytes = `0x000000000000000000000000${baseGovernor.slice(2)}`
  const arbAddressBytes = `0x000000000000000000000000${arbGovernor.slice(2)}`

  console.log('\n=== Peer Configuration Verification ===')

  const basePeerCorrect = compareAddresses(basePeerOnArb, arbAddressBytes, 'Base peer on Arbitrum')

  const arbPeerCorrect = compareAddresses(arbPeerOnBase, baseAddressBytes, 'Arbitrum peer on Base')

  console.log('\n=== Configuration Summary ===')
  console.log('Endpoints match:', baseEndpoint === arbEndpoint ? '✅' : '❌')
  if (baseEndpoint !== arbEndpoint) {
    console.log('  Base endpoint:    ', baseEndpoint)
    console.log('  Arbitrum endpoint:', arbEndpoint)
  }

  console.log('Proposal Chain IDs match:', baseProposalChainId === arbProposalChainId ? '✅' : '❌')
  if (baseProposalChainId !== arbProposalChainId) {
    console.log('  Base chain ID:    ', baseProposalChainId)
    console.log('  Arbitrum chain ID:', arbProposalChainId)
  }

  console.log('Peer configurations correct:', basePeerCorrect && arbPeerCorrect ? '✅' : '❌')

  if (!basePeerCorrect || !arbPeerCorrect) {
    console.log('\n⚠️  Action Required:')
    if (!basePeerCorrect) {
      console.log(`Run setPeer(30110, "${arbAddressBytes}") on Base Governor`)
    }
    if (!arbPeerCorrect) {
      console.log(`Run setPeer(30184, "${baseAddressBytes}") on Arbitrum Governor`)
    }
  }
}

async function main() {
  const baseClient = createPublicClient({
    chain: base,
    transport: http(process.env.BASE_RPC_URL),
  })

  const arbClient = createPublicClient({
    chain: arbitrum,
    transport: http(process.env.ARBITRUM_RPC_URL),
  })

  await verifyGovernorConfig(
    baseClient,
    arbClient,
    process.env.BASE_SUMMER_GOVERNOR_ADDRESS! as `0x${string}`,
    process.env.ARB_SUMMER_GOVERNOR_ADDRESS! as `0x${string}`,
  )
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
