import kleur from 'kleur'
import prompts from 'prompts'
import { registerAdapterPeers } from './bridge/register-adapter-peers'
import { registerArkFleetRelationships } from './bridge/register-ark-fleet'
import { registerExecutors } from './bridge/register-executors'

type ActionKey = 'peers' | 'arkFleet' | 'executors' | 'exit'

async function main() {
  console.log(kleur.green().bold('Cross-Chain Registry Admin'))
  console.log(kleur.gray('Select an action to perform on the current network.'))

  // eslint-disable-next-line no-constant-condition
  while (true) {
    const { action } = await prompts({
      type: 'select',
      name: 'action',
      message: 'Choose an action:',
      choices: [
        { title: 'Register adapter peers (LayerZero/Stargate)', value: 'peers' },
        { title: 'Register ARK_FLEET relationships', value: 'arkFleet' },
        { title: 'Register executors', value: 'executors' },
        { title: 'Exit', value: 'exit' },
      ],
    })

    const key = action as ActionKey
    if (!key || key === 'exit') break

    try {
      if (key === 'peers') {
        await registerAdapterPeers()
      } else if (key === 'arkFleet') {
        await registerArkFleetRelationships()
      } else if (key === 'executors') {
        await registerExecutors()
      }
    } catch (error) {
      console.error(kleur.red('Action failed:'), error)
    }

    const { again } = await prompts({
      type: 'confirm',
      name: 'again',
      message: 'Do you want to perform another action?',
      initial: false,
    })
    if (!again) break
  }

  console.log(kleur.green('Goodbye!'))
}

if (require.main === module) {
  main().catch((error) => {
    console.error(kleur.red('Unexpected error in admin tool:'), error)
    process.exit(1)
  })
}
