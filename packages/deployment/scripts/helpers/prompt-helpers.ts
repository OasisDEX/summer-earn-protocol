import prompts from 'prompts'
import { Address } from 'viem'

export async function continueDeploymentCheck(message?: string) {
  const _message = message ?? 'Do you want to continue with the deployment?'

  const { confirmed } = await prompts({
    type: 'toggle',
    name: 'confirmed',
    initial: true,
    active: 'yes',
    inactive: 'no',
    message: _message,
  })

  return confirmed
}

export async function promptForAddresses(
  message: string = 'Enter the addresses to whitelist (comma separated):',
): Promise<Address[]> {
  const response = await prompts({
    type: 'text',
    name: 'addresses',
    message,
    validate: (value: string) => {
      const addresses = value.split(',').map((v) => v.trim())
      for (const addr of addresses) {
        if (!/^0x[a-fA-F0-9]{40}$/.test(addr)) {
          return `Invalid address format: ${addr}`
        }
      }
      return true
    },
  })
  return response.addresses.split(',').map((s: string) => s.trim())
}

export async function useTestConfig(): Promise<boolean> {
  const { useTest } = await prompts({
    type: 'select',
    name: 'useTest',
    message: 'Select configuration to use:',
    choices: [
      { title: 'Production', value: false },
      { title: 'Test', value: true },
    ],
  })

  return useTest
}

/**
 * Prompts the user to select between Production and Bummer/Test configuration
 * @returns A boolean indicating whether to use the Bummer/Test config (true) or Production config (false)
 */
export async function promptForConfigType(): Promise<boolean> {
  const configResponse = await prompts({
    type: 'select',
    name: 'configType',
    message: 'Select the configuration to use:',
    choices: [
      { title: 'Production Config', value: false },
      { title: 'Bummer/Test Config', value: true },
    ],
  })

  return configResponse.configType as boolean
}
