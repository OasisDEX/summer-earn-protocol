import { exec } from 'child_process'
import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { promisify } from 'util'
import { finalizeGov } from './governance/finalize-gov'
import { peerGov } from './governance/peer-gov'
import { rolesGov } from './governance/roles-gov'
import { deployGov as systemGov } from './governance/system-gov'
import { verifyGovernanceRewardsManager } from './verify/governance-reward-managers'

const STEPS = {
  SYSTEM: 'system-gov',
  ROLES: 'roles-gov',
  PEER: 'peer-gov',
  FINALIZE: 'finalize-gov',
  VERIFY: 'verify-contracts',
} as const

async function deployGov() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  let continueDeployment = true
  while (continueDeployment) {
    const { step } = await prompts({
      type: 'select',
      name: 'step',
      message: 'Which deployment step would you like to run?',
      choices: [
        {
          title: '1. Deploy Governance System (system-gov.ts)',
          description: 'Deploys the initial governance contracts',
          value: STEPS.SYSTEM,
        },
        {
          title: '2. Verify Contracts',
          description: 'Verifies deployed contracts on the network explorer',
          value: STEPS.VERIFY,
        },
        {
          title: '3. Configure Roles (roles-gov.ts)',
          description: 'Sets up all roles but leaves ownership with deployer',
          value: STEPS.ROLES,
        },
        {
          title: '4. Configure Peers (peer-gov.ts)',
          description: 'Sets up peers between all deployed chains',
          value: STEPS.PEER,
        },
        {
          title: '5. Finalize Governance (finalize-gov.ts)',
          description: 'Transfers ownership to timelock - changes are locked after this step',
          value: STEPS.FINALIZE,
        },
        {
          title: 'Exit',
          value: 'exit',
        },
      ],
      initial: 0,
      onState: (state) => {
        if (state.aborted) {
          console.log(kleur.red().bold('\nDeployment process exited!'))
          process.exit(0)
        }
      },
    })

    if (step === 'exit') {
      continueDeployment = false
      console.log(kleur.red().bold('\nDeployment process exited!'))
      break
    }

    try {
      console.log(kleur.cyan().bold(`\nExecuting ${step}...\n`))

      switch (step) {
        case STEPS.SYSTEM:
          await systemGov()
          break
        case STEPS.VERIFY:
          console.log(kleur.yellow().bold('\nVerifying contracts...\n'))
          const chainId = hre.network.config.chainId
          if (!chainId) {
            throw new Error('Chain ID not found in network config')
          }
          try {
            const execPromise = promisify(exec)
            const { stdout, stderr } = await execPromise(
              `pnpm hardhat ignition verify chain-${chainId}`,
            )

            if (stdout) console.log(stdout)
            if (stderr) console.error(kleur.red(stderr))

            // Add verification for governance rewards manager
            console.log(kleur.yellow().bold('\nVerifying Governance Rewards Manager...\n'))
            await verifyGovernanceRewardsManager(hre)

            console.log(kleur.green().bold('\nContract verification completed successfully!'))
          } catch (error) {
            console.error(kleur.red().bold('\nContract verification failed:'), error)
            throw error
          }
          break
        case STEPS.ROLES:
          const { additionalGovernors } = await prompts({
            type: 'text',
            name: 'additionalGovernors',
            message:
              'Enter additional governor addresses (comma-separated) or press enter to skip:',
            validate: (value) =>
              value === '' || // Allow empty input
              value.split(',').every((addr: string) => /^0x[a-fA-F0-9]{40}$/.test(addr.trim())) ||
              'Please enter valid Ethereum addresses separated by commas',
          })

          const governorAddresses = additionalGovernors
            ? additionalGovernors.split(',').map((addr: string) => addr.trim())
            : []

          await rolesGov(governorAddresses)
          break
        case STEPS.PEER:
          const { confirmPeering } = await prompts({
            type: 'confirm',
            name: 'confirmPeering',
            message: kleur
              .yellow()
              .bold(
                '\n⚠️  WARNING: This step requires all chains to be deployed first.\n' +
                  'Make sure you have already run steps 1 & 2 on all networks you want to peer.\n' +
                  'Are you sure all chains are ready for peering?',
              ),
            initial: false,
          })
          if (confirmPeering) {
            await peerGov()
          } else {
            console.log(kleur.yellow('Peering cancelled'))
          }
          break
        case STEPS.FINALIZE:
          const { confirmed } = await prompts({
            type: 'confirm',
            name: 'confirmed',
            message: kleur
              .yellow()
              .bold(
                '\n⚠️  WARNING: This step will transfer ownership to the timelock contract.\n' +
                  'After this step, all changes must go through governance.\n' +
                  'Are you sure you want to proceed?',
              ),
            initial: false,
          })
          if (confirmed) {
            const { addressesToRevoke } = await prompts({
              type: 'text',
              name: 'addressesToRevoke',
              message:
                'Enter governor addresses to revoke (comma-separated) or press enter to skip:',
              validate: (value) =>
                value === '' || // Allow empty input
                value.split(',').every((addr: string) => /^0x[a-fA-F0-9]{40}$/.test(addr.trim())) ||
                'Please enter valid Ethereum addresses separated by commas',
            })

            const governorAddressesToRevoke = addressesToRevoke
              ? addressesToRevoke.split(',').map((addr: string) => addr.trim())
              : []

            await finalizeGov(governorAddressesToRevoke)
          } else {
            console.log(kleur.yellow('Finalization cancelled'))
          }
          break
      }

      const { continue: shouldContinue } = await prompts({
        type: 'confirm',
        name: 'continue',
        message: 'Would you like to run another step?',
        initial: true,
      })

      continueDeployment = shouldContinue
    } catch (error) {
      console.error(kleur.red().bold(`\nError during ${step}:`), error)

      const { retry } = await prompts({
        type: 'confirm',
        name: 'retry',
        message: 'Would you like to retry this step?',
        initial: true,
      })

      if (!retry) {
        const { exit } = await prompts({
          type: 'confirm',
          name: 'exit',
          message: 'Would you like to exit the deployment process?',
          initial: false,
        })

        if (exit) {
          continueDeployment = false
        }
      }
    }

    console.log(kleur.green().bold('\nDeployment process completed!'))
  }
}

// Execute the script
if (require.main === module) {
  deployGov().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
