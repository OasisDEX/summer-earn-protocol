import { StandardMerkleTree } from '@openzeppelin/merkle-tree'
import fs from 'fs'
import path from 'path'
import prompts from 'prompts'

interface Distribution {
  [address: string]: string
}

interface TreeOutput {
  chainId: string
  distributionId: string
  merkleRoot: string
  totalAmount: string
  addressCount: number
  claims: {
    [address: string]: {
      amount: string
      proof: string[]
    }
  }
}

const CHAIN_NAMES: { [chainId: string]: string } = {
  '1': 'Ethereum Mainnet',
  '10': 'Optimism',
  '137': 'Polygon',
  '8453': 'Base',
  '42161': 'Arbitrum One',
}

function getChainName(chainId: string): string {
  return CHAIN_NAMES[chainId] || `Chain ${chainId}`
}

const distributionsDir = path.join(__dirname, '../token-distributions/')

async function selectChainAndFile(): Promise<{ chainId: string; filename: string } | null> {
  try {
    const inputDir = path.join(distributionsDir, 'input/')

    // Get all chain directories
    const chainDirs = fs
      .readdirSync(inputDir)
      .filter((file) => fs.statSync(path.join(inputDir, file)).isDirectory())
      .sort((a, b) => parseInt(a) - parseInt(b)) // Sort numerically

    if (chainDirs.length === 0) {
      console.error('No chain directories found in distributions/')
      return null
    }

    // Ask user to select chain
    const chainResponse = await prompts({
      type: 'select',
      name: 'chainId',
      message: 'Select chain:',
      choices: chainDirs.map((dir) => ({
        title: getChainName(dir),
        value: dir,
      })),
    })

    if (!chainResponse.chainId) return null

    // Get distribution files for selected chain
    const chainDir = path.join(inputDir, chainResponse.chainId, 'merkle-redeemer')
    const distributionFiles = fs
      .readdirSync(chainDir)
      .filter((file) => file.endsWith('.json'))
      .sort((a, b) => parseInt(a) - parseInt(b))

    if (distributionFiles.length === 0) {
      console.error(`No distribution files found in ${chainDir}/`)
      return null
    }

    // Ask user to select distribution file
    const fileResponse = await prompts({
      type: 'select',
      name: 'filename',
      message: 'Select distribution file:',
      choices: distributionFiles.map((file) => ({
        title: `Distribution ${path.basename(file, '.json')}`,
        value: file,
      })),
    })

    if (!fileResponse.filename) return null

    return {
      chainId: chainResponse.chainId,
      filename: fileResponse.filename,
    }
  } catch (error) {
    console.error('Error in selection:', error)
    return null
  }
}

function generateMerkleTree(distribution: Distribution) {
  const values = Object.entries(distribution).map(([address, amount]) => [address, amount])
  return StandardMerkleTree.of(values, ['address', 'uint256'])
}

function generateClaimsData(tree: StandardMerkleTree<any>, distribution: Distribution) {
  const claims: TreeOutput['claims'] = {}

  for (const [i, v] of tree.entries()) {
    const address = v[0]
    const amount = v[1]
    const proof = tree.getProof(i)

    claims[address] = {
      amount,
      proof,
    }
  }

  return claims
}

async function processDistributionFile(chainId: string, filename: string) {
  try {
    // Read and parse the JSON file
    const filePath = path.join(distributionsDir, 'input', chainId, 'merkle-redeemer', filename)
    const rawData = fs.readFileSync(filePath, 'utf8')
    const distribution: Distribution = JSON.parse(rawData)

    // Generate Merkle tree
    const tree = generateMerkleTree(distribution)

    // Get distribution number from filename
    const distributionNumber = path.basename(filename, '.json')

    // Calculate total amount
    const totalAmount = Object.values(distribution)
      .reduce((acc, val) => acc + BigInt(val), BigInt(0))
      .toString()

    // Generate claims data with proofs
    const claims = generateClaimsData(tree, distribution)

    // Prepare output data
    const outputData: TreeOutput = {
      chainId,
      distributionId: distributionNumber,
      merkleRoot: tree.root,
      totalAmount,
      addressCount: Object.keys(distribution).length,
      claims,
    }

    // Create chain-specific output directory
    const outputDir = path.join(distributionsDir, 'output', chainId, 'merkle-redeemer')
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true })
    }

    // Save tree data
    const outputPath = path.join(outputDir, `distribution-${distributionNumber}.json`)
    fs.writeFileSync(outputPath, JSON.stringify(outputData, null, 2))

    // Log results
    console.log('\nDistribution Summary:')
    console.log('-------------------')
    console.log(`Network: ${getChainName(chainId)} (${chainId})`)
    console.log(`Distribution: ${distributionNumber}`)
    console.log(`Merkle Root: ${outputData.merkleRoot}`)
    console.log(`Addresses: ${outputData.addressCount}`)
    console.log(`Total Amount: ${outputData.totalAmount}`)
    console.log(`Output: ${outputPath}`)
    console.log('-------------------')

    return outputData
  } catch (error) {
    console.error(`Error processing distribution ${filename} for chain ${chainId}:`, error)
    return null
  }
}
async function main() {
  console.log('🌳 Merkle Tree Generator\n')

  const selection = await selectChainAndFile()
  if (!selection) {
    console.error('Selection cancelled or failed')
    process.exit(1)
  }

  const { chainId, filename } = selection
  await processDistributionFile(chainId, filename)
}

// Handle CTRL+C and process termination
process.on('SIGINT', () => {
  console.log('\nProcess terminated by user')
  process.exit(0)
})

main().catch(console.error)
