import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { Address, encodeFunctionData, parseAbi } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { CANCELLER_ROLE, EXECUTOR_ROLE, GOVERNOR_ROLE, PROPOSER_ROLE } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { validateAddress } from '../helpers/validation'

/**
 * @dev Post-deployment governance setup
 *
 * Configuration sequence:
 * 1. Configure TimelockController roles
 *    - Grant PROPOSER_ROLE to SummerGovernor
 *    - Grant CANCELLER_ROLE to SummerGovernor
 *    - Grant EXECUTOR_ROLE to SummerGovernor
 *
 * 2. Configure ProtocolAccessManager roles
 *    - Grant GOVERNOR_ROLE to TimelockController
 */
export async function rolesGovV2(useBummerConfig = false) {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
  const config = getConfigByNetwork(
    hre.network.name,
    { common: false, gov: true, core: false },
    useBummerConfig,
  ) as BaseConfig

  const publicClient = await hre.viem.getPublicClient()
  const [deployer] = await hre.viem.getWalletClients()
  const deployerAddress = deployer.account.address

  const timelock = await hre.viem.getContractAt(
    'TimelockController' as string,
    validateAddress(config.deployedContracts.govV2.timelock.address, 'govV2.timelock'),
  )

  const summerGovernor = await hre.viem.getContractAt(
    'SummerGovernorV2' as string,
    validateAddress(config.deployedContracts.govV2.summerGovernor.address, 'govV2.summerGovernor'),
  )
  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    validateAddress(
      config.deployedContracts.govV2.protocolAccessManager.address,
      'govV2.protocolAccessManager',
    ),
  )

  // Determine if we're on HUB chain (currently BASE chain)
  const isHubChain = (await summerGovernor.read.HUB_CHAIN_ID()) === hre.network.config.chainId

  // Check if deployer has GOVERNOR_ROLE on ProtocolAccessManager
  const deployerHasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    deployerAddress,
  ])

  if (deployerHasGovernorRole) {
    console.log(kleur.green('Deployer has GOVERNOR_ROLE. Proceeding with direct configuration...'))
    await configureRolesDirectly(
      publicClient,
      timelock,
      summerGovernor,
      protocolAccessManager,
      isHubChain,
    )
  } else {
    console.log(
      kleur.yellow(
        'Deployer does NOT have GOVERNOR_ROLE. Creating Safe transaction proposal for FOUNDATION_MULTISIG_ADDRESS...',
      ),
    )
    await createGovernanceRolesSafeProposal(
      publicClient,
      timelock,
      summerGovernor,
      protocolAccessManager,
      isHubChain,
    )
  }

  console.log(kleur.green().bold('Governance roles setup completed!'))
}

async function configureRolesDirectly(
  publicClient: any,
  timelock: any,
  summerGovernor: any,
  protocolAccessManager: any,
  isHubChain: boolean,
) {
  // Set timelock as governor in ProtocolAccessManager
  console.log('[PROTOCOL ACCESS MANAGER] - Setting up governance...')

  // Handle timelock governor role
  const timelockHasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    timelock.address,
  ])
  if (!timelockHasGovernorRole) {
    console.log('[PROTOCOL ACCESS MANAGER] - Granting governor role to timelock...')
    const hash = await protocolAccessManager.write.grantGovernorRole([timelock.address])
    await publicClient.waitForTransactionReceipt({ hash })
  }

  const governorHasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    summerGovernor.address,
  ])
  if (!governorHasGovernorRole) {
    console.log('[PROTOCOL ACCESS MANAGER] - Granting governor role to SummerGovernor...')
    const hash = await protocolAccessManager.write.grantGovernorRole([summerGovernor.address])
    await publicClient.waitForTransactionReceipt({ hash })
  }

  // On satellite chains, grant CANCELLER_ROLE to timelock and PROPOSER_ROLE to governor
  if (!isHubChain) {
    const hasTimelockCancellerRole = await timelock.read.hasRole([CANCELLER_ROLE, timelock.address])
    if (!hasTimelockCancellerRole) {
      console.log('[TIMELOCK] - Granting CANCELLER_ROLE to timelock on satellite chain...')
      const hash = await timelock.write.grantRole([CANCELLER_ROLE, timelock.address])
      await publicClient.waitForTransactionReceipt({ hash })
    }

    const hasGovernorProposerRole = await timelock.read.hasRole([
      PROPOSER_ROLE,
      summerGovernor.address,
    ])
    if (!hasGovernorProposerRole) {
      console.log('[TIMELOCK] - Granting PROPOSER_ROLE to SummerGovernor on satellite chain...')
      const hash = await timelock.write.grantRole([PROPOSER_ROLE, summerGovernor.address])
      await publicClient.waitForTransactionReceipt({ hash })
    }
  }

  // On HUB chain only: Set up timelock roles
  if (isHubChain) {
    // Grant roles to SummerGovernor in Timelock
    const roles = [
      { name: 'PROPOSER_ROLE', value: PROPOSER_ROLE },
      { name: 'CANCELLER_ROLE', value: CANCELLER_ROLE },
      { name: 'EXECUTOR_ROLE', value: EXECUTOR_ROLE },
    ]

    for (const role of roles) {
      const hasRole = await timelock.read.hasRole([role.value, summerGovernor.address])
      if (!hasRole) {
        console.log(`[TIMELOCK] - Granting ${role.name} to SummerGovernor...`)
        const hash = await timelock.write.grantRole([role.value, summerGovernor.address])
        await publicClient.waitForTransactionReceipt({ hash })
      }
    }
  }
}

async function createGovernanceRolesSafeProposal(
  publicClient: any,
  timelock: any,
  summerGovernor: any,
  protocolAccessManager: any,
  isHubChain: boolean,
) {
  const foundationMultisig = process.env.FOUNDATION_MULTISIG_ADDRESS
  if (!foundationMultisig) {
    throw new Error('FOUNDATION_MULTISIG_ADDRESS environment variable is not set')
  }
  const multisigAddress = validateAddress(foundationMultisig, 'FOUNDATION_MULTISIG_ADDRESS')

  const transactions = []

  // 1. ProtocolAccessManager Actions
  // Grant GOVERNOR_ROLE to Timelock
  const timelockHasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    timelock.address,
  ])
  if (!timelockHasGovernorRole) {
    transactions.push({
      to: protocolAccessManager.address,
      value: '0',
      data: encodeFunctionData({
        abi: parseAbi(['function grantGovernorRole(address account) external']),
        functionName: 'grantGovernorRole',
        args: [timelock.address],
      }),
      contractMethod: {
        inputs: [{ name: 'account', type: 'address' }],
        name: 'grantGovernorRole',
        payable: false,
      },
      contractInputsValues: {
        account: timelock.address,
      },
    })
  }

  // Grant GOVERNOR_ROLE to SummerGovernor
  const governorHasGovernorRole = await protocolAccessManager.read.hasRole([
    GOVERNOR_ROLE,
    summerGovernor.address,
  ])
  if (!governorHasGovernorRole) {
    transactions.push({
      to: protocolAccessManager.address,
      value: '0',
      data: encodeFunctionData({
        abi: parseAbi(['function grantGovernorRole(address account) external']),
        functionName: 'grantGovernorRole',
        args: [summerGovernor.address],
      }),
      contractMethod: {
        inputs: [{ name: 'account', type: 'address' }],
        name: 'grantGovernorRole',
        payable: false,
      },
      contractInputsValues: {
        account: summerGovernor.address,
      },
    })
  }

  // 2. Timelock Actions
  // ABI for grantRole
  const grantRoleAbi = parseAbi(['function grantRole(bytes32 role, address account) external'])

  if (!isHubChain) {
    // Satellite Chain: Grant CANCELLER_ROLE to Timelock
    const hasTimelockCancellerRole = await timelock.read.hasRole([CANCELLER_ROLE, timelock.address])
    if (!hasTimelockCancellerRole) {
      transactions.push({
        to: timelock.address,
        value: '0',
        data: encodeFunctionData({
          abi: grantRoleAbi,
          functionName: 'grantRole',
          args: [CANCELLER_ROLE, timelock.address],
        }),
        contractMethod: {
          inputs: [
            { name: 'role', type: 'bytes32' },
            { name: 'account', type: 'address' },
          ],
          name: 'grantRole',
          payable: false,
        },
        contractInputsValues: {
          role: CANCELLER_ROLE,
          account: timelock.address,
        },
      })
    }

    // Satellite Chain: Grant PROPOSER_ROLE to Governor
    const hasGovernorProposerRole = await timelock.read.hasRole([
      PROPOSER_ROLE,
      summerGovernor.address,
    ])
    if (!hasGovernorProposerRole) {
      transactions.push({
        to: timelock.address,
        value: '0',
        data: encodeFunctionData({
          abi: grantRoleAbi,
          functionName: 'grantRole',
          args: [PROPOSER_ROLE, summerGovernor.address],
        }),
        contractMethod: {
          inputs: [
            { name: 'role', type: 'bytes32' },
            { name: 'account', type: 'address' },
          ],
          name: 'grantRole',
          payable: false,
        },
        contractInputsValues: {
          role: PROPOSER_ROLE,
          account: summerGovernor.address,
        },
      })
    }
  }

  if (isHubChain) {
    // Hub Chain: Grant PROPOSER, CANCELLER, EXECUTOR to Governor
    const roles = [
      { name: 'PROPOSER_ROLE', value: PROPOSER_ROLE },
      { name: 'CANCELLER_ROLE', value: CANCELLER_ROLE },
      { name: 'EXECUTOR_ROLE', value: EXECUTOR_ROLE },
    ]

    for (const role of roles) {
      const hasRole = await timelock.read.hasRole([role.value, summerGovernor.address])
      if (!hasRole) {
        transactions.push({
          to: timelock.address,
          value: '0',
          data: encodeFunctionData({
            abi: grantRoleAbi,
            functionName: 'grantRole',
            args: [role.value, summerGovernor.address],
          }),
          contractMethod: {
            inputs: [
              { name: 'role', type: 'bytes32' },
              { name: 'account', type: 'address' },
            ],
            name: 'grantRole',
            payable: false,
          },
          contractInputsValues: {
            role: role.value,
            account: summerGovernor.address,
          },
        })
      }
    }
  }

  if (transactions.length === 0) {
    console.log(kleur.green('No governance role changes required.'))
    return
  }

  // Create Safe transaction JSON
  const chainId = (await publicClient.getChainId()).toString()
  const timestamp = Date.now()

  const safeTransactionsJson = {
    version: '1.0',
    chainId: chainId,
    createdAt: timestamp,
    meta: {
      name: 'Configure Governance Roles',
      description: 'Grant necessary roles to Timelock and SummerGovernor',
      txBuilderVersion: '1.16.3',
      createdFromSafeAddress: multisigAddress,
      createdFromOwnerAddress: '',
      checksum: '',
    },
    transactions,
  }

  // Ensure proposals directory exists
  const proposalsDir = path.join(process.cwd(), 'proposals')
  if (!fs.existsSync(proposalsDir)) {
    fs.mkdirSync(proposalsDir, { recursive: true })
  }

  const fileName = `configure_gov_roles_safe_tx_${timestamp}.json`
  const outputPath = path.join(proposalsDir, fileName)

  fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))

  console.log(kleur.green(`✅ Saved Safe transaction proposal to ${outputPath}`))
  console.log(kleur.yellow('Please execute this transaction via the Safe Transaction Builder.'))
}

if (require.main === module) {
  rolesGovV2().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
