import fs from 'fs'
import hre from 'hardhat'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import path, { resolve } from 'path'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { promptForConfigType } from '../helpers/prompt-helpers'

const multiSources = [resolve(__dirname, '../../../core-contracts/src')]

async function verifyBufferArks(hre: HardhatRuntimeEnvironment) {
  for (const sourcePath of multiSources || []) {
    hre.config.paths.sources = sourcePath
    hre.config.paths.root = resolve(sourcePath, '..')
  }

  const useBummerConfig = await promptForConfigType()

  // Get config for current network
  const config = getConfigByNetwork(
    hre.network.name,
    {
      common: false,
      gov: true,
      core: true,
    },
    useBummerConfig,
  )

  const protocolAccessManager = config.deployedContracts.gov.protocolAccessManager.address
  const configurationManager = config.deployedContracts.core.configurationManager.address

  // Read all fleet deployment files from the deployments/fleets directory
  const fleetsDirectory = path.join(__dirname, '../../deployments/fleets')
  const fleetFiles = fs
    .readdirSync(fleetsDirectory)
    .filter((file) => file.endsWith('_deployment.json'))
    .filter((file) => {
      // Only process files for the current network
      const fileContent = JSON.parse(fs.readFileSync(path.join(fleetsDirectory, file), 'utf8'))
      return (
        fileContent.network === hre.network.name &&
        (useBummerConfig ? fileContent.isBummer === useBummerConfig : !fileContent.isBummer)
      )
    })

  console.log(`Found ${fleetFiles.length} fleet deployment files for network ${hre.network.name}`)

  for (const fleetFile of fleetFiles) {
    try {
      const fleetDeployment = JSON.parse(
        fs.readFileSync(path.join(fleetsDirectory, fleetFile), 'utf8'),
      )

      // Print the deployment data for debugging
      console.log(`Deployment data for ${fleetFile}:`, JSON.stringify(fleetDeployment, null, 2))

      // Extract fields with proper null/undefined checking
      const bufferArkAddress = fleetDeployment.bufferArkAddress
      const fleetAddress = fleetDeployment.fleetAddress
      const asset = config.tokens[fleetDeployment.assetSymbol]
      const fleetName = fleetDeployment.fleetName || 'Buffer Ark'
      const fleetDetails = fleetDeployment.fleetDetails || 'Buffer Ark for Fleet'

      if (!bufferArkAddress) {
        console.warn(`No buffer ARK address found in ${fleetFile}. Skipping.`)
        continue
      }

      if (!fleetAddress) {
        console.warn(`No fleet address found in ${fleetFile}. Skipping.`)
        continue
      }

      if (!asset) {
        console.warn(`No asset address found in ${fleetFile}. Skipping.`)
        continue
      }

      console.log(
        `Verifying buffer ARK for fleet at ${fleetAddress} and buffer ARK at ${bufferArkAddress}`,
      )

      // Set default values for optional parameters to avoid undefined
      const depositCap = fleetDeployment.depositCap || '0'
      const maxRebalanceOutflow = fleetDeployment.maxRebalanceOutflow || '0'
      const maxRebalanceInflow = fleetDeployment.maxRebalanceInflow || '0'
      const requiresKeeperData = fleetDeployment.requiresKeeperData || false
      const maxDepositPercentageOfTVL = fleetDeployment.maxDepositPercentageOfTVL || '0'

      // Prepare ArkParams according to ArkTypes.sol
      const arkParams = {
        name: 'BufferArk',
        details: 'BufferArk details',
        accessManager: protocolAccessManager,
        asset: asset,
        configurationManager: configurationManager,
        depositCap: MAX_UINT256_STRING,
        maxRebalanceOutflow: MAX_UINT256_STRING,
        maxRebalanceInflow: MAX_UINT256_STRING,
        requiresKeeperData: false,
        maxDepositPercentageOfTVL: HUNDRED_PERCENT,
      }

      // Log the verification parameters for debugging
      console.log('Verification parameters:', {
        address: bufferArkAddress,
        contract: 'src/contracts/arks/BufferArk.sol:BufferArk',
        arkParams: arkParams,
        fleetAddress: fleetAddress,
      })

      await hre.run('verify:verify', {
        address: bufferArkAddress,
        contract: 'src/contracts/arks/BufferArk.sol:BufferArk',
        constructorArguments: [arkParams, fleetAddress],
      })
      console.log(`Successfully verified buffer ARK at ${bufferArkAddress}`)
    } catch (error) {
      console.error(`Error processing ${fleetFile}:`, error)
    }
  }
}

if (require.main === module) {
  verifyBufferArks(hre).catch(console.error)
}

export { verifyBufferArks }
